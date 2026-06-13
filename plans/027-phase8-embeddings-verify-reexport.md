# Plan 027: Verify and re-export the Phase 8 embeddings; decide on-device shippability

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report. This plan is a **spike + decision
> gate**, not an app integration — do NOT wire embeddings into the Flutter app.
> When done, update the status row in `plans/README.md` unless a reviewer told
> you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c862d307..HEAD -- intelligence/ml/phase8_embeddings/export.py intelligence/ml/phase8_embeddings/train.py`
> If either changed since this plan was written, compare against the "Current
> state" excerpts before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/022 (the embeddings model is trained — `intelligence/ml/phase8_embeddings/finetuned/` and `intelligence/ml/models/grocery_embeddings.onnx` exist)
- **Category**: direction (ML spike / decision)
- **Planned at**: commit `c862d307`, 2026-06-13

## Why this matters

Phase 8 produced `intelligence/ml/models/grocery_embeddings.onnx` — but it is
**470 MB** (full float32 multilingual MiniLM-L12), there is **no TFLite
export**, and the 128-d projection-head question from plan 022 was never
verified. 470 MB cannot be bundled into a mobile app, and an unverified output
dimension means the model might be emitting raw 384-d sentence embeddings
instead of the intended 128-d projected vectors.

This plan answers two questions before anyone tries to integrate embeddings:
1. **Is the projection head actually attached?** (output dim == 128, not 384)
2. **Can the model be made small enough to ship on-device?** (quantized TFLite
   size) — and if not, the honest output is "don't ship on-device; defer to
   server-side or drop," recorded as a decision.

No integration code is written here. The goal is a verified, re-exported,
size-measured model and a clear go/no-go.

## Current state

- `intelligence/ml/models/grocery_embeddings.onnx` — 470 MB, float32, exported
  via `optimum` (from plan 022's `export.py` repair). No `.tflite` exists.
- `intelligence/ml/phase8_embeddings/finetuned/` — the trained
  SentenceTransformer (per plan 022).
- `intelligence/ml/phase8_embeddings/train.py` — base model
  `paraphrase-multilingual-MiniLM-L12-v2`, TripletLoss. Plan 022 Step 3 flagged
  that a 128-d `Dense` projection head must be appended via
  `SentenceTransformer(modules=list(model.children()) + [dense])` and that this
  is only detectable at runtime by checking the encode dimension. **Confirm
  whether train.py actually does this** (read it; plan 022 left it untouched).
- `intelligence/ml/phase8_embeddings/export.py` — plan 022 rewired it to
  `optimum` → `onnx2tf`. Verify whether the `onnx2tf` step ran/produced a
  `.tflite`; only the `.onnx` is present, suggesting the TFLite leg failed or
  was skipped.
- `intelligence/requirements.txt` — ML deps. Phase 8 export needs
  `onnx2tf onnx-graphsurgeon sng4onnx` (noted in plan 022).

This is a **maintainer-run** plan: it requires `intelligence/.venv` with
TensorFlow/optimum/onnx2tf and the trained model on disk — none of which exist
in an isolated worktree. The executor's role is to make the **code/script
changes**; the maintainer runs them. (Same boundary as plans 021/022.)

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Python syntax check | `python3 -m py_compile intelligence/ml/phase8_embeddings/export.py intelligence/ml/phase8_embeddings/train.py` | exit 0 |
| (Maintainer) deps | `cd intelligence && source .venv/bin/activate && pip install -r requirements.txt onnx2tf onnx-graphsurgeon sng4onnx` | exit 0 |
| (Maintainer) dim check | see Step 1 | prints `128` |
| (Maintainer) re-export | `cd intelligence/ml/phase8_embeddings && python3 export.py` | writes a `.tflite`, prints size |

## Scope

**In scope** (executor may modify):
- `intelligence/ml/phase8_embeddings/export.py` (add quantized TFLite export +
  size report + a dimension-assertion guard)
- `intelligence/ml/phase8_embeddings/train.py` (ONLY if Step 1 confirms the
  projection head is missing — append the 128-d Dense head)
- A new helper script `intelligence/ml/phase8_embeddings/verify_dim.py`
  (optional convenience for the maintainer's Step 1 check)

**Out of scope** (do NOT touch):
- Anything under `frontend/` — there is **no app integration in this plan**.
- `intelligence/ml/phase7_classifier/*` — that's plan 026.
- The 470 MB `.onnx` artifact — do not commit it or any model binary.

## Git workflow

- Branch: `advisor/027-phase8-embeddings-verify`
- Conventional commits (e.g. `fix(intelligence): quantize phase8 tflite export`).
- Do NOT push.

## Steps

### Step 1: Determine whether the projection head is attached

Read `intelligence/ml/phase8_embeddings/train.py`. Decide from the code whether
a 128-d `Dense` projection module is appended to the SentenceTransformer before
training/saving.

Create `intelligence/ml/phase8_embeddings/verify_dim.py` for the maintainer to
run (it needs the trained model, so the executor only writes it):
```python
"""Prints the embedding dimension of the finetuned model. Expect 128."""
from pathlib import Path
from sentence_transformers import SentenceTransformer

MODEL_DIR = Path(__file__).resolve().parent / "finetuned"
m = SentenceTransformer(str(MODEL_DIR))
vec = m.encode(["Hafermilch"])
print("embedding dim:", vec.shape[-1])
```

If — and only if — the code review in train.py shows the projection head is
**missing**, add it per plan 022 Step 3:
```python
from sentence_transformers import models
dense = models.Dense(in_features=word_emb_dim, out_features=128, activation_function=torch.nn.Tanh())
model = SentenceTransformer(modules=list(model.modules()) + [dense])  # adjust to the actual var names in train.py
```
(Match the existing variable names and module-list construction in train.py;
do not restructure the training loop.) If the head is already present, leave
train.py untouched and note that.

**Verify (executor)**: `python3 -m py_compile intelligence/ml/phase8_embeddings/train.py intelligence/ml/phase8_embeddings/verify_dim.py` → exit 0.

**Verify (maintainer, post-merge)**: `python3 verify_dim.py` prints
`embedding dim: 128`. If it prints `384`, the head is missing → the maintainer
must apply the train.py fix and **retrain** before the export below is
meaningful.

### Step 2: Add quantized TFLite export + size report to `export.py`

Modify `intelligence/ml/phase8_embeddings/export.py` so the `onnx2tf` step
produces a **quantized** TFLite (float16 at minimum; int8 if a representative
dataset is easy) and prints the resulting file size in MB. After conversion,
add:
```python
out = MODELS_DIR / "grocery_embeddings.tflite"
size_mb = out.stat().st_size / (1024 * 1024)
print(f"grocery_embeddings.tflite = {size_mb:.1f} MB")
if size_mb > 40:
    print("WARNING: >40 MB — likely too large to bundle on-device. "
          "See plan 027 decision gate.")
```
Prefer `onnx2tf`'s float16 output (`-oh5`/`-osd` already in use; add the
float16 flag per onnx2tf docs) or a post-conversion
`TFLiteConverter` float16 pass. Keep the existing optimum→onnx2tf structure from
plan 022; only add quantization + the size print.

**Verify (executor)**: `python3 -m py_compile intelligence/ml/phase8_embeddings/export.py` → exit 0, and `grep -n "size_mb" intelligence/ml/phase8_embeddings/export.py` shows the size report.

### Step 3: Decision gate (maintainer, post-merge — documented, not executed by executor)

After the maintainer runs `python3 export.py`:
- **If `grocery_embeddings.tflite` ≤ ~40 MB and `verify_dim` == 128** → it's a
  GO for on-device. A *separate* future plan handles app integration
  (`tflite_flutter` runtime — already added by plan 026 — plus an
  `EmbeddingService` and a cosine-similarity fallback in
  `CanonicalResolverService` for items the classifier also misses).
- **If > ~40 MB or quantization fails or dim ≠ 128** → NO-GO for on-device.
  Record the decision in `plans/README.md`: embeddings stay server-side (or are
  dropped) and are not bundled. The classifier (plan 026) remains the on-device
  resolution model.

## Done criteria (executor)

- [ ] `python3 -m py_compile intelligence/ml/phase8_embeddings/export.py intelligence/ml/phase8_embeddings/train.py intelligence/ml/phase8_embeddings/verify_dim.py` exits 0
- [ ] `intelligence/ml/phase8_embeddings/verify_dim.py` exists
- [ ] `grep -n "size_mb" intelligence/ml/phase8_embeddings/export.py` returns a match (size report present)
- [ ] export.py produces a `.tflite` with float16 (or int8) quantization, not float32
- [ ] train.py is unchanged UNLESS Step 1's code review found the head missing (state which, in the report)
- [ ] No `frontend/` files and no model binaries were modified/committed
- [ ] `plans/README.md` status row updated

## STOP conditions

- The drift check shows export.py/train.py changed and no longer match the
  "Current state" description.
- Step 1's train.py review is ambiguous about whether the head exists (report
  what you see; don't guess-edit the training loop).
- `onnx2tf`'s quantization flags differ from what plan 022's export.py assumes
  (report the actual onnx2tf interface; don't invent flags).

## Maintenance notes

- This plan deliberately stops at "is it shippable?" The maintainer's
  `verify_dim` + `export.py` run produces the numbers that decide the next step.
- If GO: the future integration plan reuses the `tflite_flutter` dependency plan
  026 adds — no second runtime needed.
- If NO-GO: that is an acceptable outcome. The classifier already covers
  on-device resolution; embeddings were always the more speculative half of the
  intelligence layer (per the maintainer's standing "harden existing features"
  direction).
