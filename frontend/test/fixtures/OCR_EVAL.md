# On-device OCR evaluation

The committed manifest contains transcriptions and line status only. Sample
photos remain outside the repository and are never included in production app
assets.

From `frontend/`, prepare the private device payload:

```bash
dart run tool/prepare_ocr_eval.dart /home/whtvrboo/Downloads/samples
```

The preparation step generates an ignored Dart test target containing the
private bytes. This avoids command-line size limits while ensuring the photos
are compiled only into the evaluation build, never the production app.

Connect an Android or iOS device, then record and score the current baseline:

```bash
dart run tool/run_ocr_eval.dart DEVICE_ID
```

Score the resulting raw OCR output:

```bash
dart run tool/score_ocr_eval.dart \
  test/fixtures/ocr_eval_manifest.json \
  build/ocr_eval_results_ppocrv6_device.json
```

The device test sends each original capture through the production portable
PP-OCRv6 path. The app does not use OpenCV or a platform OCR API. The report
includes normalized character and word error rates, readable-line recall,
exact-line rate, crossed-out detection recall, unmatched predictions, and mean
OCR latency. Illegible regions do not affect transcript accuracy.
Without region bounding boxes, unmatched predictions are a conservative
hallucination signal rather than a definitive illegible-region score.

ML Kit is measured here only as the legacy baseline. It is not the target OCR
architecture: the replacement must use the same bundled model and runtime on
every supported mobile platform and must not call a cloud service.

The first Android result is recorded in `OCR_BASELINE_MLKIT_ANDROID.md`.
The first production PP-OCRv6 host result is recorded in
`OCR_BASELINE_PPOCRV6_HOST.md`.

## PP-OCRv6 reference evaluation

The official model pair can also be evaluated with PaddleOCR's reference
pre/post-processing. Keep downloaded reference files outside the repository.

```bash
python tool/benchmark_ppocrv6.py \
  --samples-dir /home/whtvrboo/Downloads/samples \
  --manifest test/fixtures/ocr_eval_manifest.json \
  --det-model-dir /path/to/PP-OCRv6_small_det_onnx \
  --rec-model-dir /path/to/PP-OCRv6_medium_rec_onnx \
  --output build/ocr_eval_results_ppocrv6.json

dart run tool/score_ocr_eval.dart \
  test/fixtures/ocr_eval_manifest.json \
  build/ocr_eval_results_ppocrv6.json
```

This host benchmark intentionally uses PaddleOCR's reference implementation,
which depends on desktop Python/OpenCV. It does not authorize OpenCV in the app.
Production inference implements the corresponding image transforms, DB
post-process, crop construction, CTC decode, and reading order in portable Dart
plus the same ONNX Runtime version on Android and iOS.

## Handwriting recognizer bake-off

Create a disposable host environment before running the research tools:

```bash
python3 -m venv /tmp/mitlist-ocr-benchmark
/tmp/mitlist-ocr-benchmark/bin/pip install \
  -r tool/requirements-ocr-benchmark.txt
```

`tool/benchmark_handwriting_recognizer.py` keeps the bundled detector fixed and
runs a candidate TrOCR checkpoint over identical line crops. It supports a
Transformers checkpoint for research and split TrOCR encoder/decoder ONNX files
for deployment-oriented evaluation. These are host-only dependencies; a model
must win this evaluation before any runtime or asset is added to Flutter.

`tool/benchmark_ppocr_ctc_lexicon.py` evaluates forced CTC scoring of bundled
grocery names. Its output includes both `raw_text` and the selected `text` so
over-corrections remain auditable.

The first results and rejection decisions are recorded in
`OCR_HANDWRITING_BAKEOFF.md`. Raw results and private crops belong in `build/`
and `/tmp`, not source control.

The opt-in correction collector, writer-disjoint dataset builder, fine-tuning
instructions, and model-promotion gates are documented in `OCR_TRAINING.md`.
