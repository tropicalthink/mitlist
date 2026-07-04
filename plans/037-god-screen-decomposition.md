# Plan 037: Decompose the expenses god-screen using the list-detail controller pattern

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/screens/money/expenses_screen.dart`
> On any change, re-read the screen before starting; on material mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: L
- **Risk**: MED (large UI refactor; needs a test safety net)
- **Depends on**: 043 recommended first (a widget test as a safety net) — see notes
- **Category**: tech-debt
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

Several screens are 8–9× the repo's median file size and concentrate the most-
edited UI: `expenses_screen.dart` (1717 lines), `pinwall_board_screen.dart`
(1869), `chores_screen.dart` (1650), `hub/pinwall_section.dart` (1700). Every
feature touch on these risks a merge-heavy diff in a file too big to review well.
The repo already has a proven decomposition pattern — a `ChangeNotifier`
controller that owns data + side-effects, keeping the widget file to
presentation — applied to exactly one screen (`list_detail_controller.dart` /
`list_detail_screen.dart`). This plan propagates it to the highest-churn screen,
`expenses_screen.dart`, as the template for the others.

## Current state

- `frontend/lib/screens/money/expenses_screen.dart` (1717 lines) — mixes data
  loading, mutations (create/settle/edit expenses), and presentation.
- **The pattern to follow**: `frontend/lib/screens/lists/list_detail_controller.dart`
  (a `ChangeNotifier` owning state + async side-effects) paired with
  `frontend/lib/screens/lists/list_detail_screen.dart` (presentation that watches
  the controller). Read both fully before starting — replicate their structure,
  naming, disposal, and how the screen obtains the controller.

This is a structural refactor, not a behavior change: the screen must render and
behave identically after.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass (sqlite-env note may apply) |

## Scope

**In scope**:
- `frontend/lib/screens/money/expenses_screen.dart`
- `frontend/lib/screens/money/expenses_controller.dart` (create — mirror
  `list_detail_controller.dart`)
- Any small private widget files you extract under `frontend/lib/screens/money/`
- `frontend/test/screens/money/expenses_screen_test.dart` (create — safety net)

**Out of scope**:
- The other god screens (pinwall, chores) — this plan is the template; the others
  are follow-ups (see Maintenance). Do NOT refactor them here.
- The finance service/repository and expense data models — behavior unchanged.
- Any change to what the screen displays or the API calls it makes.

## Git workflow

- Branch: `advisor/037-expenses-controller`
- Commit per extraction unit; conventional commits, e.g.
  `refactor(money): extract ExpensesController from expenses_screen`.

## Steps

### Step 0: Establish the safety net first

Before refactoring, ensure a widget test exists that mounts `ExpensesScreen` with
provider overrides and asserts the key states render (list of expenses, the
create action). If Plan 043's pattern or an existing `frontend_flows_test.dart`
expense case covers this, extend it; otherwise create
`expenses_screen_test.dart` modeled on the harness in
`frontend/test/frontend_flows_test.dart` (it already mounts screens with Riverpod
overrides and has an expense-create case at ~line 176). **Do not start the
refactor until a test exercises the screen** — this is the guardrail that catches
regressions.

**Verify**: the new/extended test passes against the UNREFACTORED screen:
`cd frontend && flutter test test/screens/money/` (or the flows test) → pass.

### Step 1: Extract the controller

Create `expenses_controller.dart` as a `ChangeNotifier` (matching
`list_detail_controller.dart`'s shape) that owns: the loaded expenses/settlement
state, loading/error flags, and the mutation methods (create/settle/edit) —
moving that logic out of the widget. The screen constructs/obtains the controller
the same way `list_detail_screen.dart` does and `watch`es it.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!` and the
Step 0 test still passes.

### Step 2: Move presentation into scoped widgets

Extract large `build` sub-trees into private `ConsumerWidget`/`StatelessWidget`
classes (as `list_detail_screen.dart` and `pinwall_board_screen.dart` do with
scoped consumers), so rebuilds stay localized. Keep behavior identical.

**Verify**: Step 0 test passes; `cd frontend && dart analyze lib/` clean.

### Step 3: Shrink the screen file

After extraction, `expenses_screen.dart` should be materially smaller (target:
well under half its original size; the controller + extracted widgets hold the
rest). Confirm no dead code left behind.

**Verify**: `wc -l frontend/lib/screens/money/expenses_screen.dart` → substantially
less than 1717; `cd frontend && flutter test` → pass.

## Test plan

- The Step 0 widget test is both the safety net and the deliverable. It must pass
  before and after the refactor, proving behavior preservation.
- Model on `frontend/test/frontend_flows_test.dart` (Riverpod override harness).
- No new behavior to test — this is structural.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `frontend/lib/screens/money/expenses_controller.dart` exists and is a `ChangeNotifier`
- [ ] `wc -l frontend/lib/screens/money/expenses_screen.dart` is < 900 (materially reduced from 1717)
- [ ] A widget test for `ExpensesScreen` exists and passes
- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `cd frontend && flutter test` passes (only the known welcome-screen case may fail)
- [ ] No files outside `frontend/lib/screens/money/` and `frontend/test/screens/money/` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- You cannot get a passing widget test against the unrefactored screen (Step 0) —
  do NOT refactor blind; report what blocks the test.
- The refactor requires touching the finance service/repo or changing an API call
  — that means behavior is changing; STOP and report.

## Maintenance notes

- This is the template. Follow-up plans should apply the same controller pattern
  to `chores_screen.dart`, `pinwall_board_screen.dart`, and
  `hub/pinwall_section.dart`, highest-churn first, each with its own safety-net
  test. Link this plan from those.
- Reviewer: the PR is large — focus on behavior parity (the test) and that no data
  logic was changed, only relocated.
