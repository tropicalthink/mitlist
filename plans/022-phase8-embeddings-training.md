# Plan 022: Train the Phase 8 grocery embedding model and export it for on-device use

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 6c868661..HEAD -- intelligence/ml/phase8_embeddings/`
> If files under `intelligence/ml/phase8_embeddings/` changed since this plan
> was written, compare the "Current state" excerpts against the live code
> before proceeding; on a mismatch, treat it as a STOP condition.
>
> **Important environment note**: the training data
> `intelligence/ml/data/triplets.jsonl` is git-ignored. It exists only in the
> user's main working tree. **Do NOT run this plan in a fresh clone or isolated
> worktree.** Run in the user's working tree at
> `/home/whtvrboo/Desktop/dev/mitlist`. Training fine-tunes a transformer and
> is slow (~hours on CPU); a GPU is strongly preferred but not required.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (training is straightforward; the ONNX→TFLite export is the
  fragile part and is explicitly fenced)
- **Depends on**: 021 (only for the shared `pip install -r requirements.txt`;
  if 021 already ran, the heavy deps are present. Otherwise this plan installs
  them in Step 1.)
- **Category**: ml-training
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

The Phase 8 embedding model powers semantic similarity, substitutes,
suggestions, and canonical matching for **unknown** items — the cases the
Phase 7 classifier and the alias table miss (plan.md §7 "Embeddings over this
graph power similarity… without calling an LLM", §18 Phase 8). It fine-tunes a
multilingual sentence-transformer with triplet loss so that, e.g., `Hafermilch`
and `lait d'avoine` (oat milk in two languages) sit close together while
`Mandelmilch` (almond milk) sits apart.

The training script and the 7,052-row triplet dataset both exist. The training
half is essentially ready. The **export half is broken**: `export.py` tries to
convert ONNX → TF using `tf2onnx`, which only converts the *other* direction
(TF → ONNX), and it invokes `python` (absent on this Debian box) instead of
`python3`. This plan trains the model, produces a reliable ONNX artifact, and
replaces the broken TFLite conversion with a working one.

After this plan: a fine-tuned model in
`intelligence/ml/phase8_embeddings/finetuned/`, a measured triplet-eval
accuracy, and an exported on-device artifact in `intelligence/ml/models/`.

## Current state

Files (paths relative to repo root `/home/whtvrboo/Desktop/dev/mitlist`):

- `intelligence/ml/phase8_embeddings/train.py` — fine-tunes
  `paraphrase-multilingual-MiniLM-L12-v2` with `TripletLoss` (cosine,
  margin 0.3), adds a 128-d `Dense` projection head, evaluates with
  `TripletEvaluator`, saves to `finetuned/`, and records model-version metadata
  to `progress.db`. **This file is essentially correct; see Step 3 for one
  optional robustness check only.**
- `intelligence/ml/phase8_embeddings/export.py` — **broken**. Current body:
  ```python
  subprocess.run(["python", "-m", "optimum.exporters.onnx",
      "--model", str(MODEL_DIR), "--task", "feature-extraction", str(ONNX_DIR)], check=True)
  pb_dir = OUT_DIR / "model.pb"
  subprocess.run(["python", "-m", "tf2onnx.convert",          # WRONG: tf2onnx is TF->ONNX
      "--onnx", str(ONNX_DIR / "model.onnx"),
      "--output", str(pb_dir), "--opset", "13"], check=True)
  ...
  converter = tf.lite.TFLiteConverter.from_saved_model(str(pb_dir))   # pb_dir is never a valid saved_model
  ```
  Two defects: (1) `python` should be `python3`; (2) `tf2onnx.convert` cannot
  turn an ONNX file into a TF SavedModel — the direction is reversed, so
  `from_saved_model` gets a non-existent/invalid input.
- `intelligence/ml/data/triplets.jsonl` — 7,052 rows. Field shape:
  ```json
  {"anchor_de":"Hafermilch","anchor_en":"oat milk","anchor_fr":"lait d'avoine","anchor_es":"leche de avena",
   "positive_text":"lait d'avoine","positive_type":"different_language","positive_lang":"fr",
   "negative_de":"Mandelmilch","negative_en":"almond milk","negative_fr":"lait d'amande","negative_es":"leche de almendras",
   "negative_subtype":"SAME_CATEGORY_HARD","reason":"both plant-based milks"}
  ```
  `train.py`'s `load_triplets` already reads these fields correctly (verified:
  `anchor_de`, `positive_text`, `negative_de` all present) and expands extra
  cross-language pairs, yielding well over 7,052 `InputExample`s.

Repo convention: `python3` only (no `python`), venv at `intelligence/.venv`,
model-version metadata written via `generator.progress.ProgressStore` at the
end of training (keep that try/except block as-is).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Activate venv | `source intelligence/.venv/bin/activate` | prompt shows `(.venv)` |
| Install ML deps | `pip install -r intelligence/requirements.txt` | exit 0 (torch, sentence-transformers 3.0.1, optimum, onnx) |
| Verify deps | `python3 -c "import torch, sentence_transformers; print('ok')"` | prints `ok` |
| Train | `cd intelligence/ml/phase8_embeddings && python3 train.py` | finishes; `finetuned/` created; eval score printed |
| Export ONNX | (in export.py, Step 4) | `onnx/model.onnx` created |
| Install converter | `pip install onnx2tf onnx-graphsurgeon sng4onnx` | exit 0 |

