# Plan 041: Restore a working `build_runner` and gate generated-code freshness in CI

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/pubspec.yaml AGENTS.md .gitea/workflows/ci.yml`
> On any change, re-read AGENTS.md's "Regenerating generated code" section first.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED (bumping retrofit may ripple through generated client signatures)
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

Codegen is pinned-broken: per `AGENTS.md`, `dart run build_runner build` "currently
fails on a retrofit/retrofit_generator version mismatch" and requires a manual
`dependency_overrides` dance then a revert. CI explicitly does NOT run
`build_runner`; the generated files (including `app_database.g.dart`, 12,817 lines)
are hand-committed. So regenerating Drift/retrofit/json code is a fragile, error-
prone ritual, and nothing checks that the committed generated files still match
their sources — a contributor can silently desync 12k+ lines. Fixing the version
pin and adding a freshness check makes codegen routine and self-verifying.

## Current state

- `AGENTS.md` "Regenerating generated code" documents the retrofit/retrofit_generator
  mismatch and the manual override workaround.
- `.gitea/workflows/ci.yml:2` header: "Does NOT run build_runner (codegen is
  pinned-broken; generated files are committed)".
- Committed generated artifacts: `frontend/lib/storage/app_database.g.dart` and
  any `*.g.dart`/`*.freezed.dart` under `frontend/lib/`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Outdated | `cd frontend && flutter pub outdated \| grep -i retrofit` | shows retrofit versions |
| Codegen | `cd frontend && dart run build_runner build --delete-conflicting-outputs` | exit 0 (the goal) |
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass |
| Freshness | `git diff --exit-code -- frontend/lib` | exit 0 after a clean regen |

## Scope

**In scope**:
- `frontend/pubspec.yaml` (resolve the retrofit/retrofit_generator versions)
- Regenerated `*.g.dart` files under `frontend/lib/` (the output of a clean run)
- `.gitea/workflows/ci.yml` (add a freshness check)
- `AGENTS.md` (update the now-obsolete "pinned-broken" instructions)

**Out of scope**:
- Hand-editing generated files — they must come from `build_runner` only.
- The Drift schema or retrofit client definitions (source `.dart`) — this plan
  fixes the toolchain, not the models. If a regen changes generated output because
  a source changed, that's a separate concern; STOP and report unexpected diffs.

## Git workflow

- Branch: `advisor/041-codegen-unpin`
- Conventional commits, e.g. `build(codegen): unpin retrofit_generator; regen`.

## Steps

### Step 1: Find a compatible retrofit / retrofit_generator pair

Inspect the current constraints and the mismatch. Bump `retrofit` and
`retrofit_generator` (and `build_runner`/`source_gen` if needed) to a mutually
compatible set per their changelogs. Run `flutter pub get` until it resolves.

**Verify**: `cd frontend && flutter pub get` → resolves; no `dependency_overrides`
needed for retrofit.

### Step 2: Run codegen clean

`cd frontend && dart run build_runner build --delete-conflicting-outputs` must
exit 0 with no manual override. Commit the regenerated files.

**Verify**: the command exits 0; `cd frontend && dart analyze lib/` → clean;
`cd frontend && flutter test` → pass.

### Step 3: Confirm generated output matches (no drift from sources)

After a clean regen, `git diff --exit-code -- frontend/lib` on a SECOND
consecutive run must be empty (idempotent generation).

**Verify**: run build_runner again → `git diff --exit-code -- frontend/lib` exits 0.

### Step 4: Add a CI freshness gate

In `ci.yml` frontend job, add a step that runs `build_runner` and fails if the
committed generated files are stale:

```yaml
- name: Codegen up to date
  run: |
    cd frontend
    dart run build_runner build --delete-conflicting-outputs
    git diff --exit-code
```
Update the `ci.yml:2` header comment (no longer "pinned-broken"). Update the
`AGENTS.md` "Regenerating generated code" section to the simple
`dart run build_runner build` instruction and remove the override workaround.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`
→ exit 0; `grep -n "pinned-broken" .gitea/workflows/ci.yml AGENTS.md` → no matches.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart run build_runner build --delete-conflicting-outputs` exits 0 with no `dependency_overrides`
- [ ] A second run leaves `git diff --exit-code -- frontend/lib` clean (idempotent)
- [ ] `cd frontend && dart analyze lib/ && flutter test` pass
- [ ] `grep -n "pinned-broken" .gitea/workflows/ci.yml AGENTS.md` → no matches
- [ ] CI has a codegen-freshness step
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- No compatible retrofit/retrofit_generator pair exists without bumping the Flutter
  SDK or Drift majors — report the constraint chain; that's a bigger migration.
- A clean regen produces a large unexpected diff in generated files (means the
  committed files were already stale/hand-edited) — report the scope before
  committing 12k-line diffs.

## Maintenance notes

- Once green, codegen is routine: edit a Drift table / retrofit client, run
  build_runner, commit. The CI gate keeps committed output honest.
- Reviewer: the regenerated-file diff can be huge; focus on the pubspec version
  change and the CI/AGENTS updates, and trust the idempotency check for the rest.
