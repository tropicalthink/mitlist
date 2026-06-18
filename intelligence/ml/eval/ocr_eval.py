#!/usr/bin/env python3
"""Plan 012 Workstream C — OCR engine comparison eval harness.

Measures before/after OCR accuracy on real sample photos, scored separately for
print and handwriting.  Mirrors the resolution eval harness pattern
(resolution_eval.py / eval_harness.dart) so plan-012 A+B and the OCR engine
spike share a consistent measurement gate.

## Architecture overview

                          sample photos
                               │
                      ocr_eval_dataset.jsonl
                    (ground-truth transcripts)
                               │
               ┌───────────────┴───────────────┐
        backend: "mlkit"               backend: "apple_vision"  (future)
        (adb shell / Flutter          (xcrun simctl / Flutter
         integration test)             integration test)
               │                               │
         OcrResult JSONL              OcrResult JSONL
               └───────────────┬───────────────┘
                                │
                          ocr_eval.py score
                       (this file, --mode score)
                                │
                        ┌───────┴───────┐
                      print         handwriting
                    metrics           metrics
                   (never blended — see intelligence/plan.md §19)

## Usage

### Step 1 — populate the dataset
Add rows to `intelligence/ml/data/ocr_eval_dataset.jsonl`:
    {"image_path": "data/ocr_samples/print_001.jpg",
     "input_type": "print",
     "ground_truth_lines": ["Bananen", "Milch 1L", "Eier"],
     "note": "clean Rewe receipt, good lighting"}

Images live in `intelligence/ml/data/ocr_samples/` (gitignored; real photos).

### Step 2 — run OCR backends and collect results
Backend runners write JSONL to `intelligence/ml/data/ocr_results_<backend>.jsonl`.
Each row is an OcrResult (schema below).

Stub runner (dry-run, no real images needed):
    python3 intelligence/ml/eval/ocr_eval.py --mode stub \\
        --dataset intelligence/ml/data/ocr_eval_dataset.jsonl \\
        --out intelligence/ml/data/ocr_results_stub.jsonl

Flutter-driven runner (requires `flutter test` harness — see README at bottom):
    flutter test test/services/scan/ocr_eval_runner_test.dart \\
        --dart-define=OCR_BACKEND=mlkit \\
        --dart-define=DATASET_PATH=intelligence/ml/data/ocr_eval_dataset.jsonl \\
        --dart-define=OUT_PATH=intelligence/ml/data/ocr_results_mlkit.jsonl

### Step 3 — score
    python3 intelligence/ml/eval/ocr_eval.py --mode score \\
        --results intelligence/ml/data/ocr_results_mlkit.jsonl \\
        --dataset intelligence/ml/data/ocr_eval_dataset.jsonl

### Compare two backends
    python3 intelligence/ml/eval/ocr_eval.py --mode compare \\
        --baseline intelligence/ml/data/ocr_results_mlkit.jsonl \\
        --candidate intelligence/ml/data/ocr_results_apple_vision.jsonl \\
        --dataset intelligence/ml/data/ocr_eval_dataset.jsonl

Pure standard-library — no numpy/sklearn required (mirrors resolution_eval.py).
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Schema types (plain dicts — no dataclasses so this stays stdlib-only)
# ---------------------------------------------------------------------------

# ocr_eval_dataset.jsonl row schema:
#   image_path       str   relative to repo root; use ocr_samples/ for real photos
#   input_type       str   "print" | "handwriting"  — NEVER blend these
#   ground_truth_lines  list[str]  one clean transcript per OCR line expected
#   note             str?  human label of difficulty / scenario

# OcrResult JSONL row schema (written by backend runner, scored here):
#   image_path       str   matches dataset row
#   input_type       str   echoed from dataset row
#   backend          str   "mlkit" | "apple_vision" | "paddle_onnx" | "stub"
#   recognized_lines list[str]  raw OCR output, one string per line
#   latency_ms       float?  inference time for this image (ms)
#   note             str?  runner notes / error message


# ---------------------------------------------------------------------------
# Edit-distance metrics (pure Python, stdlib only)
# ---------------------------------------------------------------------------

def char_error_rate(ref: str, hyp: str) -> float:
    """Character Error Rate = edit_distance(ref, hyp) / len(ref).
    Returns 1.0 if ref is empty and hyp is non-empty."""
    ref = ref.strip()
    hyp = hyp.strip()
    if not ref:
        return 0.0 if not hyp else 1.0
    d = _edit_distance(list(ref), list(hyp))
    return min(d / len(ref), 1.0)  # cap at 1.0; insertions can exceed ref len


def word_error_rate(ref: str, hyp: str) -> float:
    """Word Error Rate = edit_distance(ref_words, hyp_words) / len(ref_words)."""
    ref_w = ref.strip().split()
    hyp_w = hyp.strip().split()
    if not ref_w:
        return 0.0 if not hyp_w else 1.0
    d = _edit_distance(ref_w, hyp_w)
    return min(d / len(ref_w), 1.0)


def _edit_distance(a: list, b: list) -> int:
    """Standard Levenshtein distance."""
    n, m = len(a), len(b)
    if n == 0:
        return m
    if m == 0:
        return n
    # Two-row DP — O(n*m) time, O(min(n,m)) space
    if n < m:
        a, b, n, m = b, a, m, n
    prev = list(range(m + 1))
    for i in range(1, n + 1):
        curr = [i] + [0] * m
        for j in range(1, m + 1):
            if a[i - 1] == b[j - 1]:
                curr[j] = prev[j - 1]
            else:
                curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
        prev = curr
    return prev[m]


# ---------------------------------------------------------------------------
# Line alignment — match recognized_lines to ground_truth_lines
# ---------------------------------------------------------------------------

def align_lines(gt_lines: list[str], rec_lines: list[str]) -> list[tuple[str, str]]:
    """Align recognized lines to ground-truth lines using LCS-based greedy match.
    Returns list of (gt, rec) pairs; unmatched gt lines are paired with "".
    Unmatched rec lines are ignored (spurious detections count as insertions
    at the WER/CER level once we have a per-image aggregate).
    """
    # Simple approach: concatenate all lines and score at image level.
    # This avoids fragile line-by-line alignment when OCR merges/splits lines.
    # For per-line analysis, return a synthetic single-pair alignment.
    gt_cat = " ".join(gt_lines)
    rec_cat = " ".join(rec_lines)
    return [(gt_cat, rec_cat)]


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score_results(dataset_rows: list[dict], result_rows: list[dict]) -> dict:
    """Score OcrResult rows against dataset ground truth.

    Returns a metrics dict with overall + per-input_type breakdown.
    Metric keys: cer, wer, exact_match_rate, n, latency_ms_median
    """
    by_image = {r["image_path"]: r for r in dataset_rows}

    buckets: dict[str, list] = {"print": [], "handwriting": []}

    unmatched = 0
    for res in result_rows:
        key = res["image_path"]
        if key not in by_image:
            unmatched += 1
            continue
        gt = by_image[key]
        input_type = gt.get("input_type", "print")
        if input_type not in buckets:
            buckets[input_type] = []

        gt_lines = gt.get("ground_truth_lines", [])
        rec_lines = res.get("recognized_lines", [])

        aligned = align_lines(gt_lines, rec_lines)
        for gt_text, rec_text in aligned:
            cer = char_error_rate(gt_text, rec_text)
            wer = word_error_rate(gt_text, rec_text)
            exact = 1 if gt_text.strip().lower() == rec_text.strip().lower() else 0
            latency = res.get("latency_ms")
            buckets[input_type].append({
                "cer": cer,
                "wer": wer,
                "exact": exact,
                "latency_ms": latency,
            })

    if unmatched:
        print(f"[warn] {unmatched} result row(s) had no matching dataset entry",
              file=sys.stderr)

    def _summarize(rows: list) -> dict:
        if not rows:
            return {"n": 0, "cer": float("nan"), "wer": float("nan"),
                    "exact_match_rate": float("nan"), "latency_ms_median": float("nan")}
        n = len(rows)
        avg_cer = sum(r["cer"] for r in rows) / n
        avg_wer = sum(r["wer"] for r in rows) / n
        exact_rate = sum(r["exact"] for r in rows) / n
        latencies = sorted(r["latency_ms"] for r in rows if r["latency_ms"] is not None)
        med_lat = latencies[len(latencies) // 2] if latencies else float("nan")
        return {
            "n": n,
            "cer": round(avg_cer, 4),
            "wer": round(avg_wer, 4),
            "exact_match_rate": round(exact_rate, 4),
            "latency_ms_median": round(med_lat, 1) if not math.isnan(med_lat) else float("nan"),
        }

    all_rows = [r for rows in buckets.values() for r in rows]
    return {
        "overall": _summarize(all_rows),
        "by_input_type": {k: _summarize(v) for k, v in buckets.items()},
    }


def format_metrics(metrics: dict, backend: str = "") -> str:
    """Human-readable metrics table."""
    b = []
    tag = f" [{backend}]" if backend else ""
    b.append(f"── OCR eval{tag} ──")

    def _row(label: str, m: dict) -> str:
        def pct(v):
            return "   —  " if math.isnan(v) else f"{v*100:5.1f}%"
        lat = m.get("latency_ms_median", float("nan"))
        lat_s = "   —  " if math.isnan(lat) else f"{lat:6.0f}ms"
        return (f"{label:12}  n={m['n']:4d}  "
                f"CER={pct(m['cer'])}  WER={pct(m['wer'])}  "
                f"exact={pct(m['exact_match_rate'])}  "
                f"lat_med={lat_s}")

    b.append(_row("OVERALL", metrics["overall"]))
    for itype, m in sorted(metrics["by_input_type"].items()):
        b.append(_row(itype.upper()[:12], m))
    return "\n".join(b)


def compare_metrics(baseline: dict, candidate: dict,
                    baseline_name: str = "baseline",
                    candidate_name: str = "candidate") -> str:
    """Delta table: positive Δ = improvement (lower error rate)."""
    b = []
    b.append(f"── OCR engine comparison: {baseline_name} vs {candidate_name} ──")
    b.append(f"{'':12}  {'metric':6}  {baseline_name:>12}  {candidate_name:>12}  {'Δ (↑ better)':>14}")

    def _delta_rows(label: str, bm: dict, cm: dict):
        rows = []
        for metric in ("cer", "wer", "exact_match_rate"):
            bv = bm.get(metric, float("nan"))
            cv = cm.get(metric, float("nan"))
            if math.isnan(bv) or math.isnan(cv):
                rows.append(f"{label:12}  {metric:6}  {'—':>12}  {'—':>12}  {'—':>14}")
                continue
            # For CER/WER: lower is better — flip sign for Δ display
            if metric in ("cer", "wer"):
                delta = bv - cv   # positive = candidate improved
            else:
                delta = cv - bv   # exact_match_rate: higher is better
            sign = "+" if delta > 0 else ""
            rows.append(f"{label:12}  {metric:6}  {bv*100:11.1f}%  {cv*100:11.1f}%  "
                        f"{sign}{delta*100:+12.1f}%")
        return rows

    for section in ["overall"] + sorted(baseline.get("by_input_type", {}).keys()):
        if section == "overall":
            bm = baseline.get("overall", {})
            cm = candidate.get("overall", {})
        else:
            bm = baseline.get("by_input_type", {}).get(section, {})
            cm = candidate.get("by_input_type", {}).get(section, {})
        b.extend(_delta_rows(section.upper()[:12], bm, cm))

    return "\n".join(b)


# ---------------------------------------------------------------------------
# Stub runner (dry-run; produces synthetic results for structural testing)
# ---------------------------------------------------------------------------

def run_stub(dataset_rows: list[dict], backend: str = "stub") -> list[dict]:
    """Produce fake OcrResult rows from dataset for structural testing.

    The stub simulates imperfect OCR: print lines get mild noise, handwriting
    lines get heavier noise.  This lets you verify the scoring math without
    real photos or a real OCR backend.
    """
    import random
    rng = random.Random(42)  # deterministic

    def _corrupt(text: str, severity: float) -> str:
        chars = list(text)
        result = []
        for c in chars:
            if rng.random() < severity * 0.15:
                result.append("")           # deletion
            elif rng.random() < severity * 0.10:
                result.append(rng.choice("aeiou"))  # insertion
            elif rng.random() < severity * 0.08:
                result.append(rng.choice("bcdfg"))  # substitution
            else:
                result.append(c)
        return "".join(result)

    results = []
    for row in dataset_rows:
        gt_lines = row.get("ground_truth_lines", [])
        severity = 0.1 if row.get("input_type") == "print" else 0.45
        rec_lines = [_corrupt(ln, severity) for ln in gt_lines]
        results.append({
            "image_path": row["image_path"],
            "input_type": row.get("input_type", "print"),
            "backend": backend,
            "recognized_lines": rec_lines,
            "latency_ms": rng.uniform(50, 300),
            "note": "stub synthetic result",
        })
    return results


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def load_jsonl(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        rows.append(json.loads(line))
    return rows


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    repo = Path(__file__).resolve().parents[3]
    data_dir = repo / "intelligence/ml/data"
    default_dataset = str(data_dir / "ocr_eval_dataset.jsonl")

    ap = argparse.ArgumentParser(
        description="OCR engine eval harness (plan 012 workstream C).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument(
        "--mode",
        choices=["stub", "score", "compare"],
        default="stub",
        help=(
            "stub: generate synthetic results for dry-run testing. "
            "score: score a results file against the dataset. "
            "compare: delta between two backends."
        ),
    )
    ap.add_argument(
        "--dataset",
        default=default_dataset,
        help="Path to ocr_eval_dataset.jsonl (ground-truth transcripts).",
    )
    ap.add_argument(
        "--results",
        help="[score mode] Path to OcrResult JSONL from a backend runner.",
    )
    ap.add_argument(
        "--baseline",
        help="[compare mode] Path to baseline OcrResult JSONL.",
    )
    ap.add_argument(
        "--candidate",
        help="[compare mode] Path to candidate OcrResult JSONL.",
    )
    ap.add_argument(
        "--out",
        help="[stub mode] Write synthetic results to this path.",
    )
    ap.add_argument(
        "--backend",
        default="stub",
        help="Backend label for stub mode (default: stub).",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Print metrics as JSON instead of human-readable table.",
    )
    args = ap.parse_args()

    dataset_path = Path(args.dataset)
    if not dataset_path.exists():
        # If the dataset doesn't exist yet, produce an empty scaffold and explain.
        print(
            f"[info] Dataset not found at {dataset_path}.\n"
            f"       Run in stub mode to test the harness structure:\n"
            f"         python3 {__file__} --mode stub --dataset /path/to/existing.jsonl\n"
            f"       Or populate {dataset_path} with real rows (see schema below).\n"
        )
        _print_schema()
        return

    dataset_rows = load_jsonl(dataset_path)
    if not dataset_rows:
        print("[warn] Dataset is empty. Add rows before scoring.")
        _print_schema()
        return

    if args.mode == "stub":
        results = run_stub(dataset_rows, backend=args.backend)
        if args.out:
            out_path = Path(args.out)
            write_jsonl(out_path, results)
            print(f"wrote {len(results)} stub results → {out_path}")
        metrics = score_results(dataset_rows, results)
        if args.json:
            print(json.dumps(metrics, indent=2))
        else:
            print(format_metrics(metrics, backend=f"stub ({args.backend})"))

    elif args.mode == "score":
        if not args.results:
            ap.error("--results is required for --mode score")
        results_path = Path(args.results)
        if not results_path.exists():
            ap.error(f"results file not found: {results_path}")
        results = load_jsonl(results_path)
        backend = results[0].get("backend", "unknown") if results else "unknown"
        metrics = score_results(dataset_rows, results)
        if args.json:
            print(json.dumps(metrics, indent=2))
        else:
            print(format_metrics(metrics, backend=backend))

    elif args.mode == "compare":
        if not args.baseline or not args.candidate:
            ap.error("--baseline and --candidate are required for --mode compare")
        base_path = Path(args.baseline)
        cand_path = Path(args.candidate)
        if not base_path.exists():
            ap.error(f"baseline not found: {base_path}")
        if not cand_path.exists():
            ap.error(f"candidate not found: {cand_path}")
        base_results = load_jsonl(base_path)
        cand_results = load_jsonl(cand_path)
        base_backend = base_results[0].get("backend", "baseline") if base_results else "baseline"
        cand_backend = cand_results[0].get("backend", "candidate") if cand_results else "candidate"
        base_metrics = score_results(dataset_rows, base_results)
        cand_metrics = score_results(dataset_rows, cand_results)
        if args.json:
            print(json.dumps({"baseline": base_metrics, "candidate": cand_metrics}, indent=2))
        else:
            print(format_metrics(base_metrics, backend=base_backend))
            print()
            print(format_metrics(cand_metrics, backend=cand_backend))
            print()
            print(compare_metrics(base_metrics, cand_metrics,
                                  baseline_name=base_backend,
                                  candidate_name=cand_backend))


def _print_schema():
    schema = """
Dataset row schema (ocr_eval_dataset.jsonl):
  image_path        str   relative to repo root; photos in intelligence/ml/data/ocr_samples/
  input_type        str   "print" | "handwriting"  — NEVER blend in metrics
  ground_truth_lines  list[str]  one clean string per expected OCR output line
  note              str?  scenario/difficulty description

Example:
  {"image_path": "intelligence/ml/data/ocr_samples/hw_001.jpg",
   "input_type": "handwriting",
   "ground_truth_lines": ["Milch", "Eier 6St", "Bananen"],
   "note": "hasty cursive, pencil, good light"}

OcrResult row schema (written by backend runners):
  image_path        str   matches dataset row
  input_type        str   echoed from dataset
  backend           str   "mlkit" | "apple_vision" | "paddle_onnx" | "stub"
  recognized_lines  list[str]  raw OCR output lines
  latency_ms        float?  per-image inference time
  note              str?  runner notes / error

Image directory: intelligence/ml/data/ocr_samples/  (gitignored; add real photos locally)
"""
    print(schema)


if __name__ == "__main__":
    main()
