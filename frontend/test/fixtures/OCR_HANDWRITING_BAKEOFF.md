# Handwriting recognizer bake-off

Recorded 2026-07-21 against the six private list photographs and 45 readable
ground-truth lines in `ocr_eval_manifest.json`. Photos and extracted crops stay
outside the repository.

The comparison holds `PP-OCRv6_small_det` fixed and changes only line
recognition. Candidate recognizers receive the same correctly detected,
reading-order line crops. Metrics use the committed OCR scorer.

## Results

| Recognizer | CER | Exact lines | Mean recognition latency/page | Approx. recognizer size | Decision |
|---|---:|---:|---:|---:|---|
| Production PP-OCRv6 medium CTC | **20.49%** | 37.78% | 4465 ms* | 74 MB | Keep |
| PP-OCRv6 control on bake-off crops | 22.22% | 40.00% | 1660 ms | 74 MB | Control only |
| Microsoft TrOCR-small-handwritten | 660.25% | 0.00% | 38585 ms | 246 MB FP32 | Reject |
| Multicentury HTR small ONNX | 44.94% | 6.67% | 3810 ms | 238 MB | Reject |
| German TrOCR-small | 79.51% | 0.00% | 3627 ms | 246 MB FP32 | Reject |
| Strict PP-OCR CTC lexicon prototype | 21.48% | 51.11% | 1718 ms | existing model | Do not ship yet |

\*The production baseline is a desktop Flutter end-to-end measurement, while
candidate latency measures host recognition after crop extraction. Treat the
numbers as relative diagnostics, not mobile performance claims.

## Findings

- The crops are valid. TrOCR's official IAM example was also checked and
  produced the expected `industry` transcription, ruling out a broken model
  load. Its failures here are domain transfer failures.
- Autoregressive HTR models hallucinated fluent but unrelated text when a short
  grocery crop was ambiguous. Examples included Wikipedia-like boilerplate from
  the English model and plausible unrelated German words from the German model.
- The Finnish/Swedish multicentury ONNX model transferred better than TrOCR's
  IAM checkpoint but still doubled the production character error rate while
  adding roughly 238 MB of model data.
- Forced CTC lexicon scoring improved exact matches on the six samples, but it
  also introduced confident semantic substitutions such as `Olivenöl` →
  `Olivenbrot`, `Reis` → `Redfish`, and `Kartoffeln` → `Kartoffelmehl`. Tuning
  those thresholds on six samples would overfit the evaluation set, so the
  prototype is not production code.

## Decision

Keep the current PP-OCRv6 CTC recognizer and its bounded alternatives. Do not
add a second autoregressive recognizer, a larger detector, or unconditional
dictionary decoding.

The next model-quality gate is a domain fine-tune of a compact CTC recognizer
using real corrected grocery-line crops from multiple writers. The six images
remain a regression set; they must not become both training and evaluation
data. A first credible split needs at least 1,000 transcribed lines with a
writer-disjoint holdout. Synthetic augmentation can expand that corpus but
cannot replace the real holdout.

## Reproduction

Host-only dependencies belong in an isolated environment and are not Flutter
dependencies. Install `tool/requirements-ocr-benchmark.txt`, then see
`tool/benchmark_handwriting_recognizer.py` for TrOCR/ONNX HTR candidates and
`tool/benchmark_ppocr_ctc_lexicon.py` for the constrained CTC experiment. Raw
JSON results are written under ignored `build/` paths.
