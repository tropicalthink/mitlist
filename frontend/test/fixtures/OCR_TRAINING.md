# Offline handwriting OCR training loop

This workflow improves the bundled recognizer without adding a cloud service,
an LLM, or a platform OCR API. Training happens on a private workstation; the
exported ONNX recognizer still runs entirely on-device through the shared
Flutter runtime.

## 1. Collect corrected lines

In **You**, enable **Improve offline handwriting OCR**. During scan review,
open a line and confirm or correct the item name. Only manually reviewed,
non-crossed-out lines without parsed quantity/price fields are eligible.

The collector stores:

- a cropped JPEG of the handwritten line;
- the corrected transcription and original OCR text;
- a random writer token and OCR engine version.

It does not store the complete list photograph, account ID, household ID,
email address, or list contents outside the crop. Data remains in application
support storage until the user explicitly exports or deletes it. Logging out or
deleting the account removes that account's local corpus.

Use one account per writer. Export a ZIP from each writer through **You**.

## 2. Build a writer-disjoint dataset

Gather exports on the private training workstation, then run:

```bash
python tool/prepare_ocr_training_dataset.py \
  --input /private/exports/writer-a.zip \
  --input /private/exports/writer-b.zip \
  --input /private/exports/writer-c.zip \
  --output /private/mitlist-ocr-dataset
```

The command refuses fewer than 1,000 unique lines and fewer than five writers.
It creates `train.txt`, `val.txt`, copied `images/`, an auditable
`samples.jsonl`, the current recognition dictionary, and
`dataset_report.json`. Validation writers never appear in training. Use
`--allow-small` only to exercise the tooling, never to promote a model.

The six original photographs remain a frozen regression set and must not be
included in either training or threshold tuning.

## 3. Fine-tune a compact CTC recognizer

The bundled `PP-OCRv6_medium_rec` download is an inference artifact, not a
training checkpoint. Do not pretend to fine-tune that ONNX file. Obtain a
matching official training checkpoint/config when Paddle publishes one, or
train a compatible compact PaddleOCR CTC recognizer as a challenger. Keep the
current 18,708-character dictionary and dynamic `3 x 48 x width` input/output
contract so Flutter decoding remains compatible.

From a clean checkout of PaddleOCR, the standard custom-recognition flow is:

```bash
python tools/train.py -c /private/compatible_ctc_rec.yml -o \
  Global.pretrained_model=/private/pretrained/best_accuracy \
  Global.save_model_dir=/private/output/mitlist_rec \
  Global.character_dict_path=/private/mitlist-ocr-dataset/character_dict.txt \
  'Train.dataset.data_dir=/private/mitlist-ocr-dataset' \
  'Train.dataset.label_file_list=[/private/mitlist-ocr-dataset/train.txt]' \
  'Eval.dataset.data_dir=/private/mitlist-ocr-dataset' \
  'Eval.dataset.label_file_list=[/private/mitlist-ocr-dataset/val.txt]'

python tools/export_model.py -c /private/compatible_ctc_rec.yml -o \
  Global.pretrained_model=/private/output/mitlist_rec/best_accuracy \
  Global.character_dict_path=/private/mitlist-ocr-dataset/character_dict.txt \
  Global.save_inference_dir=/private/output/mitlist_rec_inference
```

PaddleOCR's official custom-data format is a relative image path, a tab, and
the transcription. Its official export step produces a static Paddle model.
Convert that model with Paddle2ONNX using dynamic shapes. New Paddle exports use
`inference.json`; older branches use `inference.pdmodel`:

```bash
paddle2onnx \
  --model_dir /private/output/mitlist_rec_inference \
  --model_filename inference.json \
  --params_filename inference.pdiparams \
  --save_file /private/output/mitlist_rec.onnx \
  --opset_version 14 \
  --enable_onnx_checker True
```

References: [PaddleOCR custom recognition datasets and training](https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version2.x/ppocr/model_train/recognition.en.md),
[PaddleOCR training/export installation](https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/installation.en.md), and
[official Paddle2ONNX OCR conversion](https://github.com/PaddlePaddle/PaddleOCR/blob/main/deploy/paddle2onnx/readme.md).

## 4. Reject weak models before the app

Measure both the current and candidate recognizers on the same private
writer-disjoint validation crops:

```bash
python tool/evaluate_ocr_recognizer.py \
  --dataset /private/mitlist-ocr-dataset \
  --model assets/models/ocr/ppocrv6_medium_rec/inference.onnx \
  --characters-json assets/models/ocr/ppocrv6_medium_rec/characters.json \
  --output build/ocr_current_holdout.json

python tool/evaluate_ocr_recognizer.py \
  --dataset /private/mitlist-ocr-dataset \
  --model /private/output/mitlist_rec.onnx \
  --characters-json assets/models/ocr/ppocrv6_medium_rec/characters.json \
  --output build/ocr_candidate_holdout.json
```

A candidate is eligible for device testing only when all of these hold:

- at least 1,000 real corrected lines and at least five writers;
- writer-disjoint holdout CER improves by at least 20% relative;
- exact-line rate improves and no writer regresses catastrophically;
- the frozen six-photo regression benchmark does not regress;
- dynamic-width ONNX compatibility, APK size, and Android/iOS latency pass.

Only after those gates should `inference.onnx` be replaced and a split release
APK built. Keep every old result so model promotion is reversible and auditable.
