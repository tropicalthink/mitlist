#!/usr/bin/env python3
"""Plan 037 — Phase D: fit the calibrated resolution scorer.

Reads the labelled feature dump emitted by the Dart exporter
(`frontend/test/services/resolution_feature_export_test.dart` →
`intelligence/ml/data/resolution_features.jsonl`), fits a logistic-regression
head over the fixed feature vector, picks the auto-accept threshold for a
precision target, and writes a staging weights bundle + a parity golden file.

Pure standard library — no numpy/sklearn. The model is tiny (one weight per
feature + bias); gradient descent on a few hundred rows is instant. The whole
point is that the weights are calibrated on the SAME features the app computes
at inference (the Dart export is the parity contract), so there is no Python
re-implementation of the feature math to drift out of sync.

Usage:
    python3 intelligence/ml/eval/resolution_eval.py \
        [--features intelligence/ml/data/resolution_features.jsonl] \
        [--out intelligence/ml/data/resolution_weights.json] \
        [--golden intelligence/ml/data/resolution_golden.json] \
        [--precision 0.99] [--holdout 0.25] \
        [--epochs 4000] [--lr 0.3] [--l2 0.001] [--ship]

With --ship, the fitted bundle is also written to
`frontend/assets/grocery/resolution_weights.json` only when held-out
precision@auto and coverage@auto both meet or beat the hand-set defaults.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

ASSET_VERSION = 1  # bump when retrained; CalibratedScorer/loader version-gates.

EXPECTED_FEATURE_NAMES = [
    "aliasStringSim",
    "canonicalNameSim",
    "classifierProb",
    "embedderCosine",
    "sourceAgreement",
    "isHouseholdAlias",
    "householdFreq",
    "recency",
    "listCooccurrence",
    "isExactAlias",
]

# Source: frontend/lib/services/scan/resolution/calibrated_scorer.dart
# CalibratedScorer.kDefaultWeights / kDefaultBias / default tauAuto.
DEFAULT_WEIGHTS = [1.4, 4.4, 2.2, 1.8, 0.8, 2.6, 1.8, 0.5, 1.4, 0.4]
DEFAULT_BIAS = -2.7
DEFAULT_TAU_AUTO = 0.85


def load_dump(path: Path):
    """Returns (feature_names, rows) where each row is
    {raw_text, input_type, candidate_id, expected_id, label, features:[...]}."""
    feature_names = None
    rows = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            if "feature_names:" in line:
                feature_names = line.split("feature_names:", 1)[1].strip().split(",")
            continue
        rows.append(json.loads(line))
    if feature_names is None:
        raise SystemExit("dump missing the '# feature_names:' header")
    return feature_names, rows


def sigmoid(z: float) -> float:
    if z < -60:
        return 0.0
    if z > 60:
        return 1.0
    return 1.0 / (1.0 + math.exp(-z))


def fit_logistic(X, y, *, epochs, lr, l2):
    """Class-weighted L2 logistic regression via full-batch gradient descent."""
    n = len(X)
    dim = len(X[0])
    w = [0.0] * dim
    b = 0.0
    pos = sum(y) or 1
    neg = (n - pos) or 1
    # Up-weight the rare positive class (one true item among many candidates).
    wpos = n / (2.0 * pos)
    wneg = n / (2.0 * neg)
    for _ in range(epochs):
        gw = [0.0] * dim
        gb = 0.0
        for xi, yi in zip(X, y):
            z = b + sum(w[j] * xi[j] for j in range(dim))
            p = sigmoid(z)
            cw = wpos if yi == 1 else wneg
            err = cw * (p - yi)
            for j in range(dim):
                gw[j] += err * xi[j]
            gb += err
        for j in range(dim):
            w[j] -= lr * (gw[j] / n + l2 * w[j])
        b -= lr * (gb / n)
    return w, b


def predict(w, b, x):
    return sigmoid(b + sum(w[j] * x[j] for j in range(len(w))))


def pick_tau(scored_labels, target_precision):
    """scored_labels: list of (p, label). Returns the lowest tau whose
    precision among p>=tau meets target, plus (precision, coverage) there."""
    thresholds = sorted({round(p, 4) for p, _ in scored_labels}, reverse=True)
    best = None
    n = len(scored_labels)
    for tau in thresholds:
        sel = [(p, l) for p, l in scored_labels if p >= tau]
        if not sel:
            continue
        prec = sum(l for _, l in sel) / len(sel)
        cov = len(sel) / n
        if prec >= target_precision:
            best = (tau, prec, cov)  # keep lowering tau while precision holds
    if best is None:
        # Nothing hits the target; fall back to the most precise non-empty tau.
        tau = thresholds[0]
        sel = [(p, l) for p, l in scored_labels if p >= tau]
        prec = sum(l for _, l in sel) / len(sel)
        best = (tau, prec, len(sel) / n)
    return best


def query_key(row):
    return (row["raw_text"], row["input_type"])


def split_by_query(rows, holdout_fraction):
    """Deterministic query-level split; all candidates for one query stay
    together. Uses a stable SHA-256 bucket instead of process-randomized hash."""
    by_query = {}
    for row in rows:
        by_query.setdefault(query_key(row), []).append(row)

    train = []
    holdout = []
    for key, query_rows in by_query.items():
        raw = f"{key[0]}\0{key[1]}".encode("utf-8")
        bucket = int.from_bytes(hashlib.sha256(raw).digest()[:8], "big") / 2**64
        target = holdout if bucket < holdout_fraction else train
        target.extend(query_rows)

    if not train or not holdout:
        raise SystemExit(
            f"holdout split produced train={len({query_key(r) for r in train})} "
            f"holdout={len({query_key(r) for r in holdout})}; adjust --holdout"
        )
    return train, holdout


def evaluate(rows, w, b, tau_auto):
    """Top-1 accuracy (argmax candidate per raw_text) + auto-accept precision."""
    by_query = {}
    for r in rows:
        by_query.setdefault((r["raw_text"], r["input_type"]), []).append(r)
    total = correct = accepted = accepted_correct = 0
    for cands in by_query.values():
        total += 1
        scored = [(predict(w, b, c["features"]), c) for c in cands]
        scored.sort(key=lambda t: t[0], reverse=True)
        top_p, top = scored[0]
        is_correct = top["candidate_id"] == top["expected_id"]
        if is_correct:
            correct += 1
        if top_p >= tau_auto:
            accepted += 1
            if is_correct:
                accepted_correct += 1
    return {
        "queries": total,
        "top1": correct / total if total else 0.0,
        "precision_at_auto": accepted_correct / accepted if accepted else float("nan"),
        "coverage": accepted / total if total else 0.0,
        "accepted": accepted,
        "accepted_correct": accepted_correct,
    }


def bundle(feature_names, weights, bias, tau_auto, tau_review):
    return {
        "version": ASSET_VERSION,
        "feature_names": feature_names,
        "weights": [round(x, 6) for x in weights],
        "bias": round(bias, 6),
        "tau_auto": round(tau_auto, 6),
        "tau_review": tau_review,
    }


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")


def format_metrics(metrics):
    precision = metrics["precision_at_auto"]
    precision_s = "nan" if math.isnan(precision) else f"{precision:.3f}"
    return (
        f"queries={metrics['queries']} top1={metrics['top1']:.3f} "
        f"precision@auto={precision_s} coverage@auto={metrics['coverage']:.3f} "
        f"({metrics['accepted_correct']}/{metrics['accepted']})"
    )


def main():
    ap = argparse.ArgumentParser()
    repo = Path(__file__).resolve().parents[3]
    ap.add_argument("--features",
                    default=str(repo / "intelligence/ml/data/resolution_features.jsonl"))
    # Staging path by default — NOT shipped. Copy into
    # frontend/assets/grocery/ (versioned) only after confirming the fit beats
    # the hand-tuned CalibratedScorer defaults on the eval (precision@auto at
    # equal-or-higher coverage). The eval harness exists to catch a regression
    # here before it ships.
    ap.add_argument("--out",
                    default=str(repo / "intelligence/ml/data/resolution_weights.json"))
    ap.add_argument("--golden",
                    default=str(repo / "intelligence/ml/data/resolution_golden.json"))
    ap.add_argument("--precision", type=float, default=0.99)
    ap.add_argument("--holdout", type=float, default=0.25)
    ap.add_argument("--tau-review", type=float, default=0.50)
    ap.add_argument("--epochs", type=int, default=4000)
    ap.add_argument("--lr", type=float, default=0.3)
    ap.add_argument("--l2", type=float, default=0.001)
    ap.add_argument("--ship", action="store_true",
                    help="write frontend asset only if holdout beats defaults")
    args = ap.parse_args()

    if not 0.0 < args.holdout < 1.0:
        raise SystemExit("--holdout must be > 0 and < 1")

    feature_names, rows = load_dump(Path(args.features))
    if feature_names != EXPECTED_FEATURE_NAMES:
        raise SystemExit(
            "feature_names header does not match kResolutionFeatureNames; "
            f"got {feature_names!r}"
        )
    if len(DEFAULT_WEIGHTS) != len(feature_names):
        raise SystemExit("default weights length does not match feature count")

    train_rows, holdout_rows = split_by_query(rows, args.holdout)
    holdout_queries = len({query_key(r) for r in holdout_rows})
    X = [r["features"] for r in rows]
    y = [int(r["label"]) for r in rows]
    if not any(y):
        raise SystemExit("no positive examples in the dump — nothing to fit")
    train_X = [r["features"] for r in train_rows]
    train_y = [int(r["label"]) for r in train_rows]
    if not any(train_y):
        raise SystemExit("no positive examples in train split — nothing to fit")

    print(f"loaded {len(rows)} candidate rows over "
          f"{len({(r['raw_text'], r['input_type']) for r in rows})} queries; "
          f"{sum(y)} positive; {len(feature_names)} features")
    print(f"split train={len({query_key(r) for r in train_rows})} queries / "
          f"{len(train_rows)} rows; holdout={holdout_queries} queries / "
          f"{len(holdout_rows)} rows")

    w, b = fit_logistic(train_X, train_y, epochs=args.epochs, lr=args.lr, l2=args.l2)

    scored_labels = [(predict(w, b, train_X[i]), train_y[i]) for i in range(len(train_X))]
    tau_auto, tau_prec, tau_cov = pick_tau(scored_labels, args.precision)
    fitted_train = evaluate(train_rows, w, b, tau_auto)
    fitted_holdout = evaluate(holdout_rows, w, b, tau_auto)
    default_train = evaluate(train_rows, DEFAULT_WEIGHTS, DEFAULT_BIAS, DEFAULT_TAU_AUTO)
    default_holdout = evaluate(
        holdout_rows,
        DEFAULT_WEIGHTS,
        DEFAULT_BIAS,
        DEFAULT_TAU_AUTO,
    )

    print("\nfitted weights:")
    for name, weight in zip(feature_names, w):
        print(f"  {name:18} {weight:+.3f}")
    print(f"  {'bias':18} {b:+.3f}")
    print(f"\ntau_auto={tau_auto:.3f} "
          f"(candidate-level precision {tau_prec:.3f} @ coverage {tau_cov:.3f})")
    print("\nquery-level metrics:")
    print(f"  fitted train={format_metrics(fitted_train)}")
    print(f"  fitted holdout={format_metrics(fitted_holdout)}")
    print(f"  default train={format_metrics(default_train)}")
    print(f"  default holdout={format_metrics(default_holdout)}")

    weights_bundle = bundle(feature_names, w, b, tau_auto, args.tau_review)
    write_json(Path(args.out), weights_bundle)
    print(f"\nwrote weights → {args.out}")

    # Parity golden: a few feature vectors + the P this fit produces, so the Dart
    # CalibratedScorer can be checked byte-for-byte against the fitter.
    golden = []
    for r in rows[: min(8, len(rows))]:
        golden.append({"features": r["features"],
                       "expected_p": round(predict(w, b, r["features"]), 6)})
    write_json(Path(args.golden), golden)
    print(f"wrote golden → {args.golden}")

    if args.ship:
        asset_path = repo / "frontend/assets/grocery/resolution_weights.json"
        fitted_precision = fitted_holdout["precision_at_auto"]
        default_precision = default_holdout["precision_at_auto"]
        if holdout_queries < 10:
            print("NOT SHIPPED: holdout has fewer than 10 queries")
        elif math.isnan(fitted_precision):
            print("NOT SHIPPED: fitted model accepted no holdout queries")
        elif not math.isnan(default_precision) and fitted_precision < default_precision:
            print(
                "NOT SHIPPED: fitted holdout precision@auto "
                f"{fitted_precision:.3f} < default {default_precision:.3f}"
            )
        elif fitted_holdout["coverage"] < default_holdout["coverage"]:
            print(
                "NOT SHIPPED: fitted holdout coverage@auto "
                f"{fitted_holdout['coverage']:.3f} < default "
                f"{default_holdout['coverage']:.3f}"
            )
        else:
            write_json(asset_path, weights_bundle)
            print(f"SHIPPED: wrote {asset_path}")


if __name__ == "__main__":
    main()
