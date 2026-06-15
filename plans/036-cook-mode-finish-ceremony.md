# Plan 036: Close the cook-mode loop with a real finish moment

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update this plan's status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 45ae60c2..HEAD -- frontend/lib/screens/recipes/cook_mode_screen.dart`
> If the file changed, compare the "Current state" excerpts against the live
> code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `45ae60c2`, 2026-06-15

## Why this matters

Cook mode walks the user through mise-en-place, scaled servings, step-by-step
cooking, and timers — then ends on a flat dead-end: a checkmark, the text
"Finished — nice work", and a "Done" button that just `Navigator.pop()`s. The
effort the feature invests has no payoff and no closure — the classic "glued on"
ending. Finishing a cook should *feel* like an accomplishment and offer an
obvious next step.

This plan delivers the **frontend finish ceremony** end-to-end (a real summary
of what was cooked, success haptic, and clear next actions). The deeper loop —
recording a "cooked" event into the household activity feed and marking a meal
plan cooked — requires **new backend surface that does not exist yet** (the
activity feed is derived by `UNION ALL` over domain tables with no cook event;
cook mode isn't even handed the meal-plan entry it came from). That work is
scoped as a design note here, not built, to keep this plan a clean, verifiable
frontend change.

## Current state

`frontend/lib/screens/recipes/cook_mode_screen.dart`:

- The screen is a `ConsumerStatefulWidget` taking `recipeId` plus optional
  preloaded `recipe`, `ingredients`, `steps` (`:24-36`). It does **not** receive
  any meal-plan entry id.
- State available at finish: `_recipe` (`models.Recipe`, has `.title`,
  `.servings`), `_selectedServings` (`:51`), `_steps` (`:46`,
  `_steps.length` = step count), `_cookStarted` (`:55`, set true in the
  `onStart` callback at `:417`).
- The finished state is rendered at `:424-425`:

```dart
if (_currentStepIndex >= _steps.length) {
  return _FinishedView(onExit: () => Navigator.of(context).pop());
```

- `_FinishedView` (`:1393-1434`) is a stateless flat screen:

```dart
class _FinishedView extends StatelessWidget {
  final VoidCallback onExit;
  const _FinishedView({required this.onExit});
  @override
  Widget build(BuildContext context) {
    // AppIcon checkCircle (64) + "Finished — nice work" + AppButton "Done" -> onExit
  }
}
```

- No cook-start timestamp is tracked (no `Stopwatch`/`DateTime` for elapsed).

Available helpers:
- `Haptics.success()` → heavy impact (`frontend/lib/utils/haptics.dart:16`); `Haptics.medium()` / `.light()` also available.
- Design tokens: `MitlistSpacing.*`, `theme.textTheme`, `theme.colorScheme`. `AppIcon` (`name:` from `frontend/lib/widgets/icons.dart`), `AppButton` (`frontend/lib/widgets/app_button.dart`, variants `solid|outline|ghost|soft`), `AppCard` (`frontend/lib/widgets/app_card.dart`).

### Backend facts grounding the design note (do not build in this plan)

- Activity feed is **derived**, not event-sourced: `internal/repositories/activity_repo.go:30-51` is a `UNION ALL` over `list_items`, `expenses`, chores, `meal_plans`, `recipes`. Activity types are a closed enum (`internal/models/activity.go:13-17`) — there is **no** `recipe_cooked`/`meal_cooked` type. The client `ActivityService` (`frontend/lib/services/activity_service.dart`) has list/get/delete only — **no create**.
- `meal_plans` already has a `cook_user_id` column (referenced at `activity_repo.go:46`), a partial foothold for a future "cooked" concept.

## Commands you will need

| Purpose   | Command                                                                 | Expected            |
|-----------|-------------------------------------------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`                                      | no new issues       |
| Format    | `cd frontend && dart format lib/screens/recipes/cook_mode_screen.dart` | exit 0              |
| Tests     | `cd frontend && flutter test`                                          | all pass            |

## Scope

**In scope**:
- `frontend/lib/screens/recipes/cook_mode_screen.dart` only.

**Out of scope** (these are the deferred backend loop — do NOT start them here):
- Any backend change (new activity type, cook event endpoint, meal-plan cooked status).
- Threading a meal-plan entry id into `CookModeScreen` (would require changing every call site / router).
- The client `ActivityService` — it has no create method; do not add one in this plan.

## Git workflow

- Branch: `advisor/036-cook-mode-finish-ceremony`
- Single logical commit; conventional-commit style. Example: `feat(cook): give cook mode a real finish moment`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Track cook elapsed time

In `_CookModeScreenState`, add a nullable field `DateTime? _cookStartedAt;`
near the cook-flow state (`:54-56`). Set it where the cook actually starts — in
the `onStart` callback at `:417`:

```dart
onStart: () => setState(() {
  _cookStarted = true;
  _cookStartedAt = DateTime.now();
}),
```

(Keep any existing logic inside `onStart` if more than the single assignment is
present — read the live code first.)

**Verify**: `cd frontend && dart analyze lib/screens/recipes/cook_mode_screen.dart` → no new issues.

### Step 2: Fire a success haptic when the finish state is reached

The finish state renders when `_currentStepIndex >= _steps.length` (`:424`).
Fire `Haptics.success()` **once** on entry to that state. The cleanest place is
where the step index crosses the end — in the "advance step" handler around
`:298-300` (`if (_currentStepIndex >= _steps.length - 1) { ... setState(() =>
_currentStepIndex = _steps.length); }`). Add `unawaited(Haptics.success());`
there (import `dart:async` `unawaited` if not already imported — check the
existing imports; the screen already uses timers so it likely imports
`dart:async`). Do **not** call it inside `build()`/`_FinishedView` (that would
re-fire on every rebuild).

**Verify**: `cd frontend && dart analyze lib/screens/recipes/cook_mode_screen.dart` → no new issues.

### Step 3: Rebuild `_FinishedView` into a real summary + next actions

Replace the flat `_FinishedView` (`:1393-1434`) with a richer version that
receives the cook summary and offers two actions. Change its constructor to take
the data and two callbacks:

```dart
class _FinishedView extends StatelessWidget {
  final String recipeTitle;
  final int servings;
  final int stepCount;
  final Duration? elapsed;
  final VoidCallback onCookAgain;
  final VoidCallback onExit;

  const _FinishedView({
    required this.recipeTitle,
    required this.servings,
    required this.stepCount,
    required this.elapsed,
    required this.onCookAgain,
    required this.onExit,
  });
  // ...
}
```

The build should show, using design tokens only (no raw Material widgets, no
hardcoded pixels):

- The existing `AppIcon(name: 'checkCircle', size: 64, color: colorScheme.primary)` celebration mark, optionally wrapped in a subtle entrance animation (e.g. `TweenAnimationBuilder<double>` scaling 0.8→1.0 over ~`MitlistMotion`/300ms — if a motion-duration token exists in `frontend/lib/theme/animations.dart`, use it; otherwise a literal `Duration(milliseconds: 300)` is acceptable here).
- A headline: `"Nice work — ${recipeTitle} is done"` (fall back to "Nice work" if `recipeTitle` is empty).
- A compact summary line/`AppCard`: servings cooked, step count, and elapsed time when `elapsed != null` (format as `Xm` / `Hh Mm`; write a tiny local formatter — do not add a dependency).
- Two `AppButton`s: a primary `"Done"` → `onExit`, and a secondary (`variant: AppButtonVariant.soft` or `.outline`) `"Cook again"` → `onCookAgain`.

### Step 4: Wire the finished view from the screen

At the render site (`:424-425`), pass the summary and callbacks. "Cook again"
should reset the cook flow to the start of the steps (mirror the initial state:
`_currentStepIndex = 0`, `_cookStarted = false` or straight back into step 0 —
match how the screen models "before start"; read `:402-417` to see the
pre-start branch and reset to that state). Compute `elapsed` from
`_cookStartedAt`:

```dart
if (_currentStepIndex >= _steps.length) {
  final elapsed = _cookStartedAt == null ? null : DateTime.now().difference(_cookStartedAt!);
  return _FinishedView(
    recipeTitle: _recipe?.title ?? '',
    servings: _selectedServings,
    stepCount: _steps.length,
    elapsed: elapsed,
    onCookAgain: () => setState(() {
      _currentStepIndex = 0;
      _cookStarted = false;
      _cookStartedAt = null;
    }),
    onExit: () => Navigator.of(context).pop(),
  );
}
```

(Adjust the reset to whatever cleanly returns the screen to its pre-cook state;
if timers (`_timers`) need clearing on "Cook again", clear them too — check the
existing timer-teardown logic, e.g. `dispose`/`_ticker`.)

**Verify**:
- `cd frontend && dart analyze lib/` → no new issues
- `cd frontend && dart format lib/screens/recipes/cook_mode_screen.dart` → exit 0
- `cd frontend && flutter test` → all pass

## Test plan

- This is a UI/UX change to a stateful screen; the existing widget suite is the regression net (`flutter test`).
- If a cook-mode widget test exists (`ls frontend/test` and grep for `CookMode`), add a case that pumps the screen to the finished state and asserts the summary text (recipe title, step count) and the presence of "Cook again" + "Done" buttons. If no cook-mode test harness exists, do not build one from scratch — note manual verification in the PR description (pump through a recipe, finish, see the summary, tap "Cook again" → returns to step 1, tap "Done" → pops).
- Verification: `cd frontend && flutter test` → all pass.

## Done criteria

ALL must hold:

- [ ] `cd frontend && dart analyze lib/` reports no new issues
- [ ] `cd frontend && flutter test` exits 0
- [ ] `_FinishedView` shows the recipe title, servings, step count, and (when available) elapsed time
- [ ] A "Cook again" action returns the screen to the start of the cook flow; "Done" pops
- [ ] `Haptics.success()` fires exactly once on reaching the finished state (not on rebuild)
- [ ] `cd frontend && dart format --output=none --set-exit-if-changed lib/screens/recipes/cook_mode_screen.dart` exits 0
- [ ] No files outside `cook_mode_screen.dart` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- "Current state" excerpts/line numbers don't match live code (drift since `45ae60c2`).
- The cook-flow reset for "Cook again" can't be expressed without touching data-loading logic you'd risk breaking — report and ship just the summary + "Done" (drop "Cook again") rather than guessing.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes — the deferred backend loop (design note, NOT this plan)

To make finishing a cook visible household-wide, a follow-up plan would need:

1. **A cook event source.** Either add `ActivityType` `recipe_cooked`
   (`internal/models/activity.go`) and a real source — the simplest given the
   derived feed (`activity_repo.go` `UNION ALL`) is a `recipe_cooks` table
   (recipe_id, user_id, group_id, servings, cooked_at) `UNION`'d in — or reuse
   the existing `meal_plans.cook_user_id` foothold for meal-plan-driven cooks.
2. **A write path.** A `POST /recipe-cooks` (or similar) endpoint + a client
   `ActivityService.recordCook(...)` (the client service currently can't write
   activity). Cook mode would call it on finish.
3. **Meal-plan context.** Thread the originating meal-plan entry id into
   `CookModeScreen` so finishing can mark that entry cooked. Today the screen
   only gets `recipeId`.

Open questions for that plan: should "cooked" be idempotent per meal-plan entry;
should it work offline via the outbox (consistent with the app's offline-first
writes); does the activity feed need pagination once cook events are added.
Scope it as a small backend + thin client plan once prioritised.
