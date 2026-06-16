# On-Device OCR Engine Options — Feasibility Analysis
# Plan 012 Workstream C

**Status**: Research spike — no engine swap. Read-only analysis.
**Scope**: Print and handwriting on-device OCR for grocery list scanning (DE + EN).
**Bundle budget**: ~20 MB total (current assets already consume ~18 MB).
**Constraint**: On-device only, no server, fail-soft gracefully.

---

## 1. Current Baseline — Google ML Kit Text Recognition (Latin)

**Package**: `google_mlkit_text_recognition ^0.14.0`
**Script**: `TextRecognitionScript.latin` (covers Latin alphabets including ä/ö/ü)
**Integration point**: `frontend/lib/services/scan/ocr_service.dart`

### Model size
ML Kit's Latin text recognition model is bundled as a Play Services / on-device model:
- Android: downloaded once at install or first use via Google Play Services; not bundled in the APK. Approximate download: **~6–8 MB**.
- iOS: bundled model included in the firebase_ml_vision / mlkit framework: **~4–6 MB** on-disk.
- No cost against the 20 MB bundle budget (it lives in the system ML layer).

### Strengths
- Zero integration effort — already wired.
- Reasonable print accuracy on clean, straight, well-lit text (real-world WER < 5% on printed grocery lists).
- Handles ä/ö/ü natively via Latin script configuration.
- Confidence values per line (usable as OCR confidence signal in `scan_models.dart`).
- Bounding box metadata — mandatory for the review UI image strip.
- Fully offline after initial model download.
- Maintained by Google; SDK updates are transparent.

### Weaknesses
- **Handwriting accuracy is poor** — trained primarily on printed/document text. Real-world grocery handwriting WER: estimated 30–60% on abbreviations/shorthand (e.g. "mlch", "wzmehl", "kfee"). This is the primary ceiling identified in `intelligence/plan.md §5`.
- No per-character confidence; line-level confidence only.
- No multi-candidate output — single best string per line (forces single-pass architecture).
- Character confusion on noisy print: digit-for-letter (0→O, 1→l), umlaut drop. The `ocr_corpus.jsonl` extensively documents the known error taxonomy.
- No direct hook for domain vocabulary to bias recognition.

### Verdict
**Adequate for print; inadequate for handwriting.** The resolution layer (`ensemble_resolver.dart`, `calibrated_scorer.dart`) currently compensates for OCR noise, but the compensation has a ceiling because the OCR output for handwriting is often too corrupted for even fuzzy matching to recover.

---

## 2. PaddleOCR Mobile — PP-OCRv4 / PP-OCRv5 via ONNX / NCNN / Paddle-Lite

### What it is
PaddleOCR is Baidu's open-source OCR system. The mobile variants (PP-OCRv4, PP-OCRv5) use a two-stage pipeline:
- **Detection model** (`det`): localises text regions — typically a DB (Differentiable Binarization) or DBNet++ network.
- **Recognition model** (`rec`): classifies character sequences within each detected region — typically a SVTR or PP-LCNetV3 backbone with a CTC head.

### Model sizes (PP-OCRv4, quantized INT8)
| Component | Full FP32 | INT8 quant | Notes |
|---|---|---|---|
| det (DBNet++) | ~2.3 MB | ~0.9 MB | text region detection |
| rec Latin/DE | ~8.4 MB | ~3.1 MB | char sequence recognition |
| cls (angle) | ~0.7 MB | ~0.3 MB | optional text angle classifier |
| **Total (det + rec + cls)** | **~11.4 MB** | **~4.3 MB** | INT8 is the realistic path |

PP-OCRv5 rec models are slightly larger (~5–6 MB INT8) but improve accuracy on complex fonts and multilingual text.

**Budget impact**: 4–6 MB INT8 is feasible within the ~2 MB of remaining headroom only if the grocery classifier TFLite (~4.9 MB) is compressed or moved to Play Asset Delivery. If the classifier stays, PaddleOCR would exceed the 20 MB hard cap by ~3–5 MB. This is the primary constraint.

### Print accuracy (DE/EN)
PP-OCRv4/v5 was trained on large-scale document corpora including German. Print WER on clean grocery lists: estimated **2–4%** — marginal improvement over ML Kit but not decisive for print. The real gain would be in vocabulary-guided decoding, which PaddleOCR does not natively support without beam search + language model.

### Handwriting accuracy (DE/EN)
Standard PP-OCRv4/v5 rec is trained predominantly on print/document data. Handwriting WER remains high (estimated 25–50% on grocery shorthand). PaddleOCR does have a separate handwriting-specialized model (`PP-HWNet`) but:
- It is not yet production-released as of the knowledge cutoff.
- Its size is unknown but likely >8 MB FP32.
- It is primarily Chinese-character focused; Latin handwriting support is not confirmed at production quality.

**Handwriting conclusion**: PaddleOCR does not solve the handwriting problem in its current production form.

### Runtime / Flutter integration path
PaddleOCR mobile can be deployed via three runtimes:

**Option A: ONNX Runtime (preferred for this stack)**
- Export PP-OCRv4 to ONNX: `paddle2onnx` CLI, well-supported.
- Runtime: `onnxruntime` Flutter plugin (`onnxruntime: ^1.x` on pub.dev) — wraps the ONNX Runtime Mobile C++ library.
- The existing `intelligence/requirements.txt` already includes `onnxruntime>=1.26.0` and `onnx>=1.21.0` for the Python toolchain, so the conversion toolchain is present.
- Flutter integration: load `.onnx` files from `assets/models/`; run det → post-process → crop → rec → decode CTC output.
- **Con**: ONNX Runtime Mobile adds ~5–8 MB to the APK (the native `.so`). This competes with the model budget.

**Option B: NCNN**
- Baidu's lightweight inference framework; `flutter_ncnn` bindings exist but are community-maintained and not actively kept up with Flutter 3.x.
- NCNN binary: ~3–4 MB (smaller than ORT). Better CPU inference speed on ARM.
- **Con**: Dart FFI bindings are unmaintained; significant integration risk.

**Option C: Paddle-Lite**
- Baidu's own mobile runtime. Flutter plugin: `paddlecpp` (community, low maintenance).
- **Con**: No production-quality Flutter package; would require custom platform channel + Dart FFI work. Not recommended.

**Recommended runtime if pursuing PaddleOCR**: ONNX Runtime (Option A). The existing Python toolchain already produces ONNX models. A Dart `OnnxOcrService` could parallel `OcrService` behind an interface switch without touching `ocr_service.dart`.

### Fail-soft behavior
ONNX Runtime Mobile handles missing/corrupt model files gracefully if the Dart wrapper catches `OnnxRuntimeException`; fallback to ML Kit is straightforward via a service interface.

### Multilingual (DE + EN)
PP-OCRv4 rec has a multilingual variant covering German and English. Character coverage includes ä/ö/ü/ß. Umlaut accuracy depends on training data balance — not independently verified for grocery shorthand.

### Summary verdict
PaddleOCR is architecturally sound and the ONNX path is implementable, but:
1. **Size constraint is tight** — det + rec + ORT runtime exceeds the current budget without compressing or moving the grocery classifier.
2. **Does not materially improve handwriting** — the core problem.
3. **Integration complexity is non-trivial** — two-stage pipeline (det + rec), ONNX post-processing, CTC decoding all need Dart implementation or FFI wrapping.

**Recommendation: not worth pursuing until the size budget expands (Play Asset Delivery) AND a handwriting-specialized rec model is available.**

---

## 3. Small Handwriting Model — Distilled/Quantized TrOCR-Small

### What it is
TrOCR (Microsoft) is a transformer-based OCR model treating text recognition as sequence-to-sequence image captioning: a Vision Transformer (ViT) encoder + GPT-2-style decoder. The handwritten variant (`microsoft/trocr-small-handwritten`) is fine-tuned on IAM Handwriting Database.

### Model sizes
| Variant | FP32 | INT8 quant | Notes |
|---|---|---|---|
| `trocr-small-handwritten` (encoder+decoder) | ~330 MB | ~85 MB | Far too large |
| Encoder only (feature extraction) | ~85 MB | ~22 MB | Still too large |
| Knowledge-distilled micro variant (research, not production) | ~15–40 MB INT8 | estimated | No production release |

**Budget impact**: Even the most aggressively distilled TrOCR variant with INT8 quantization would consume 15–40 MB — 1.5–2x the total asset budget. There is no production TrOCR variant that fits on-device in the 20 MB window.

### Handwriting accuracy
TrOCR-small-handwritten achieves CER ~3.3% on IAM (English printed handwriting). However:
- IAM is relatively clean, consistent cursive/print English — **not** the consonant-skeleton shorthand of grocery lists (e.g. "wzmehl", "kfee").
- German handwriting (umlauts, compound words, shorthand) is not in TrOCR's training set.
- Real-world grocery handwriting WER would still be 20–40%+ without grocery-domain fine-tuning.

### Runtime requirements
TrOCR requires a seq2seq runtime capable of autoregressive decoding:
- ONNX Runtime + ONNX decoder loop (encoder once + decoder N-step loop per line).
- Each decode step is a forward pass through the decoder; 20–50 steps per word → **high latency** (500ms–3s per line on a mid-range phone CPU).
- Alternatively: export encoder only + pair with CTC head (requires fine-tuning; not a drop-in).

### Feasibility verdict
**Not feasible.** Size alone disqualifies TrOCR-small at the current budget. Even at a hypothetical 10 MB INT8, the seq2seq decode latency (500ms+ per OCR line) would make scanning a 10-item list take 5–15 seconds of OCR time — violating the product principle ("scanning must be faster than typing").

---

## 4. DeepSeek-OCR — EXCLUDED

**This option is permanently ruled out. Recorded here to prevent re-evaluation.**