> The venv currently has **no ML dependencies installed** (verified:
> `import torch` fails). The install step is mandatory. The first `train.py`
> run also downloads the ~470 MB base model from Hugging Face — network access
> is required for that first run.

## Scope

**In scope** (the only files you may modify):
- `intelligence/ml/phase8_embeddings/export.py`
- `intelligence/ml/phase8_embeddings/train.py` (only if Step 3's check fails)
- Generated artifacts: `intelligence/ml/phase8_embeddings/finetuned/**`,
  `intelligence/ml/phase8_embeddings/onnx/**`,
  `intelligence/ml/models/grocery_embeddings*` (all git-ignored or model output)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch):
- `intelligence/ml/phase7_classifier/**` — that is plan 021.
- `intelligence/ml/data/triplets.jsonl` and any other data file — inputs only.
- The `TripletLoss` hyperparameters (margin, epochs, batch size) — do not tune
  them in this plan; train with the values already in `train.py`.
- `intelligence/generator/**`, `intelligence/config/**`, `progress.db`.

## Git workflow

- Branch: `advisor/022-phase8-embeddings-training`
- Commit the `export.py` fix (and `train.py` only if changed) with a
  conventional-commit message, e.g.
  `fix(intelligence): repair phase8 embedding export (onnx2tf, python3)`.
  End the body with the repo's Co-Authored-By trailer.
- Do not commit the generated model artifacts. Do not push or open a PR unless
  instructed.

## Steps

### Step 1: Install ML dependencies

```bash
source intelligence/.venv/bin/activate
pip install -r intelligence/requirements.txt
python3 -c "import torch, sentence_transformers; print(sentence_transformers.__version__)"
```

**Verify**: prints a version (expected `3.0.1`). If install fails, STOP and
report the pip error and `python3 --version`.

### Step 2: Train the embedding model

```bash
cd intelligence/ml/phase8_embeddings
python3 train.py
```

**Verify**, ALL must hold:
- Prints `Loaded N triplets` with **N > 7,000** (the loader expands
  cross-language pairs, so N is typically ~15,000–25,000; if N is `0`, STOP).
- A `TripletEvaluator` accuracy is printed during/after fit (cosine-distance
  triplet accuracy, range 0–1). Record it. A healthy fine-tune lands **≥ 0.85**;
  the base model alone is usually ~0.7–0.8, so improvement over baseline is the
  signal.
- Prints `Training complete → .../finetuned`.
- `ls intelligence/ml/phase8_embeddings/finetuned/` shows a saved model
  (e.g. `config.json`, model weights).

If triplet eval accuracy is **< 0.75**, STOP and report it — do not change
hyperparameters (out of scope); the triplet data or projection head may need
review separately.

### Step 3: (Conditional) confirm the projection head is actually applied

`train.py` adds the 128-d head via
`model.add_module("dense_projection", dense)`. Confirm the saved model's output
dimension is 128 (the head took effect), not 384 (the base dimension):

```bash
cd intelligence/ml/phase8_embeddings
python3 -c "
from sentence_transformers import SentenceTransformer
m = SentenceTransformer('finetuned')
import numpy as np
v = m.encode(['Hafermilch'])
print('dim', v.shape[-1])
"
```

**Verify**: prints `dim 128`.
- If it prints `dim 384`, the projection head was not serialized into the
  sentence-transformers module pipeline. Fix in `train.py` by constructing the
  Dense as a proper pipeline module and appending it via the modules list
  instead of `add_module`, i.e. replace:
  ```python
  dense = Dense(in_features=model.get_sentence_embedding_dimension(),
                out_features=128, activation_function=torch.nn.Tanh())
  model.add_module("dense_projection", dense)
  ```
  with:
  ```python
  dense = Dense(in_features=model.get_sentence_embedding_dimension(),
                out_features=128, activation_function=torch.nn.Tanh())
  model = SentenceTransformer(modules=list(model.children()) + [dense])
  ```
  then re-run Step 2 and re-verify here. If it still prints 384 after this,
  STOP and report — do not improvise further.

### Step 4: Fix `export.py` to produce ONNX, then TFLite via `onnx2tf`

Replace the broken `tf2onnx` step. The reliable path is:
optimum (sentence-transformers → ONNX) → `onnx2tf` (ONNX → TFLite directly).
`onnx2tf` emits TFLite files itself, so the intermediate TF SavedModel and the
`tf.lite` converter call are no longer needed.

First install the converter:
```bash
pip install onnx2tf onnx-graphsurgeon sng4onnx
```

Then rewrite `export.py` to this shape:

```python
"""Export Phase 8 embeddings: sentence-transformers -> ONNX -> TFLite (onnx2tf)."""

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
MODELS_DIR = ROOT / "ml" / "models"

MODEL_DIR = OUT_DIR / "finetuned"
ONNX_DIR = OUT_DIR / "onnx"
TF_OUT_DIR = OUT_DIR / "onnx2tf_out"
TFLITE_OUT = MODELS_DIR / "grocery_embeddings.tflite"


def main() -> None:
    if not MODEL_DIR.exists():
        raise SystemExit(f"Missing {MODEL_DIR}. Run train.py first.")

    ONNX_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["python3", "-m", "optimum.exporters.onnx",
         "--model", str(MODEL_DIR),
         "--task", "feature-extraction",
         str(ONNX_DIR)],
        check=True,
    )

    # onnx2tf writes a set of .tflite files into TF_OUT_DIR
    subprocess.run(
        ["onnx2tf", "-i", str(ONNX_DIR / "model.onnx"),
         "-o", str(TF_OUT_DIR), "-osd"],
        check=True,
    )

    # Pick the float32 (or float16) tflite onnx2tf produced and copy it out.
    candidates = sorted(TF_OUT_DIR.glob("*float32*.tflite")) or sorted(TF_OUT_DIR.glob("*.tflite"))
    if not candidates:
        raise SystemExit(f"onnx2tf produced no .tflite in {TF_OUT_DIR}")
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(candidates[0], TFLITE_OUT)
    print(f"Saved {TFLITE_OUT.stat().st_size / 1024 / 1024:.1f} MB → {TFLITE_OUT} (from {candidates[0].name})")


if __name__ == "__main__":
    main()
```

**Verify**:
```bash
cd intelligence/ml/phase8_embeddings
python3 export.py
ls -la ../models/grocery_embeddings.tflite
```
Expected: prints `Saved <N> MB → …/grocery_embeddings.tflite` and the file
exists and is non-empty (a MiniLM-L12 embedding model is typically ~80–120 MB
float32, smaller if onnx2tf emits a quantized variant).

### Step 5: Sanity-check the exported TFLite produces embeddings

```bash
cd intelligence/ml/phase8_embeddings
python3 -c "
import numpy as np, tensorflow as tf
it = tf.lite.Interpreter('../models/grocery_embeddings.tflite')
it.allocate_tensors()
print('inputs', [d['name'] for d in it.get_input_details()])
print('output shape', it.get_output_details()[0]['shape'])
"
```

**Verify**: the command runs without error and prints an output shape whose
last dimension is the embedding size (128 if Step 3 confirmed the head, else
384). If it errors, the TFLite is malformed — STOP and report the error and the
`onnx2tf` output from Step 4.

## Test plan

No unit-test harness exists for this subproject. Verification is: (a) Step 2's
triplet-eval accuracy beats the base model, and (b) Steps 4–5 produce a TFLite
that loads and reports a sane output shape. There are no new test files to
write in this plan.

## Done criteria

ALL must hold:

- [ ] `python3 -c "import torch, sentence_transformers; print('ok')"` prints `ok`
- [ ] `python3 train.py` completes; `Loaded N triplets` shows N > 7,000;
      `finetuned/` exists; triplet-eval accuracy recorded and ≥ 0.75
- [ ] Step 3 sanity check prints the expected embedding dimension
- [ ] `export.py` no longer references `tf2onnx` or invokes bare `python`
      (`grep -n "tf2onnx\|\"python\"\|'python'" export.py` returns nothing)
- [ ] `intelligence/ml/models/grocery_embeddings.tflite` exists and is non-empty
- [ ] Step 5 loads the TFLite and prints an output shape without error
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row for 022 updated with the achieved eval score

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows `train.py` / `export.py` already differ from the
  "Current state" excerpts.
- `Loaded N triplets` is `0` (data path or field names wrong).
- Triplet-eval accuracy < 0.75 after a clean run.
- Step 3 still reports `dim 384` after applying the projection-head fix.
- `onnx2tf` fails to install or fails to convert the ONNX model. In that case,
  report the error and **leave the working ONNX model in place** (`onnx/model.onnx`)
  — the ONNX artifact is itself usable on-device via onnxruntime, and the
  TFLite conversion is the only blocked part. Do not hand-roll a converter.
- Any step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

For whoever owns this next:

- ONNX→TFLite for transformers is the brittle link. `onnx2tf` is the currently
  reliable tool; `tf2onnx` (what was here) is the wrong direction and
  `onnx-tf` is frequently broken on TF 2.16. If `onnx2tf` regresses, the ONNX
  model is the fallback runtime artifact.
- The projection head dimension (128) defines the on-device embedding size; the
  Flutter `CanonicalItemResolver` / embedding index must use the same
  dimension. If you change `out_features` in `train.py`, update the app side.
- Embedding and classifier (plan 021) are complementary: the classifier handles
  known canonicals fast; embeddings handle unknown/novel items. The app wires
  embeddings in as the fallback when classifier confidence and alias lookup
  both miss (README §4, plan.md §10 confidence gate).
- Reviewer should scrutinize: that `export.py` selects the intended precision
  variant from `onnx2tf`'s multiple outputs (the glob picks float32 first), and
  that the chosen `.tflite`'s output shape matches the trained head.
