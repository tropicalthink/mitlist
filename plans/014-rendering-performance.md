# Plan 014: Lazy list building and bounded image decodes in heavy screens

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/screens/lists/list_detail_screen.dart frontend/lib/widgets/hub/pinwall_section.dart frontend/lib/sheets/expense_detail_sheet.dart frontend/lib/sheets/recipe_detail_sheet.dart frontend/lib/screens/recipes frontend/lib/screens/meal_plans/meal_plan_screen.dart frontend/lib/screens/pinwall/pinwall_board_screen.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (layout changes in the most-used screen; needs careful manual smoke)
- **Depends on**: plans/009-frontend-test-baseline.md
- **Category**: perf
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

Two user-perceivable costs: (1) the list-detail screen builds **every** item row
eagerly — a plain `ListView(children: [...open.map(...), ...done.map(...)])` —
so large lists re-layout all rows on every rebuild (and rebuilds are frequent:
every SSE event and outbox drain re-emits the watch stream); (2) all ten
`Image.network` call sites decode full-resolution images for thumbnail-sized
slots (no `cacheWidth`/`cacheHeight`), causing memory spikes and decode jank on
image-heavy pinwall/recipe views.

## Current state

- `frontend/lib/screens/lists/list_detail_screen.dart:1001` —

  ```dart
  return CheckboxTheme(
    data: _itemCheckboxThemeData(),
    child: ListView(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      children: [
        ...open.map((item) => _buildDismissibleItemRow(item, textTheme)),
        if (done.isNotEmpty) ...[
          Material( /* done-section header w/ InkWell expand toggle */ ...
  ```

  `open`/`done` come from `_openItemsSorted()` / `_doneItemsSorted()`. The done
  section has an expand/collapse header. Items are Dismissible rows.
- `Image.network` sites (10 total — enumerate fresh with
  `grep -rn "Image.network" frontend/lib/`):
  `screens/lists/list_detail_screen.dart` (×2), `widgets/hub/pinwall_section.dart` (×2),
  `sheets/expense_detail_sheet.dart` (×2), `sheets/recipe_detail_sheet.dart`,
  `screens/recipes/recipes_screen.dart`, `screens/recipes/recipe_creation_screen.dart`,
  `screens/meal_plans/meal_plan_screen.dart`, `screens/pinwall/pinwall_board_screen.dart`.
  Example — `recipes_screen.dart:857`: fixed `width/height` (design-token sized)
  with `fit: BoxFit.cover` and no `cacheWidth`.
- Conventions: design tokens `MitlistSpacing.*`; screens are StatefulWidgets with
  Riverpod; tests in `frontend/test/frontend_flows_test.dart` cover list flows —
  they must stay green.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/lib/screens/lists/list_detail_screen.dart` (ListView → builder pattern)
- The 10 `Image.network` call sites (add `cacheWidth`/`cacheHeight` only)

**Out of scope**:
- The other large screens' structure (expenses/chores/calendar) — separate,
  riskier refactor, deliberately deferred.
- Switching image loading to a caching package (`cached_network_image`) —
  bigger dependency decision, not this plan.
- Any visual/design change.

## Git workflow

- Branch: `perf/rendering` off `new-main-fr`.
- Two conventional commits: `perf: build list detail rows lazily`,
  `perf: bound network image decode sizes`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Convert list-detail to lazy building

Replace the spread-children `ListView` with `ListView.builder` (or
`CustomScrollView` + `SliverList.builder` if the done-header is easier that way):
compute a flat row model first — e.g.
`[...open rows, if (done.isNotEmpty) headerMarker, if (_doneExpanded) ...done rows]`
— then build each row on demand in `itemBuilder`. Preserve: Dismissible behavior,
the done expand/collapse state, padding, and **stable keys** on item rows
(`ValueKey(item.id)` — check what `_buildDismissibleItemRow` already uses; add if
absent so Dismissible state survives index shifts).

**Verify**: `dart analyze lib/` → exit 0; `flutter test test/frontend_flows_test.dart` → list flows pass.

### Step 2: Bound image decodes

At each `Image.network` site with a known display size, add
`cacheWidth: (displayWidth * MediaQuery.devicePixelRatioOf(context) * 1.5).round()`
(width only is sufficient; Flutter preserves aspect). Where display width is
unbounded (full-bleed images), use a sane ceiling (e.g. screen width × DPR).
Do not change `fit`, sizes, or error/loading builders.

**Verify**: `dart analyze lib/` → exit 0; `grep -rn "Image.network" frontend/lib/ | wc -l` unchanged; each site now has `cacheWidth` (grep count matches).

### Step 3: Full suite + manual smoke note

**Verify**: `flutter test` → all pass. Note for the reviewer in your report:
manually scroll a 100+ item list and an image-heavy pinwall to confirm no
behavior change (executor can't do this — flag it).

## Test plan

Existing `frontend_flows_test.dart` list flows are the regression net (they pump
list detail with seeded items). Add one assertion-level test only if a flow test
doesn't already cover the done-section expand/collapse after the refactor —
check first; if covered, no new tests.

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] No spread-children `ListView(children:` remains at `list_detail_screen.dart:~1001`
- [ ] All `Image.network` sites pass `cacheWidth`
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The done-section header logic is entangled with scroll position or animations
  that a builder list breaks (report what you found).
- Any flow test fails after Step 1 in a way that isn't a missing key.

## Maintenance notes

- New `Image.network` calls should always set `cacheWidth`; plan 017's lint set
  can't enforce this — reviewer vigilance (or a custom lint later).
- Reviewer: scrutinize Dismissible keys and the row-model index math
  (off-by-one around the done header is the likely bug).
- Deferred: `cached_network_image` adoption; large-screen ViewState refactor.