### Architecture
DeepSeek-OCR is a vision-language MoE (Mixture of Experts) model consisting of:
- **DeepEncoder** (~380M parameters): a vision encoder based on SAM/ViT-H variant for high-resolution document understanding.
- **DeepSeek-3B-MoE decoder** (~3B total parameters, ~800M active per token): a language model decoder generating text autoregressively.

### Why it fails every constraint

| Constraint | DeepSeek-OCR status |
|---|---|
| On-device, no server | **FAIL** — requires GPU for viable latency; CPU inference is 30–120s per image |
| ~20 MB bundle budget | **FAIL** — ~2 GB at 4-bit quantization (100x over budget) |
| Fail-soft | **FAIL** — loading a 2 GB model on a phone will OOM or take 20+ seconds cold-start |
| Handwriting + grocery shorthand | **IRRELEVANT** — the model targets dense-text document OCR (invoices, academic papers, forms), not grocery shorthand |
| Downstream vocabulary problem | **DOES NOT HELP** — vocabulary correction is a resolution-layer problem; swapping OCR engines doesn't fix missing canonical IDs |

### Runtime requirements
DeepSeek-OCR needs an LLM inference runtime (mlc-llm, llama.cpp-vision, or ONNX Runtime with custom CUDA ops). None of these runtimes exist as production Flutter plugins. The minimum integration effort would be months of custom FFI + platform channel work.

### Bottom line
DeepSeek-OCR solves a different problem (extracting structured data from dense printed documents at server-grade compute) and is fundamentally incompatible with the on-device, bundle-constrained, mobile-latency requirements of mitlist. Do not revisit.

---

## 5. Recommendation

### What to measure after plan-012 A+B land

**Short answer: measure the existing ML Kit baseline on handwriting first** using the eval scaffold in this plan, before committing to any engine change. The hypothesis driving a potential upgrade is "ML Kit handwriting is the accuracy ceiling" — but the actual measured WER on real grocery photos may show the ceiling is actually the resolution/vocabulary layer, not OCR character quality. The eval harness (Deliverable 2) is how you determine this.

**If measured WER confirms OCR is the bottleneck** (i.e., even correct OCR inputs fail to resolve because the recognizer outputs are too corrupted for fuzzy matching), then the only realistic on-device candidate within the budget is:

#### Candidate: Apple Vision Framework (iOS only) + ML Kit (Android) dual path

- **iOS**: `VNRecognizeTextRequest` with `.accurate` recognition level includes Apple's on-device handwriting recognition model. No bundle cost (system framework). Handwriting CER on English: ~5–10% on IAM-style; unknown for German grocery shorthand. This is already available on every iOS 13+ device.
- **Android**: ML Kit remains the baseline. There is no equivalent on-device handwriting model in ML Kit's public API.

**Integration path** (iOS fast path, zero bundle cost):
- A new `OcrServiceAppleVision` that calls `VNRecognizeTextRequest` via platform channel (method channel to Swift).
- Conditioned on `Platform.isIOS`; falls back to ML Kit on Android.
- `ocr_service.dart` is not modified — the switch happens at the DI layer or via an `OcrBackend` enum.

This is the highest-confidence improvement with the lowest risk because it costs nothing in bundle size.

#### Size/latency budget for any future Android handwriting model
If a purpose-trained grocery handwriting recognition model is eventually produced (e.g. fine-tuned CRNN or ASTER on the `ocr_corpus.jsonl` data), it must fit within:

| Budget item | Limit |
|---|---|
| Model size (det + rec, INT8) | ≤ 3 MB |
| Cold-start load time | ≤ 200 ms |
| Per-line inference latency (median) | ≤ 80 ms |
| Total 10-line list inference | ≤ 1.5 s |

A CRNN (CNN + BiLSTM + CTC) with a Latin character set and vocabulary of ~500 grocery tokens can be trained to ~2 MB INT8 and runs at ~20–40 ms/line on mid-range ARM. This is the architecture to fine-tune if Apple Vision proves insufficient on Android users.

### What to skip

| Option | Skip reason |
|---|---|
| TrOCR-small | 85–330 MB, seq2seq latency 500ms+ per line |
| PaddleOCR PP-OCRv4/v5 | Size budget (det + rec + ORT runtime > 20 MB); doesn't fix handwriting |
| DeepSeek-OCR | 2 GB, LLM runtime, wrong problem class |
| Any cloud OCR API | Violates on-device/no-server constraint |

### Sequencing

```
Plan 012 A+B: preprocessing + vocabulary fixes
  ↓
Run OCR eval harness (this deliverable) on pre/post snapshots
  ↓
If print WER < 5% and handwriting WER > 20%:
  → Spike Apple Vision (iOS) — zero bundle cost, one sprint
  → Measure again with eval harness
  ↓
If Android handwriting WER remains > 20%:
  → Evaluate fine-tuned grocery CRNN (~2 MB INT8 target)
  → Must fit within 3 MB net budget increase
```
