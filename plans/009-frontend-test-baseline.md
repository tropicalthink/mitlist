# Plan 009: Repair the frontend test baseline (stale finders, chores overflow, sqlite docs)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/test frontend/lib/screens/chores/chores_screen.dart frontend/lib/sheets frontend/README.md`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

`flutter test` currently fails with ~11 failures on a clean checkout, so the suite
cannot gate anything — every other frontend plan's "tests pass" criterion is
meaningless until this lands. The failures decompose into three distinct causes:
(a) stale test finders asserting UI text that was changed without updating tests,
(b) a real product bug — a 16px RenderFlex overflow in the chores screen's sticky
header that the test harness surfaces as an exception, and (c) a host-environment
gap — Drift's `NativeDatabase` needs `libsqlite3.so`, which isn't documented as a
dev prerequisite.

## Current state

- `frontend/test/` has exactly 3 files: `design_system_test.dart`,
  `frontend_flows_test.dart`, `widget_test.dart`.
- **Stale finders** in `frontend/test/frontend_flows_test.dart`:
  - line 211: `expect(find.text('Expense Details'), findsOneWidget);` — but
    `frontend/lib/sheets/expense_detail_sheet.dart:56` renders `title: 'Expense details',`
  - line 304: `expect(find.text('Recipe Details'), findsOneWidget);` — but
    `frontend/lib/sheets/recipe_detail_sheet.dart:86` renders `title: 'Recipe details',`
  - lines 363/368: taps `AppButton` with text `'Join Household'` then expects
    `find.text('Joined Household')` — open `frontend/lib/sheets/join_household_sheet.dart`
    and read the actual button label and success-state text (the success state
    renders `"You're in."` around line 279); align the test with reality.
  - There are reportedly a few more stale text finders ("Groceries" etc.) —
    run the suite and fix every finder-mismatch failure the same way: read the
    actual widget code, update the test to assert what is really rendered.
    **Never change product code to match a stale test.**
- **RenderFlex overflow (real product bug)**: `frontend/lib/screens/chores/chores_screen.dart:714`
  area — a `Column` inside a fixed-height `SliverPersistentHeader`
  (`_StickyHeaderDelegate(height: _stickyHeaderHeight, ...)`) overflows by ~16px
  in the test viewport. Excerpt at :705–725:

  ```dart
  child: CustomScrollView(
    physics: AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _StickyHeaderDelegate(
          height: _stickyHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(...
  ```

  Fix the layout, not the test: either make `_stickyHeaderHeight` account for the
  actual content height, or make the header content shrink-safe (e.g. wrap the
  Column in a `FittedBox`/`SingleChildScrollView(physics: NeverScrollable...)` or
  reduce fixed paddings). Reproduce first with
  `flutter test test/frontend_flows_test.dart --plain-name "chore"` and read the
  exact overflow report (it names the offending widget and pixel count).
- **libsqlite3**: tests construct `NativeDatabase.memory()`
  (`frontend/test/frontend_flows_test.dart:~1000`); on Linux hosts without
  `libsqlite3.so` those tests fail to load the dynamic library. `frontend/README.md`
  has no prerequisite note.
- Conventions: design tokens from `lib/theme/` (`MitlistSpacing.md` etc.); tests
  use `ProviderScope(overrides: [...])` with `appDatabaseProvider.overrideWithValue(db)`
  (see `frontend_flows_test.dart:~995–1015` for the harness pattern).

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | ALL pass (goal of this plan) |
| Sqlite check | `ldconfig -p \| grep libsqlite3` | prints a path (else install needed) |

## Scope

**In scope**:
- `frontend/test/frontend_flows_test.dart` (finder fixes only)
- `frontend/lib/screens/chores/chores_screen.dart` (overflow fix only)
- `frontend/README.md` (add a "Running tests" prerequisite note: Linux needs
  `libsqlite3` — e.g. `sudo apt install libsqlite3-dev` on Debian/Ubuntu)

**Out of scope**:
- Any sheet/screen text changes to make stale tests pass — tests follow code.
- New test coverage (plan 015 owns that).
- `design_system_test.dart` and `widget_test.dart` unless they are among the
  failing tests for the same three causes.

## Git workflow

- Branch: `fix/frontend-test-baseline` off `new-main-fr`.
- Conventional commits, one per cause (`test: ...`, `fix: ...`, `docs: ...`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Establish the failure inventory

Run `flutter test 2>&1 | grep -E "FAILED|Exception"` and list every failing test
with its cause class (stale finder / overflow / sqlite). If `libsqlite3` is
missing on this host, install it (or skip those tests' verification and note it).

**Verify**: you have a written inventory matching ~11 failures.

### Step 2: Fix the chores sticky-header overflow

Reproduce, read the overflow report, fix the layout in `chores_screen.dart` so the
header content fits its declared height at the default test viewport (800×600)
AND at `textScaleFactor: 1.3` (check with a quick manual `MediaQuery` override in
a scratch test if unsure; don't commit the scratch).

**Verify**: `flutter test --plain-name "chore"` → no RenderFlex overflow exceptions.

### Step 3: Fix every stale finder

Per the Current state list: read the real widget text, update the assertion.

**Verify**: `flutter test test/frontend_flows_test.dart` → all pass.

### Step 4: Document the sqlite prerequisite

Add 2–3 lines to `frontend/README.md` near the test instructions.

**Verify**: `grep -n "libsqlite3" frontend/README.md` → match.

## Test plan

This plan IS the test repair. Final gate: full `flutter test` green on a host
with libsqlite3 present.

## Done criteria

- [ ] `flutter test` exits 0 (zero failures)
- [ ] `dart analyze lib/` exits 0
- [ ] `grep -n "Expense Details\|Recipe Details" test/` → no matches
- [ ] `grep -n "libsqlite3" frontend/README.md` → match
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A failing test's cause is NOT one of the three classes above (that's an
  undiagnosed product bug — report it, don't paper over it).
- The overflow fix requires restructuring the screen beyond the header block.
- More than ~15 tests fail (baseline has drifted).

## Maintenance notes

- Reviewer: confirm no `expect` was weakened to `findsAny`/removed — assertions
  must still pin real UI text.
- Future: a CI job running `flutter test` would prevent this rot; CI was
  deferred by the maintainer last cycle — revisit.
