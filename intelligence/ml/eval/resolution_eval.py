#!/usr/bin/env python3
"""Plan 037 — Phase D: fit the calibrated resolution scorer.

Reads the labelled feature dump emitted by the Dart exporter
(`frontend/test/services/resolution_feature_export_test.dart` →
`intelligence/ml/data/resolution_features.jsonl`), fits a logistic-regression
head over the fixed feature vector, picks the auto-accept threshold for a
precision target, and writes the shipped weights bundle + a parity golden file.

Pure standard library — no numpy/sklearn. The model is tiny (one weight per
feature + bias); gradient descent on a few hundred rows is instant. The whole
point is that the weights are calibrated on the SAME features the app computes
at inference (the Dart export is the parity contract), so there is no Python
re-implementation of the feature math to drift out of sync.

Usage:
    python3 intelligence/ml/eval/resolution_eval.py \
        [--features intelligence/ml/data/resolution_features.jsonl] \
        [--out frontend/assets/grocery/resolution_weights.json] \
        [--precision 0.99] [--epochs 4000] [--lr 0.3] [--l2 0.001]

Then copy/keep `resolution_weights.json` under `frontend/assets/grocery/`
(versioned) and load it in CalibratedScorer.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

ASSET_VERSION = 1  # bump when retrained; CalibratedScorer/loader version-gates.


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
    ap.add_argument("--tau-review", type=float, default=0.50)
    ap.add_argument("--epochs", type=int, default=4000)
    ap.add_argument("--lr", type=float, default=0.3)
    ap.add_argument("--l2", type=float, default=0.001)
    args = ap.parse_args()

    feature_names, rows = load_dump(Path(args.features))
    X = [r["features"] for r in rows]
    y = [int(r["label"]) for r in rows]
    if not any(y):
        raise SystemExit("no positive examples in the dump — nothing to fit")

    print(f"loaded {len(rows)} candidate rows over "
          f"{len({(r['raw_text'], r['input_type']) for r in rows})} queries; "
          f"{sum(y)} positive; {len(feature_names)} features")

    w, b = fit_logistic(X, y, epochs=args.epochs, lr=args.lr, l2=args.l2)

    scored_labels = [(predict(w, b, X[i]), y[i]) for i in range(len(X))]
    tau_auto, tau_prec, tau_cov = pick_tau(scored_labels, args.precision)
    metrics = evaluate(rows, w, b, tau_auto)

    print("\nfitted weights:")
    for name, weight in zip(feature_names, w):
        print(f"  {name:18} {weight:+.3f}")
    print(f"  {'bias':18} {b:+.3f}")
    print(f"\ntau_auto={tau_auto:.3f} "
          f"(candidate-level precision {tau_prec:.3f} @ coverage {tau_cov:.3f})")
    print("query-level:  top1={top1:.3f}  precision@auto={precision_at_auto:.3f}  "
          "coverage={coverage:.3f}  ({accepted_correct}/{accepted})".format(**metrics))

    Path(args.out).write_text(json.dumps({
        "version": ASSET_VERSION,
        "feature_names": feature_names,
        "weights": [round(x, 6) for x in w],
        "bias": round(b, 6),
        "tau_auto": round(tau_auto, 6),
        "tau_review": args.tau_review,
    }, indent=2))
    print(f"\nwrote weights → {args.out}")

    # Parity golden: a few feature vectors + the P this fit produces, so the Dart
    # CalibratedScorer can be checked byte-for-byte against the fitter.
    golden = []
    for r in rows[: min(8, len(rows))]:
        golden.append({"features": r["features"],
                       "expected_p": round(predict(w, b, r["features"]), 6)})
    Path(args.golden).write_text(json.dumps(golden, indent=2))
    print(f"wrote golden → {args.golden}")


if __name__ == "__main__":
    main()
