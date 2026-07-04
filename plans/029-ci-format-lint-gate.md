# Plan 029: CI enforces formatting (and analyzes test code) on every push

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- .gitea/workflows/ci.yml`
> If it changed, compare the excerpt below to live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (gate-only; may surface existing violations to clean up)
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

CI runs `go build/vet/test` and `dart analyze lib/` + `flutter test`, but has no
format gate on any language and never analyzes the Dart `test/` directory. So
formatting drift lands unblocked, and a broken test helper (a stale fake missing
a method, an orphan import) slips through `dart analyze lib/` and only fails when
someone runs the suite. Adding cheap format checks and widening analyze to the
whole package raises the floor with near-zero maintenance.

## Current state

```yaml
# .gitea/workflows/ci.yml (backend job)
- name: Build
  run: cd backend && go build ./...
- name: Vet
  run: cd backend && go vet ./...
- name: Test
  run: cd backend && go test ./...

# (frontend job)
- name: Analyze
  run: cd frontend && dart analyze lib/        # ← excludes test/
- name: Test
  run: cd frontend && flutter test
```
No `gofmt`/`golangci-lint`, no `dart format --set-exit-if-changed`, no
`.golangci.yml`, no `.editorconfig` at repo root.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Go fmt check | `cd backend && gofmt -l .` | ideally empty (see Step 0) |
| Dart fmt check | `cd frontend && dart format --output=none --set-exit-if-changed .` | exit 0 if clean |
| Analyze all | `cd frontend && dart analyze` (no `lib/`) | `No issues found!` if test/ is clean |

## Scope

**In scope**:
- `.gitea/workflows/ci.yml`

**Out of scope** (do NOT do in this plan):
- Reformatting the codebase — if `gofmt -l` or `dart format` reports files, do
  NOT reformat them here (that is a large, separate, review-noisy diff). See
  Step 0: if the tree is already clean, add the gate; if not, add the gate but
  report the offending files so a dedicated formatting commit can precede it.
- Introducing `golangci-lint` — deferred (it needs a config and a triage of
  findings). This plan is format + analyze-widening only.

## Git workflow

- Branch: `advisor/029-ci-format-lint-gate`
- Conventional commit: `ci: add format checks and analyze test code`.

## Steps

### Step 0 (investigate first): is the tree already format-clean?

Run `cd backend && gofmt -l .` and
`cd frontend && dart format --output=none --set-exit-if-changed .` and
`cd frontend && dart analyze` (whole package).

- If all three are clean → proceed to add the gates (Steps 1–2).
- If any reports files → still add the gates, but in your completion report list
  the offending files and note that a formatting/cleanup commit must land first
  (or the gate will fail its first run). Do NOT reformat in this plan.

### Step 1: Add a Go format gate to the backend job

After the Vet step, add:

```yaml
- name: Format check
  run: |
    cd backend
    unformatted=$(gofmt -l .)
    if [ -n "$unformatted" ]; then echo "gofmt needs:"; echo "$unformatted"; exit 1; fi
```

**Verify**: the YAML is valid (the file parses; see Step 3).

### Step 2: Add a Dart format gate and widen analyze

In the frontend job: change `dart analyze lib/` to `dart analyze` (whole package,
so `test/` is checked), and add a format step:

```yaml
- name: Format check
  run: cd frontend && dart format --output=none --set-exit-if-changed .
```
Keep the existing `flutter test`, parity, and eval steps unchanged.

**Verify**: YAML parses (Step 3).

### Step 3: Validate the workflow file

Confirm the YAML is well-formed. If `yq` or a YAML linter is available, use it;
otherwise `python3 -c "import yaml,sys; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`
→ exit 0 (no exception).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "gofmt -l" .gitea/workflows/ci.yml` → present
- [ ] `grep -n "dart format" .gitea/workflows/ci.yml` → present
- [ ] `grep -n "dart analyze$\|dart analyze " .gitea/workflows/ci.yml` → analyze no longer scoped to `lib/` only (whole-package)
- [ ] `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` exits 0
- [ ] Completion report states whether `gofmt -l .` and `dart format` were clean (Step 0)
- [ ] No files outside `.gitea/workflows/ci.yml` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Step 0 shows the tree is NOT format-clean — report the file list; the gate is
  still added, but flag that a formatting commit must precede merge.
- Widening `dart analyze` to the whole package surfaces existing errors in
  `test/` — report them; do not fix unrelated test code in this plan.

## Maintenance notes

- Follow-up (deferred): add `golangci-lint` with a curated `.golangci.yml`, and
  consider an `.editorconfig`.
- Reviewer: confirm the new steps run on the right working directory and that the
  frontend `dart analyze` change actually widened scope.
