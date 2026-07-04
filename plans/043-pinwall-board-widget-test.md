# Plan 043: Add a widget test for the pinwall board screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/screens/pinwall/pinwall_board_screen.dart`
> On any change, re-read the screen's provider usage before writing the test.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (test-only)
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`pinwall_board_screen.dart` (1869 lines) is the repo's largest, highest-churn UI
surface — presence bar, note cards, and a stats card aggregating chores/finance/
lists — and it has **no** widget test. By contrast, chores and expenses have flow
coverage in `frontend_flows_test.dart`. Regressions in board composition or the
multi-provider stats card ship unverified. A widget test that mounts the board and
asserts its key pieces render is the safety net that also unblocks the pinwall
refactors (Plans 037/039).

## Current state

- `frontend/lib/screens/pinwall/pinwall_board_screen.dart` — mounts many
  providers. From the audit, notable ones: `presentMembersProvider`,
  `cachedCurrentChoresByGroupProvider`, `cachedFinanceSummaryByGroupProvider`
  (and more). Read the file and list every provider the screen `watch`es/`read`s —
  each needs an override in the test.
- **Test harness to model on**: `frontend/test/frontend_flows_test.dart` already
  mounts screens with Riverpod `ProviderScope` overrides (see its chore/expense
  cases around lines 96 and 176) and wires `localizationsDelegates`/
  `supportedLocales`. Copy that setup exactly.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze` | `No issues found!` (test/ included) |
| Test | `cd frontend && flutter test test/screens/pinwall/` | pass |

Note: needs native `libsqlite3` (Drift). If `flutter test` errors with
`Failed to load dynamic library 'libsqlite3.so'`, symlink
`ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/sqlitelib/libsqlite3.so`
and run with `LD_LIBRARY_PATH=/tmp/sqlitelib flutter test ...`. CI has the lib.

## Scope

**In scope**:
- `frontend/test/screens/pinwall/pinwall_board_screen_test.dart` (create)

**Out of scope**:
- `pinwall_board_screen.dart` itself — do NOT modify the screen to make it
  testable unless it is truly impossible to mount with overrides. If a small
  seam is genuinely required, STOP and report rather than reshaping the screen
  here (that belongs to the refactor plans 037/039).

## Git workflow

- Branch: `advisor/043-pinwall-board-widget-test`
- Conventional commit: `test(pinwall): widget test for the board screen`.

## Steps

### Step 1: Enumerate the screen's provider dependencies

Read `pinwall_board_screen.dart` and list every provider it reads/watches. Grep
for `ref.watch(` and `ref.read(` in the file. Each becomes an `override` in the
test's `ProviderScope`.

### Step 2: Write the mount test

Create `pinwall_board_screen_test.dart` modeled on `frontend_flows_test.dart`:
- `ProviderScope(overrides: [...])` supplying seeded fakes for every provider
  from Step 1 (one board with a couple of notes; a small finance summary; a
  present member or two).
- `MaterialApp` with `AppLocalizations.localizationsDelegates` and
  `supportedLocales` (omitting these null-derefs `AppLocalizations.of(context)!`).
- Mount `PinwallBoardScreen`, `await tester.pumpAndSettle()`, and assert: at least
  one note card renders (find by a note's text), the presence bar renders, and the
  stats card shows a chores/finance figure.

**Verify**: `cd frontend && flutter test test/screens/pinwall/pinwall_board_screen_test.dart`
→ pass.

### Step 3: Add one interaction (optional but preferred)

If feasible without deep mocking, add an interaction assertion (e.g. tapping the
add-note affordance opens the composer). Skip if it requires stubbing a network
mutation that the harness doesn't already support, and note the skip.

**Verify**: `cd frontend && flutter test test/screens/pinwall/` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `frontend/test/screens/pinwall/pinwall_board_screen_test.dart` exists
- [ ] It mounts `PinwallBoardScreen` and asserts note card + presence bar + stats render
- [ ] `cd frontend && flutter test test/screens/pinwall/` passes
- [ ] `cd frontend && dart analyze` (whole package) exits 0
- [ ] `pinwall_board_screen.dart` is unchanged (`git diff --stat` shows only the new test)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The screen cannot be mounted without a real network/DB call the harness can't
  override, or requires a screen-code seam to be testable — report what blocks it
  (this is a signal that the refactor plan 037/039 should come first).

## Maintenance notes

- This test is the safety net for Plans 037 (god-screen decomposition) and 039
  (pinwall shared widgets) — run it before/after those refactors.
- Reviewer: confirm the test asserts real rendered content, not just that mounting
  doesn't throw.
