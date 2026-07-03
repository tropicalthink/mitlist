# Plan 044: Archive the completed plan sets so only in-flight work reads as active

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- plans frontend/plans`
> If either index changed, re-read it before archiving.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: all of 001–019 remain DONE, and any of 020–043 the operator
  chose to execute are DONE (do not archive plans still TODO/IN PROGRESS)
- **Category**: docs
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

There are two `plans/` trees: `plans/` (the intelligence-layer set, 001–019, all
DONE, plus this new 020+ batch) and `frontend/plans/` (an older offline/outbox
set, all DONE). Both are committed and read as "active." Two fully-done plan trees
invite confusion — an agent may re-attempt completed work — and duplicate the
"current vs older set" ambiguity the READMEs already have to disclaim. Archiving
the finished sets keeps only in-flight work visible.

## Current state

- `plans/README.md` — intelligence set 001–019 all `DONE ✓v`; 020+ is this new
  batch (status varies).
- `frontend/plans/README.md` — offline/outbox set, all `DONE` with commit hashes.

**Timing matters**: only archive plans whose status is DONE. This new batch
(020–043) may be partly TODO when this plan runs — do NOT archive TODO plans.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| List statuses | `grep -n "DONE\|TODO\|IN PROGRESS\|BLOCKED" plans/README.md frontend/plans/README.md` | inspect |
| Confirm git-tracked | `git ls-files plans frontend/plans \| head` | files listed |

## Scope

**In scope**:
- `frontend/plans/` (the fully-DONE offline/outbox set) → move under
  `docs/history/frontend-plans/` (or add a clear ARCHIVED banner — see Step 1)
- `plans/001-019` + `plans/018-DESIGN.md` + `plans/019-DESIGN.md` (all DONE) →
  move to `plans/archive/` OR add an ARCHIVED banner to their section of
  `plans/README.md`
- `plans/README.md` and `frontend/plans/README.md` (update pointers/banners)

**Out of scope**:
- Any plan in the 020+ batch that is not DONE — leave it where it is, active.
- Deleting plan files — they are the record; move or banner them, never delete.

## Git workflow

- Branch: `advisor/044-archive-completed-plans`
- Use `git mv` to preserve history; conventional commit:
  `docs(plans): archive completed plan sets`.

## Steps

### Step 1: Choose archive vs banner (pick one, be consistent)

Two acceptable approaches — pick the one the operator prefers; default to
**banner** (lower churn, keeps history in place):

- **Banner (default)**: add a top-of-file `> **ARCHIVED — all plans DONE as of
  <date>. Kept for the record; not active work.**` to `frontend/plans/README.md`
  and to the 001–019 section of `plans/README.md`.
- **Move**: `git mv frontend/plans docs/history/frontend-plans`, and move the
  DONE `plans/001-019*.md` into `plans/archive/`, updating `plans/README.md` to
  point at the archive. If you move, fix any relative links.

### Step 2: Ensure the active index only lists in-flight work at the top

`plans/README.md` should surface the currently-executable plans (the not-DONE
subset of 020+) prominently, with the completed 001–019 (and any DONE 020+) below
a clear "Completed / archived" divider.

**Verify**: `grep -n "ARCHIVED\|Completed\|archive" plans/README.md frontend/plans/README.md`
→ present.

### Step 3: Verify nothing that's still TODO got archived

**Verify**: every plan under any `archive/` path or ARCHIVED banner has status
DONE in the index. Cross-check:
`grep -rn "TODO\|IN PROGRESS" plans/archive/ docs/history/ 2>/dev/null` → no matches.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] The fully-DONE offline/outbox set is archived (moved or bannered) — `grep -n "ARCHIVED" frontend/plans/README.md` or the file now lives under `docs/history/`
- [ ] The DONE 001–019 intelligence set is archived/bannered in `plans/README.md`
- [ ] No plan with status TODO/IN PROGRESS was archived
- [ ] No plan files were deleted (`git status` shows moves/edits, not deletions of content)
- [ ] `plans/README.md` clearly separates active from completed work
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Any 020+ plan the operator intended to keep active is not yet DONE and the
  archive approach would bury it — confirm the active set first.
- Moving files breaks relative links you can't fully fix — prefer the banner
  approach and report.

## Maintenance notes

- Going forward, archive a plan set once its whole index is DONE and verified.
- Reviewer: confirm no active work was hidden and history is preserved (moves via
  `git mv`, not delete+add).
