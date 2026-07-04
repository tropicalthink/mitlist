# Plan 016: Make the intelligence pipeline docs match what actually ships; retire the dead TFLite-embedder branch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- intelligence/`
> If the README/scripts changed since planning, reconcile before editing.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (Plans 006 and 012 add their own README sections — if they landed, merge around them)
- **Category**: docs / tech-debt
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

`intelligence/README.md` sections 3–4 tell a contributor to export `grocery_embeddings.tflite` and copy it into the app — a file the app has never loaded. The shipped embedder is a Model2Vec-distilled JSON bundle built by `build_embedder_bundle.py`, and none of the six real asset build scripts appear in the README at all. Following the docs produces an artifact nothing consumes and skips the steps that matter. Meanwhile the repo carries the abandoned SentenceTransformer→ONNX→TFLite export chain as committed files, indistinguishable from live pipeline. Stale docs are worse than missing; this is a docs+deletion pass with no runtime risk.

## Current state

- `intelligence/README.md`:
  - `:109-129` — "Phase 7 / Phase 8" training sections; Phase 8 ends in `python export.py → ../models/grocery_embeddings.tflite`.
  - `:131-138` — "Flutter integration": `cp ml/models/grocery_embeddings.tflite ../frontend/assets/models/` — no such asset exists in `frontend/assets/models/` (only `grocery_classifier.*`).
  - `:61` — "~1,800 items"; the shipped seed is 3,242 items, v5, four languages.
  - The six real build scripts are never mentioned: `ml/build_app_seed.py` (→ `assets/grocery/seed.json`), `ml/build_embedder_bundle.py` (→ `embedder_vocab.json` + `catalog_vectors.json` + `embedder_golden.json`), `ml/build_store_aisles.py` (→ `store_aisles.json`), `ml/off_ground.py` + `ml/off_enrich_seed.py` (OpenFoodFacts enrichment → `off_aliases.json`), `ml/mine_corrections_aliases.py` (correction-mining → curated alias candidates for human review).
- `intelligence/ml/build_embedder_bundle.py:1-20` — documents the real architecture: Phase-8 model is only the **distillation teacher**; outputs are the three JSON bundles the app loads via `static_embedding_service.dart:38-39`.
- Dead branch, committed: `intelligence/ml/phase8_embeddings/export.py` (targets the tflite), `intelligence/ml/phase8_embeddings/onnx2tf_out/model_auto.json`. Untracked local artifacts (do NOT delete; gitignore them): `phase8_embeddings/onnx/`, `phase8_embeddings/finetuned/`, `phase8_embeddings/__pycache__/`, `ml/models/grocery_embeddings.onnx`.
- `intelligence/ml/phase8_embeddings/train.py` is **alive** (produces the teacher); `verify_dim.py` — check its references before deciding (`grep -rn "verify_dim" intelligence/` — if nothing references it and its docstring targets the tflite chain, it goes with export.py).
- `intelligence/plan.md:313-318` — "shipped global taxonomy (top ~2,000 grocery items, DE + EN)": stale (3,242 items, DE/EN/FR/ES).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Sanity | `git status intelligence/` | only intended deletions/edits |
| Link check | `grep -rn "grocery_embeddings.tflite" intelligence/ frontend/` | only historical mentions you intentionally kept (ideally none) |

## Scope

**In scope**:
- `intelligence/README.md`
- `intelligence/plan.md` (the two stale numbers only — it's a historical planning doc; do not rewrite it)
- `git rm`: `intelligence/ml/phase8_embeddings/export.py`, `intelligence/ml/phase8_embeddings/onnx2tf_out/model_auto.json`, and `verify_dim.py` if unreferenced
- `.gitignore` (or `intelligence/.gitignore`): the untracked local artifact dirs above

**Out of scope**:
- `phase8_embeddings/train.py` (live teacher), `build_*.py` scripts, any asset regeneration.
- The review-dump data files (`corrections_alias_candidates*.jsonl`, `mined_candidates_deferred.jsonl`, `proposed_new_items.jsonl`) — they are human-curation inputs by design (`mine_corrections_aliases.py:24` says "do NOT auto-merge"); document, don't delete.
- Deleting anything untracked (someone's local training run).

## Git workflow

- Branch: `advisor/016-pipeline-docs-and-dead-code`
- Commit style: `docs(intelligence): document the real asset pipeline; drop dead tflite-embedder branch`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Rewrite README sections 3–4

Replace the Phase-8-export + Flutter-integration sections with the real flow:

1. **Data → assets** table: each `build_*.py` script, its inputs under `ml/data/`, its output asset path, and when to bump which version constant (`ASSET_VERSION` in `build_app_seed.py`; the embedder bundle's version in `build_embedder_bundle.py` — read the script for the exact constant name).
2. **Phase 8 = teacher only**: `train.py` produces `finetuned/`; `build_embedder_bundle.py` distills it (or the e5-small fallback) via Model2Vec into the three JSON bundles; there is no tflite embedder in the app.
3. **Classifier (Phase 7)** stays as-is for training, but the copy step lists only the three `grocery_classifier.*` assets.
4. A one-line pointer per curation file (`curated_aliases.jsonl`, `alias_blocklist.jsonl`, the `mine_corrections_aliases.py` outputs) so they stop looking like dead ends.
5. Fix `:61` "~1,800" → "~3,200 (v5, DE/EN/FR/ES)".

Preserve (don't duplicate, don't delete) the "Calibration eval" section if Plan 006 landed and the parity note if Plan 012 landed.

### Step 2: Delete the dead branch

`git rm intelligence/ml/phase8_embeddings/export.py intelligence/ml/phase8_embeddings/onnx2tf_out/model_auto.json`; run the `verify_dim` reference grep and remove it too if orphaned. Add to `.gitignore` (repo root or a new `intelligence/.gitignore`, matching however the repo already ignores build outputs — check `git check-ignore -v intelligence/ml/phase8_embeddings/finetuned` first):

```
intelligence/ml/phase8_embeddings/onnx/
intelligence/ml/phase8_embeddings/finetuned/
intelligence/ml/models/*.onnx
__pycache__/
```

### Step 3: Fix plan.md numbers

`intelligence/plan.md:315` — update the cold-start block's "top ~2,000 grocery items, DE + EN" to "~3,200 items, DE/EN/FR/ES (seed v5)". Nothing else in that file.

**Verify**: `grep -rn "grocery_embeddings.tflite" intelligence/ frontend/` → no matches; `grep -n "1,800\|~2,000" intelligence/README.md intelligence/plan.md` → no stale counts

## Test plan

Docs-only + deletions: the greps above are the tests. Confirm `git status` shows no accidental data-file deletions.

## Done criteria

- [ ] README documents all six build scripts with input→output paths
- [ ] `grep -rn "grocery_embeddings.tflite" intelligence/ frontend/` → 0 matches
- [ ] Dead files removed from git; local artifacts gitignored, not deleted
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `verify_dim.py` or `export.py` is referenced by any script or doc you're not already editing.
- `git rm` would delete a file with local modifications (someone is actively working in the dead branch).

## Maintenance notes

- The README's data→assets table is now the onboarding contract; Plans 006/012 both add sections around it — whoever executes last reconciles headings.
- If the tflite embedder path is ever revived (e.g. for a native runtime win), restore from git history rather than keeping zombie files.
