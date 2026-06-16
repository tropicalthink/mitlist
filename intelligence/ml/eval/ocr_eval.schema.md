# OCR Eval Dataset — Schema & Curation Notes
# Plan 012 Workstream C

The dataset that makes "OCR is the bottleneck" a **measured** claim instead of
a hypothesis. It is the ground truth the OCR eval harness (`ocr_eval.py`)
scores against, and the before/after measurement gate for any OCR engine change.

- **Dataset**: `intelligence/ml/data/ocr_eval_dataset.jsonl` — one JSON object per line.
- **Results** (one file per backend): `intelligence/ml/data/ocr_results_<backend>.jsonl`
- **Sample images**: `intelligence/ml/data/ocr_samples/` — **gitignored**; real photos live here locally and are never committed (privacy + size).
- **Starter set**: 0 rows committed; the harness runs in stub mode for structural testing.
  Populate with real photos before any engine comparison is meaningful.

---

## Dataset row schema

| field | type | required | meaning |
|---|---|---|---|
| `image_path` | string | YES | path relative to repo root; e.g. `intelligence/ml/data/ocr_samples/hw_001.jpg` |
| `input_type` | `"print"` \| `"handwriting"` | YES | scored **separately** — never blended (see intelligence/plan.md §19) |
| `ground_truth_lines` | string[] | YES | one clean string per OCR line expected in order; strip quantities/units from ground truth only if you want to measure item name recognition in isolation, but prefer keeping raw text so the OCR layer is measured in full |
| `note` | string | optional | human description of difficulty, lighting, script style — not scored |

Example:
```json
{"image_path": "intelligence/ml/data/ocr_samples/hw_001.jpg",
 "input_type": "handwriting",
 "ground_truth_lines": ["Milch", "Eier 6 St.", "Bananen 3"],
 "note": "hasty cursive, pencil, overhead light, iPhone 13"}
```

---

## OcrResult row schema (written by backend runners)

| field | type | meaning |
|---|---|---|
| `image_path` | string | must match a dataset row |
| `input_type` | string | echoed from dataset row |
| `backend` | string | `"mlkit"` \| `"apple_vision"` \| `"paddle_onnx"` \| `"stub"` |
| `recognized_lines` | string[] | raw OCR output; one string per detected line (order matters for CER/WER) |
| `latency_ms` | float? | wall-clock time for this image in milliseconds |
| `note` | string? | runner notes or error description |

---

## Metrics (computed by ocr_eval.py)

Scored per `input_type` **and** overall — never blended:

- **CER (Character Error Rate)** — Levenshtein(ref_chars, hyp_chars) / len(ref_chars). Primary metric for handwriting (where words are badly mangled). Lower is better.
- **WER (Word Error Rate)** — Levenshtein(ref_words, hyp_words) / len(ref_words). Primary metric for print. Lower is better.
- **Exact match rate** — fraction of images where the full concatenated output matches ground truth exactly. Useful as an upper bound check. Higher is better.
- **Latency (median ms)** — per-image OCR inference time. Budget: ≤ 80 ms median on a mid-range Android (see ocr_engine_options.md §5).

### Comparing to the resolution eval

The OCR eval measures the **recognition layer only** (image → text string).
The resolution eval (`resolution_eval.py`) measures the **resolution layer** (text string → canonical id).
They are separate instruments. A before/after OCR eval measures whether the text coming out of OCR improved; a before/after resolution eval measures whether the grocery resolution improved.

The two interact: if OCR WER drops, resolution precision typically rises. But the split measurement is what distinguishes "OCR is the bottleneck" from "vocabulary / alias coverage is the bottleneck."

---

## Curation principles

- **Real photos only** — synthetic test images are not representative of the phone-camera-to-grocery-list path. Add photos taken with a real phone in real lighting.
- **Cover the spread**:
  - Print: clean receipt, slightly angled, glare, low light, small font (≤8pt).
  - Handwriting: neat print, casual script, pencil, pen, mix of DE+EN, umlauts, shorthand.
- **Represent the vocabulary** — include items from `resolution_eval.jsonl` so OCR quality on exactly those items can be traced.
- **One image = one list or sub-section** — do not put multiple independent lists in one image row; the line alignment gets ambiguous.
- **Minimum useful set**: ~20 print + ~20 handwriting images to see stable CER/WER numbers. Grow to 100+ for confidence in engine comparison.

---

## Backend runners

### stub (built-in to ocr_eval.py)
No photos needed. Produces synthetic corrupted text to test the scoring math.

```bash
# Dry-run: verify the harness structure without any real data
python3 intelligence/ml/eval/ocr_eval.py --mode stub \
    --dataset intelligence/ml/data/ocr_eval_dataset.jsonl \
    --backend mlkit
```

### mlkit (Flutter integration test runner)
Requires a connected device or emulator.

```bash
# Run Flutter integration test that exercises OcrService and writes results JSONL
flutter test test/services/scan/ocr_eval_runner_test.dart \
    --dart-define=OCR_BACKEND=mlkit \
    --dart-define=DATASET_PATH=intelligence/ml/data/ocr_eval_dataset.jsonl \
    --dart-define=OUT_PATH=intelligence/ml/data/ocr_results_mlkit.jsonl

# Score the results
python3 intelligence/ml/eval/ocr_eval.py --mode score \
    --dataset intelligence/ml/data/ocr_eval_dataset.jsonl \
    --results intelligence/ml/data/ocr_results_mlkit.jsonl
```

**Note**: `test/services/scan/ocr_eval_runner_test.dart` is the gap to fill when
plan-012 A+B land — scaffold is in `ocr_eval_runner_test.dart.scaffold` (see this directory).

### apple_vision (iOS only, future)
Same pattern; swap `--dart-define=OCR_BACKEND=apple_vision` and implement the platform channel in Swift.

### Compare two backends
```bash
python3 intelligence/ml/eval/ocr_eval.py --mode compare \
    --dataset intelligence/ml/data/ocr_eval_dataset.jsonl \
    --baseline intelligence/ml/data/ocr_results_mlkit.jsonl \
    --candidate intelligence/ml/data/ocr_results_apple_vision.jsonl
```

---

## Known gaps (to fill when plan-012 A+B land)

| Gap | Owner | Notes |
|---|---|---|
| `test/services/scan/ocr_eval_runner_test.dart` | Plan 012 eng | Flutter integration test that calls `OcrService.recogniseFromPath()` per dataset image and writes OcrResult JSONL. See scaffold in this directory. |
| `intelligence/ml/data/ocr_samples/` | Team / testers | Real photos. Gitignored. Add at least 20 print + 20 handwriting before comparing engines. |
| `intelligence/ml/data/ocr_eval_dataset.jsonl` | Team | Ground-truth transcripts for the photos above. |
| Apple Vision platform channel (Swift) | Future spike | iOS only; see ocr_engine_options.md §5 for the recommended integration path. |
