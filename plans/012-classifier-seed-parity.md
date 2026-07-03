# Plan 012: Add a classifier↔seed parity gate so taxonomy drift is visible

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/assets/models/ intelligence/ml/ .gitea/workflows/ci.yml`
> If the model assets or seed were regenerated since planning, re-derive the counts in "Current state" before proceeding.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (pairs well with plan 006's CI eval step)
- **Category**: tests / data
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The on-device classifier predicts **canonical display names** (German), which the resolver maps back to items via the alias table (`candidate_generator.dart:69-79`: `findAlias(aliasText: normaliseText(p.label))`). That mapping only works while every model label still exists as an alias in the shipped seed. The model was trained against a pre-v5 seed snapshot: `grocery_classifier_labels.txt` has 3,185 labels while `seed.json` (version 5, rebuilt two days later) has 3,242 items. Items renamed in v5 make the classifier's vote silently unresolvable; items added are simply unclassifiable. Nothing measures either. This plan adds a parity checker that quantifies orphaned labels and coverage, wires it into CI as a gate, and documents the retrain path — it does **not** retrain the model (that needs TF + the training corpus; the gate tells you when it's worth doing).

## Current state

- `frontend/assets/models/grocery_classifier_labels.txt` — 3,185 lines, one German canonical name per line (`Aal`, `Absinth`, …), in `label_encoder.classes_` order (see `intelligence/ml/phase7_classifier/export.py:10`).
- `frontend/assets/grocery/seed.json` — `{version: 5, items: [...]}`, 3,242 items, each with `id`, `name_de/en/fr/es`, `aliases_de/en/fr/es`. The seed loader also registers each `name_*` as an alias (`grocery_seed_loader.dart:187-191`), so "label resolvable" ≙ "normalised label ∈ union(all aliases, all names)".
- The consumption path — `frontend/lib/services/scan/resolution/candidate_generator.dart:69-79`: an unresolvable label costs a candidate vote *and* wastes one of the `topK=5` slots.
- Normalisation the check must reproduce: lowercase, trim, collapse internal whitespace (`frontend/lib/services/scan/resolution/string_sim.dart:7-8`).
- Training/export live in `intelligence/ml/phase7_classifier/` (`train.py`, `export.py`); the export writes the three assets the app loads (`grocery_classifier_service.dart:29-32`).
- CI: `.gitea/workflows/ci.yml` — `frontend` job (checkout, flutter, analyze, test). Ubuntu runner has `python3`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Run checker | `python3 intelligence/ml/check_classifier_parity.py` | prints a report; exit 0 below threshold |
| Frontend tests | `cd frontend && flutter test test/services/` | pass |
| CI lint | eyeball indentation against sibling steps | consistent |

## Scope

**In scope**:
- `intelligence/ml/check_classifier_parity.py` (create)
- `.gitea/workflows/ci.yml` (one step)
- `intelligence/README.md` (a "Retraining the classifier" paragraph correcting the stale section — coordinate with Plan 016, which rewrites those docs; if 016 already landed, just add the parity note)

**Out of scope**:
- Retraining/exporting the model (needs TF + `ml/data/ocr_corpus.jsonl` + GPU time; the checker's report is the input to that decision).
- Any change to `candidate_generator.dart` (a fallback fuzzy-match for orphaned labels would mask the drift this gate exists to expose).
- Switching the model to predict ids instead of names — right long-term fix, but it's a retrain-time change; note it in the script's docstring.

## Git workflow

- Branch: `advisor/012-classifier-seed-parity`
- Commit style: `test(intelligence): classifier↔seed parity gate in CI`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: The checker script

Create `intelligence/ml/check_classifier_parity.py` (stdlib only, like `eval/resolution_eval.py`):

1. Load `frontend/assets/models/grocery_classifier_labels.txt` and `frontend/assets/grocery/seed.json` (resolve paths relative to the repo root via `Path(__file__).resolve().parents[2]`).
2. Build the resolvable-alias set: for every item, all four `name_*` plus all four `aliases_*` lists, each normalised (lowercase, strip, collapse internal whitespace — reimplement the 3-line normaliser with a comment pointing at `string_sim.dart:7-8`).
3. Report: total labels; **orphaned labels** (normalised label not in the set) with up to 20 examples; **uncovered items** (seed items whose `name_de` is not among the labels — new-in-v5 items the model can't predict) as a count.
4. Exit non-zero when `orphaned / total > 0.02` (2% — generous enough to pass today *if* v5 was mostly additive; the run itself will tell you). Print the threshold and the actual rate either way.

**Verify**: `python3 intelligence/ml/check_classifier_parity.py` → prints the report. Record the orphan rate in your completion report. If it exits non-zero, that is a *finding, not a failure of this plan* — see STOP conditions for how to proceed.

### Step 2: CI step

In `.gitea/workflows/ci.yml`, add to the `frontend` job (after Analyze — it needs no Flutter, just the checkout):

```yaml
      - name: Classifier/seed parity
        run: python3 intelligence/ml/check_classifier_parity.py
```

### Step 3: Document the retrain path

In `intelligence/README.md`, next to the Phase 7 section: when the parity gate fails, retrain — `cd intelligence/ml/phase7_classifier && python train.py && python export.py`, then copy the three assets to `frontend/assets/models/` (the copy commands already in the README §4 are correct for the classifier), then re-run the checker. One sentence noting the future improvement: emitting ids as labels removes this class of drift entirely.

**Verify**: `grep -n "check_classifier_parity" intelligence/README.md .gitea/workflows/ci.yml` → both present

## Test plan

The script is its own test (deterministic over committed assets). Sanity-check it catches drift: temporarily append a fake label `zzz_not_a_real_item` to a *copy* of the labels file and run with `--labels <copy>` (add that flag) → orphan count increments. Do not modify the real asset.

## Done criteria

- [ ] `python3 intelligence/ml/check_classifier_parity.py` runs and prints total/orphaned/uncovered with examples
- [ ] The `--labels` override proves detection (report the fake-label run output)
- [ ] CI step added
- [ ] README updated
- [ ] Completion report states the actual orphan rate and whether the gate currently passes
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The orphan rate exceeds 2% on the committed assets: wire everything, set the CI step to `continue-on-error: true` with a `# TODO: retrain, see plans/012` comment, and report the rate — a red main branch on a pre-existing data condition helps nobody, but the signal must be visible.
- `seed.json` lacks the `aliases_*`/`name_*` shape described (asset format changed) — re-derive from `grocery_seed_loader.dart` and report the diff.

## Maintenance notes

- Every seed rebuild (`build_app_seed.py`, bumping `ASSET_VERSION`) should be followed by this checker; the CI step enforces that ordering socially.
- The real fix at next retrain: labels = canonical **ids**. That also removes the `findAlias` hop per prediction (see Plan 007's batching of that hop).
- Reviewer should scrutinize: the normaliser matches `string_sim.dart` exactly (unicode case-folding differences between Python `.lower()` and Dart `.toLowerCase()` are acceptable at this data's ASCII/latin-1 profile — note if the orphan examples suggest otherwise).
