# On-device OCR models

The scanner runs two PP-OCRv6 graphs entirely on the phone through ONNX
Runtime: a small text detector and a medium recognizer that was fine-tuned on
handwritten shopping lists (see `frontend/test/fixtures/OCR_TRAINING.md`).

The `inference.onnx` files (~82 MB together) are **not committed**. They are
published as release assets so clones stay small. Everything else in these
folders (`characters.json`, `inference.yml`) is tracked.

## Get the models

```bash
cd frontend
python tool/fetch_ocr_models.py
```

The script downloads both files, verifies their SHA-256, and is safe to re-run.
Point it somewhere else with `MITLIST_OCR_MODELS_URL=<base url>` or
`--base-url` if you host your own copy.

Without the models the app still builds and runs, but the scanner cannot load
its graphs, so list scanning fails at runtime. The web build never ships them
(`Dockerfile.prod` strips this folder), because OCR is mobile-only.

## Replace the models

1. Export the new graph and run the gates in `OCR_TRAINING.md`.
2. Upload the file as a release asset under a new tag (for example
   `ocr-models-v2`).
3. Update the size, SHA-256, and default tag in `tool/fetch_ocr_models.py`.
4. Bump the engine string in `lib/services/scan/scan_models.dart` so stored
   scan results record which model produced them.
