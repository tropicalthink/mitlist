# Plan 006: Close the calibration loop — one-command eval, fitted weights, CI gate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- intelligence/ml/eval/ frontend/test/services/resolution_baseline_test.dart frontend/test/services/resolution_feature_export_test.dart .gitea/workflows/ci.yml intelligence/run.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (independent of 001-005)
- **Category**: tests / dx
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The "calibrated scorer" that ranks every grocery resolution runs on hand-set weights, permanently: the fitted bundle it is designed to load (`assets/grocery/resolution_weights.json`) has never existed. The fitter works, but it writes to a staging path, the ship step is a comment, its own docstring contradicts its default, and nothing in CI runs any eval — so the calibration pipeline is a chain of three manual steps nobody performs. Meanwhile the regression test that compares ensemble vs baseline **silently skips** when the eval file is missing. This plan turns the chain into one command, makes the skip a failure, adds a holdout split so the fit is honest, and wires an eval job into CI. Shipping a fitted bundle happens only if it beats the hand defaults on held-out data — otherwise the mechanics still land and the defaults remain (which the fail-soft loader already handles).

## Current state

- `intelligence/ml/eval/resolution_eval.py` — pure-stdlib logistic fitter. Docstring (lines 17-24) documents `--out frontend/assets/grocery/resolution_weights.json`, but the argparse default (lines 150-156) is the staging path:

```python
    # Staging path by default — NOT shipped. Copy into
    # frontend/assets/grocery/ (versioned) only after confirming the fit beats
    # the hand-tuned CalibratedScorer defaults on the eval (precision@auto at
    # equal-or-higher coverage). The eval harness exists to catch a regression
    # here before it ships.
    ap.add_argument("--out",
                    default=str(repo / "intelligence/ml/data/resolution_weights.json"))
```

No `resolution_weights.json` exists anywhere in the repo (staging or asset). The fitter reads `intelligence/ml/data/resolution_features.jsonl` (1,397 rows, `# feature_names:` header, 10 features) and also writes `--golden`.

- `frontend/lib/services/scan/resolution/calibrated_scorer.dart:52-86` — loads `assets/grocery/resolution_weights.json`, **fails soft to hand defaults** on absence/malformation/feature-name mismatch. `assets/grocery/` is already a pubspec asset directory (`frontend/pubspec.yaml:118`), so adding the file requires no pubspec change.

- `frontend/test/services/resolution_feature_export_test.dart:38-44` — the Dart feature exporter, gated on `EXPORT_RESOLUTION_FEATURES=1`; in a plain `flutter test` the classifier/embedder columns export as 0 (comment lines 27-29).

- `frontend/test/services/resolution_baseline_test.dart:108-113` — the ensemble-vs-baseline guard **skips** when `../intelligence/ml/data/resolution_eval.jsonl` is absent:

```dart
    final file = File(_evalPath);
    if (!file.existsSync()) {
      markTestSkipped('eval dataset not present at $_evalPath');
      return;
    }
```

The eval set has 65 rows (35 handwriting / 30 print). This is a monorepo — the path always exists in a full checkout, so the skip only ever fires on a *broken* path, which is exactly when it should fail.

- `.gitea/workflows/ci.yml` — `backend` job (go build/vet/test) and `frontend` job (pub get, analyze, `flutter test`). No Python anywhere.

- `intelligence/run.sh` — thin wrapper around `python3 -m generator.runner "$@"` (generation CLI only; no eval subcommand).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Feature export | `cd frontend && EXPORT_RESOLUTION_FEATURES=1 flutter test test/services/resolution_feature_export_test.dart` | 1 test passes; `intelligence/ml/data/resolution_features.jsonl` rewritten |
| Fit | `python3 intelligence/ml/eval/resolution_eval.py` | prints metrics; writes weights + golden |
| Baseline guard | `cd frontend && flutter test test/services/resolution_baseline_test.dart` | passes (no skip) |
| Full frontend tests | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `intelligence/ml/eval/resolution_eval.py`
- `intelligence/eval.sh` (create — the one-command entrypoint)
- `frontend/test/services/resolution_baseline_test.dart`
- `.gitea/workflows/ci.yml`
- `frontend/assets/grocery/resolution_weights.json` (create **only if** the ship gate passes)
- `intelligence/README.md` (one section: how to run the eval + ship)

**Out of scope**:
- Growing the 65-row eval set — that needs human/LLM authoring of labelled cases; record it as a follow-up in the PR description.
- `calibrated_scorer.dart` / feature code — the parity contract must not move.
- `resolution_feature_export_test.dart` behavior (the env-gate is correct; CI will set the flag).

## Git workflow

- Branch: `advisor/006-ship-calibrated-weights`
- Commit style: `feat(intelligence): one-command resolution eval with holdout gate and CI job`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add a query-level holdout split to the fitter

In `resolution_eval.py`: group rows by `(raw_text, input_type)` (candidate rows for one query must stay together), split ~75/25 deterministically (hash of the key, not `random`), fit on train, and report on holdout: `precision@auto`, `coverage@auto` (fraction of holdout queries auto-accepted), using the fitted `tau_auto`. Also compute the same two metrics for the **hand-set defaults** (`kDefaultWeights`/bias/tau are documented in `frontend/lib/services/scan/resolution/calibrated_scorer.dart:93-106` — copy them into the script as constants with a comment naming the source). Print both. Add `--holdout 0.25` and `--seed`-free determinism (hash-based).

**Verify**: `python3 intelligence/ml/eval/resolution_eval.py` → prints `train=… holdout=…` metrics for BOTH fitted and default weights, exits 0

