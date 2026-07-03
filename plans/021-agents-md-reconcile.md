# Plan 021: AGENTS.md matches reality (migrations, file paths, test status)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- AGENTS.md backend/migrations`
> If AGENTS.md changed since this plan was written, re-derive the correct values
> below from the live repo before editing.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`AGENTS.md` is the primary onboarding document for agents executing work in this
repo. It is stale in four concrete ways that actively mislead: it points at file
paths that no longer exist, lists a migration 10 versions behind, references a
`CLAUDE.md` that isn't there, and contradicts itself about whether the backend
tests pass. An agent that trusts it follows dead paths and wastes effort. This
is a cheap, high-leverage correctness fix for the docs.

## Current state

Four defects, each verified against the live repo at commit `8aec2a1e`:

1. **Stale migration number.** `AGENTS.md:139` and `AGENTS.md:245` say migration
   `000022` is the latest / most recent. The real latest is
   `000032_add_email_enabled_to_notification_preferences` — verify with
   `ls backend/migrations/ | tail -2`. The "Migration History" table
   (`AGENTS.md:239`+) stops at 000022.

2. **Dead scan-service path.** `AGENTS.md:125` says
   `Service: frontend/lib/services/scan_service.dart`. That file does not exist.
   The real entry point is `frontend/lib/services/scan/scan_pipeline_service.dart`.
   Also verify the screen path at `AGENTS.md:126`
   (`frontend/lib/screens/scanner/scanner_screen.dart`) — confirm it exists with
   `ls frontend/lib/screens/scanner/` and correct it if not.

3. **Missing CLAUDE.md reference.** `AGENTS.md:11` (Repository Layout) lists
   `CLAUDE.md   Design context & brand guidelines`. No `CLAUDE.md` exists at
   repo root, `frontend/`, or `backend/`. The design/brand content lives in
   `PRODUCT.md` (verify: `ls PRODUCT.md`).

4. **Self-contradiction on test status.** `AGENTS.md:47` annotates
   `go test ./...` with `# Run all tests (some pre-existing failures)`, while the
   "Testing" table at `AGENTS.md:197-203` marks every backend package `✅ Pass`.
   The backend suite is currently green (`cd backend && go test ./...` passes) —
   the inline "some pre-existing failures" comment is the wrong half.

## Commands you will need

| Purpose            | Command                                    | Expected |
|--------------------|--------------------------------------------|----------|
| Latest migration   | `ls backend/migrations/ \| tail -2`        | `000032_...` files |
| Confirm scan path  | `ls frontend/lib/services/scan/scan_pipeline_service.dart` | file exists |
| Confirm no CLAUDE  | `ls CLAUDE.md 2>&1`                         | "No such file" |
| Backend tests      | `cd backend && go test ./...`              | all `ok` |

## Scope

**In scope**: `AGENTS.md` only.

**Out of scope**: Do NOT create a `CLAUDE.md` to satisfy the reference — remove
the reference instead (the content is in `PRODUCT.md`). Do NOT edit the
migration files or any source.

## Git workflow

- Branch: `advisor/021-agents-md-reconcile`
- Conventional commit: `docs(agents): reconcile AGENTS.md with current repo state`.

## Steps

### Step 1: Fix the migration references

Update `AGENTS.md:139` and `AGENTS.md:245` and extend the Migration History
table so the latest listed migration is `000032`. You do not need to enumerate
every intermediate migration; at minimum correct the "latest is 000022" claim to
`000032` and add rows (or a summarizing note) covering 000023–000032. Get the
list with `ls backend/migrations/*.up.sql | sed -n '23,32p'`.

**Verify**: `grep -c "000022" AGENTS.md` → the count drops (the "latest" claims
are gone; historical mention in the table is fine if accurate).

### Step 2: Fix the scan service/screen paths

Replace `frontend/lib/services/scan_service.dart` at `AGENTS.md:125` with
`frontend/lib/services/scan/scan_pipeline_service.dart`. Verify the screen path
on the next line and correct it against `ls frontend/lib/screens/scanner/`.

**Verify**: `grep -n "scan_service.dart" AGENTS.md` → no matches.

### Step 3: Remove the CLAUDE.md reference

At `AGENTS.md:11`, remove the `CLAUDE.md` line (or repoint it to `PRODUCT.md` if
that reads better in the layout list).

**Verify**: `grep -n "CLAUDE.md" AGENTS.md` → no matches.

### Step 4: Reconcile the test-status contradiction

At `AGENTS.md:47`, change the comment `# Run all tests (some pre-existing failures)`
to reflect reality — the suite is green — e.g. `# Run all tests`.

**Verify**: `grep -n "pre-existing failures" AGENTS.md` → no matches; and
`cd backend && go test ./...` → all `ok` (confirms the "green" claim is true).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "scan_service.dart" AGENTS.md` → no matches
- [ ] `grep -n "CLAUDE.md" AGENTS.md` → no matches
- [ ] `grep -n "pre-existing failures" AGENTS.md` → no matches
- [ ] AGENTS.md references `000032` as the latest migration
- [ ] `cd backend && go test ./...` all `ok` (the reconciled claim holds)
- [ ] No files outside AGENTS.md modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The live repo shows a migration higher than 000032 or the scan pipeline file is
  at a different path — use the real value, but note the drift in your report.
- `cd backend && go test ./...` is NOT green — then the contradiction's other
  half is the truth; report it instead of guessing.

## Maintenance notes

- This doc drifts whenever migrations or the scan entry point move. Consider a
  follow-up (out of scope here) to generate the migration table from
  `backend/migrations/` rather than hand-maintaining it.
- Reviewer: spot-check that no corrected path is itself wrong.