### Step 2: Align the docstring, default, and ship gate

- Make the docstring Usage block match the real defaults (staging `--out` stays the default — deliberate; shipping is the explicit step below).
- Add a `--ship` flag: when set AND the fitted holdout metrics are ≥ defaults on precision@auto AND ≥ defaults on coverage@auto, write the bundle to `frontend/assets/grocery/resolution_weights.json` (in addition to staging) and print `SHIPPED`. Otherwise print `NOT SHIPPED: <reason>` and exit 0 (not shipping is a valid outcome).
- The bundle must include `feature_names` exactly matching the Dart `kResolutionFeatureNames` order (the loader rejects mismatches — see `calibrated_scorer.dart:73-75`; the exporter's `# feature_names:` header is the source).

**Verify**: `python3 intelligence/ml/eval/resolution_eval.py --ship` → prints `SHIPPED` or `NOT SHIPPED: …`; if shipped, `frontend/assets/grocery/resolution_weights.json` exists and `cd frontend && flutter test test/services/canonical_resolver_service_test.dart` still passes

### Step 3: One-command entrypoint

Create `intelligence/eval.sh` (executable, `#!/usr/bin/env bash`, `set -euo pipefail`):

```bash
# 1. Re-export features from the Dart parity exporter
(cd "$(dirname "$0")/../frontend" && EXPORT_RESOLUTION_FEATURES=1 flutter test test/services/resolution_feature_export_test.dart)
# 2. Fit + report (pass --ship through when given)
python3 "$(dirname "$0")/ml/eval/resolution_eval.py" "$@"
```

**Verify**: `intelligence/eval.sh` → exits 0, prints the metrics block

### Step 4: Make the baseline guard fail instead of skip

In `resolution_baseline_test.dart:108-113`, replace `markTestSkipped(...); return;` with `fail('eval dataset missing at $_evalPath — this guard must not pass vacuously');`. Apply the same change to any sibling skip-on-missing-file in `resolution_feature_export_test.dart`? **No** — that one's env-var gate stays (it's a writer, not a guard); only the missing-*dataset* skip inside it may remain too. Touch only the baseline test.

**Verify**: `cd frontend && flutter test test/services/resolution_baseline_test.dart` → passes (dataset present); then `mv intelligence/ml/data/resolution_eval.jsonl /tmp/x && cd frontend && flutter test test/services/resolution_baseline_test.dart; mv /tmp/x ../intelligence/ml/data/resolution_eval.jsonl` → the middle run FAILS (then restored)

### Step 5: CI job

In `.gitea/workflows/ci.yml`, add a step to the existing `frontend` job **after** the Test step (reuses the Flutter setup):

```yaml
      - name: Resolution eval (report-only)
        run: |
          cd frontend && EXPORT_RESOLUTION_FEATURES=1 flutter test test/services/resolution_feature_export_test.dart
          python3 ../intelligence/ml/eval/resolution_eval.py
```

Report-only: it fails the job only if the exporter or fitter errors (e.g. feature-layout drift breaks the parity header), not on metric values. Check the runner image has `python3` (ubuntu-latest does).

**Verify**: `python3 -c "import yaml,sys; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` → exits 0 (if PyYAML is unavailable, verify indentation matches the sibling steps by eye and note it)

### Step 6: Document

In `intelligence/README.md`, add a short "Calibration eval" section: what `eval.sh` does, what `--ship` requires, and that the app falls back to hand defaults when no bundle ships.

**Verify**: `grep -n "eval.sh" intelligence/README.md` → present

## Test plan

- Step 4's fail-not-skip is itself the test change; prove both directions (present → pass, absent → fail).
- After Step 2, if a bundle shipped: `flutter test test/services/` all green (the scorer loads the bundle in any test that constructs it via `CalibratedScorer.load()` with the root bundle — widget-test asset loading uses the app bundle, so also run `flutter test test/services/canonical_resolver_service_test.dart` explicitly).
- Full `cd frontend && flutter test` green.

## Done criteria

- [ ] `intelligence/eval.sh` exists, is executable, and exits 0 end-to-end
- [ ] `python3 intelligence/ml/eval/resolution_eval.py` prints holdout metrics for fitted AND default weights
- [ ] `grep -n "markTestSkipped" frontend/test/services/resolution_baseline_test.dart` → no matches
- [ ] CI workflow contains the eval step
- [ ] EITHER `frontend/assets/grocery/resolution_weights.json` exists (ship gate passed) OR the fitter run log shows `NOT SHIPPED: <reason>` — paste whichever into the completion report
- [ ] `cd frontend && flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The feature export produces a `# feature_names:` header that does not match `kResolutionFeatureNames` in `resolution_features.dart:35-46` — parity is broken upstream; fitting against it would ship wrong weights.
- `flutter test` cannot run on this machine (missing libsqlite3) — the export step is the only way to regenerate features; report instead of hand-editing the jsonl.
- With 65 queries the holdout contains < 10 queries — still implement everything, but do NOT pass `--ship`; report that the eval set must grow first (this is the expected outcome; say so plainly).

## Maintenance notes

- The eval set (65 rows) is the real bottleneck — precision numbers from it are indicative, not proof. The follow-up (out of scope here) is authoring 300+ labelled cases across languages/input types; the mechanics this plan lands make that immediately valuable.
- Changing `kResolutionFeatureNames` (order or content) invalidates bundle + golden + features dump; the loader's parity guard catches the app side, Step 5's CI step catches the pipeline side.
- Reviewer should scrutinize: the holdout split is by query (not by candidate row) and deterministic.
