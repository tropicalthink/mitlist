# Plan 019: Surface tonight's meal on the hub and connect the meal plan to cook mode

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 40f73b32..HEAD -- frontend/lib/widgets/hub/ frontend/lib/screens/home/household_hub_screen.dart frontend/lib/screens/meal_plans/meal_plan_screen.dart frontend/lib/providers/meal_plan_provider.dart frontend/test/frontend_flows_test.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW–MED (frontend only, additive; one existing-test repair)
- **Depends on**: 018 (DONE — cook mode and the `recipeCook` route must exist)
- **Category**: direction
- **Planned at**: commit `40f73b32`, 2026-06-12

## Why this matters

"What's for dinner?" is the most-asked question in any household, and mitlist
has no answer surface: the hub shows chores due and balances but nothing about
tonight's meal, and the meal plan screen is a dead end — a planned day-slot is
literally not tappable (`meal_plan_screen.dart:527`: `onTap: plan == null ?
onAdd : null`). Meanwhile cook mode (plan 018, merged at `40f73b32`) exists
but is only reachable by manually browsing Recipes. This plan completes the
chain the maintainer asked for: **hub "Tonight: lasagna" → recipe → Cook**,
and makes planned meals tappable everywhere. Design philosophy (maintainer's
standing brief): surfaces answer the household's actual question at the
moment it's asked — don't make people think or navigate.

## Current state

- `frontend/lib/screens/home/household_hub_screen.dart` — the hub. Sections
  are composed at lines 719–737:

  ```dart
  // household_hub_screen.dart:722-734
  delegate: SliverChildListDelegate([
    StatsGrid(groupId: _resolvedGroupId!),
    const SizedBox(height: MitlistSpacing.lg),
    PinwallSection(groupId: _resolvedGroupId!, me: _me),
    const SizedBox(height: MitlistSpacing.lg),
    ActivityWall(
      activities: _snapshot!.activities,
      ...
  ```

  It has a `RefreshIndicator` calling `_onRefresh` (line 698). Hub widgets
  live in `frontend/lib/widgets/hub/` — `stats_grid.dart` is the exemplar: a
  `ConsumerWidget` that watches `.family` providers keyed by `groupId`.
- `frontend/lib/screens/meal_plans/meal_plan_screen.dart` — week view. Facts:
  - `_load()` (lines 90–110) fetches plans via
    `ref.read(mealPlanServiceProviderAsync.future)` →
    `svc.listMealPlans(groupId, from: 'yyyy-MM-dd', to: 'yyyy-MM-dd')` and
    caches recipes in `_recipeCache` (`Map<String, Recipe>`).
  - `_SlotRow` (lines 487+) renders each slot. The dead-end tap:

    ```dart
    // meal_plan_screen.dart:526-527
    child: InkWell(
      onTap: plan == null ? onAdd : null,
    ```

    Planned rows show recipe title + tags and trailing edit (`pencil`) /
    remove (`xMark`) IconButtons (lines 601–610). `_SlotRow` receives
    callbacks from its parent (`onAdd`, `onRemove`, `onEdit` — see the
    construction at lines 466–479).
- `frontend/lib/models/meal_plan_models.dart` — `MealPlan` has `id`,
  `groupId`, `date` (DateTime), `slot` (string: breakfast/lunch/dinner,
  default 'dinner'), `recipeId`, `servings`, `cookUserId` (nullable).
- `frontend/lib/providers/meal_plan_provider.dart` — currently exposes
  `mealPlanServiceProviderAsync`. The repo's provider convention for derived
  data is `FutureProvider.family` — exemplar:

  ```dart
  // providers/chore_provider.dart:23
  final choresByGroupProvider = FutureProvider.family<List<Chore>, String>((ref, groupId) async {
  ```

- Cook mode entry: route `recipeCook` is registered in `router.dart` under
  `recipes/:recipeId/cook`; `CookModeScreen(recipeId: ...)` self-loads
  recipe/ingredients/steps when not passed via extra, so
  `context.pushNamed('recipeCook', pathParameters: {'recipeId': id})` works
  with no extra. Recipe detail route: `context.pushNamed('recipeDetail',
  pathParameters: {'recipeId': id})`.
- Recipe fetch: `ref.read(recipeServiceProviderAsync.future)` then
  `svc.getRecipe(id)` (see `meal_plan_screen.dart:116-120`).
- **Known broken test you will repair first**:
  `frontend/test/frontend_flows_test.dart:269` "recipe card opens a real
  detail sheet" pumps `RecipesScreen` without a GoRouter; since the detail
  sheet became a routed screen (commit `62741654`), tapping the card throws
  "No GoRouter found in context". The test still expects the old sheet
  strings (`'Recipe details'`). Fakes live in `frontend/test/support/fakes.dart`
  (`FakeRecipeService`, `FakeGroupService`, `FakeMealPlanService`).
- Conventions: design tokens `MitlistSpacing` (xs=4 sm=8 md=16 lg=24 xl=32),
  `MitlistTypography.monoBody`/`labelXSmall`, `AppIcon` (never raw
  `Icons.*`), `AppButton`, `AppCard`, sentence-case labels, section labels
  use `textTheme.labelMedium`. Reduced motion: follow
  `widgets/odometer.dart:29-30` if you animate anything.

## Commands you will need

| Purpose   | Command                              | Expected on success |
|-----------|--------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`   | exit 0 (2 pre-existing info-level `dart:html` deprecations OK) |
| Tests     | `cd frontend && flutter test`        | ALL pass — including the repaired flows test (baseline: 145 pass / 1 fail) |
| Deps      | `cd frontend && flutter pub get`     | exit 0 |

Linux hosts need `libsqlite3-dev` (already installed; report, don't install).

## Scope

**In scope** (the only files you should modify or create):
- `frontend/lib/widgets/hub/tonight_card.dart` (create)
- `frontend/lib/providers/meal_plan_provider.dart` (add one provider)
- `frontend/lib/screens/home/household_hub_screen.dart` (insert the card +
  invalidate provider on refresh)
- `frontend/lib/screens/meal_plans/meal_plan_screen.dart` (tap-through on
  planned slots only)
- `frontend/test/frontend_flows_test.dart` (repair the one broken test)
- `frontend/test/tonight_card_test.dart` (create)
- `frontend/test/support/fakes.dart` (only if a fake needs a new method)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- `frontend/lib/screens/recipes/` including cook mode — entry points only,
  no changes to the screens themselves.
- Anything in `backend/` — `listMealPlans` already serves what's needed.
- `frontend/lib/router.dart` — all needed routes exist.
- The meal-plan creation/edit sheets (`_RecipePickerSheet`,
  `_ServingsPickerSheet`) — only the slot row's tap behavior changes.
- Post-cook activity logging / rating (cycle-4 finding 4 — deliberately not
  selected).

## Git workflow

- Branch: `feat/tonight-cook-chain` off `new-main-fr`.
- Conventional commits (e.g. `feat: surface tonight's meal on the hub`).
  Commit per step or logical unit. Do NOT push or open a PR.

## Steps

### Step 1: Repair the broken flows test (establishes the router-test pattern)

In `frontend/test/frontend_flows_test.dart:269`, the test "recipe card opens
a real detail sheet":

1. Rename it to "recipe card opens the detail screen".
2. Pump with a minimal `GoRouter` instead of a bare widget: a router whose
   initial route renders `RecipesScreen` and which declares
   `GoRoute(path: '/recipes/:recipeId', name: 'recipeDetail', builder: ...
   RecipeDetailScreen(recipeId: ...))`. Reuse the file's existing
   `_pumpScreen` overrides list (group/recipe/mealPlan fakes) — wrap
   `MaterialApp.router` with the same `ProviderScope(overrides: ...)` the
   helper uses (add a router-aware variant of `_pumpScreen` rather than
   changing the existing helper's other call sites).
3. Update expectations to the screen's actual strings: after tapping
   `'Tomato Soup'`, expect `find.text('Recipe')` (app bar), and
   `find.text('Blend and simmer.')`. Drop or update `'Recipe details'` and
   the bare `'4'` expectation to match what `RecipeDetailScreen` renders
   (servings row renders `'4'` via `_DetailRow` — keep it if it passes).
   If `FakeRecipeService` lacks `getRecipeIngredients`/`getRecipeSteps`,
   note the detail screen wraps both in try/catch — an
   `UnimplementedError`-throwing fake is tolerated; add benign overrides in
   `fakes.dart` only if the existing fake hard-fails compilation.

**Verify**: `cd frontend && flutter test test/frontend_flows_test.dart` →
all pass (was 22 pass / 1 fail).

### Step 2: `todayMealPlansProvider`

In `frontend/lib/providers/meal_plan_provider.dart`, add a
`FutureProvider.family` keyed by `groupId` (String) that:

1. Computes today's date (`DateFormat('yyyy-MM-dd')`, local time).
2. Calls `listMealPlans(groupId, from: today, to: today)`.
3. Best-effort fetches each plan's recipe via the recipe service
   (try/catch per recipe, null on failure).
4. Returns a small record/list type pairing each `MealPlan` with its
   `Recipe?` — define it in the provider file (e.g.
   `typedef TodayMeal = ({MealPlan plan, Recipe? recipe});`).

Model the shape after `choresByGroupProvider`
(`providers/chore_provider.dart:23`).

**Verify**: `cd frontend && dart analyze lib/` → exit 0.

### Step 3: `TonightCard` hub widget

Create `frontend/lib/widgets/hub/tonight_card.dart`, a `ConsumerWidget`
watching `todayMealPlansProvider(groupId)`:

- **Slot selection**: prefer the `dinner` plan; if none, fall back to the
  first of today's plans in slot order breakfast → lunch → dinner. Header
  text: `'Tonight'` for dinner, `'Today · Lunch'` / `'Today · Breakfast'`
  otherwise (section label style: `textTheme.labelMedium`).
- **Planned state**: an `AppCard` (outlined) showing the recipe title
  (`textTheme.titleMedium`), a mono sub-line with servings
  (`'serves ${plan.servings}'` via `MitlistTypography.monoBody`), and a
  primary `AppButton` labeled `'Cook'` that calls
  `context.pushNamed('recipeCook', pathParameters: {'recipeId': plan.recipeId})`.
  Tapping the card body (not the button) opens
  `context.pushNamed('recipeDetail', pathParameters: {'recipeId': plan.recipeId})`.
  If the recipe failed to load, title falls back to `'Recipe'` and the card
  still navigates (detail screen self-loads). Wrap the card body in
  `Semantics(button: true, label: 'Tonight: <title>. Open recipe')`.
- **Empty state** (no plans today): a compact single-row card — copy
  `'Nothing planned for tonight'` (`bodyMedium`, `onSurfaceVariant`) with an
  outline `AppButton` `'Plan dinner'` → `context.pushNamed('mealPlan')`.
  Keep it one row tall; the hub must not nag.
- **Loading**: one `AppSkeleton` row sized like the card. **Error**: render
  the empty state (the hub stays calm; no error banners for a nice-to-have).
- Brand: `AppIcon` only, spacing tokens, no `BorderRadius.circular`,
  sentence case.

Insert into the hub between `StatsGrid` and `PinwallSection`
(`household_hub_screen.dart:723-725`), with `MitlistSpacing.lg` gaps
matching neighbors. In `_onRefresh`, add
`ref.invalidate(todayMealPlansProvider)` so pull-to-refresh updates it.

**Verify**: `dart analyze lib/` → exit 0.

### Step 4: Tappable planned slots in the meal plan

In `meal_plan_screen.dart`:

1. Add an `onOpen` callback to `_SlotRow` and thread it from the parent
   construction site (lines 466–479):
   `onOpen: plan != null ? () => context.pushNamed('recipeDetail', pathParameters: {'recipeId': plan.recipeId}) : null`.
2. Change line 527 to `onTap: plan == null ? onAdd : onOpen,`.
3. Update the row's `Semantics` label (line 525): planned rows say
   `'Open recipe for $_slotLabel'`, empty rows keep
   `'Add meal for $_slotLabel'`.
4. Do not change the edit/remove IconButtons — they sit on top of the
   InkWell and keep working.

**Verify**: `dart analyze lib/` → exit 0; `flutter test` → green.

### Step 5: Tests

See Test plan.

**Verify**: `cd frontend && flutter test` → ALL pass, no skips.

## Test plan

- `frontend/test/tonight_card_test.dart` — pump `TonightCard` inside a
  minimal `GoRouter` (reuse the pattern you built in Step 1: home route
  renders the card under test; declare stub `recipeDetail`, `recipeCook`,
  and `mealPlan` named routes whose builders render `Text` markers like
  `'DETAIL'`/`'COOK'`/`'PLAN'`). Override
  `todayMealPlansProvider(groupId)` with `overrideWith` values:
  - dinner planned → shows `'Tonight'` + recipe title + `'Cook'`,
  - tapping `'Cook'` lands on the `'COOK'` marker,
  - tapping the card body lands on `'DETAIL'`,
  - lunch-only day → header `'Today · Lunch'`,
  - no plans → `'Nothing planned for tonight'`, tapping `'Plan dinner'`
    lands on `'PLAN'`.
- The Step 1 repair counts as the meal-chain regression net for
  `recipeDetail` navigation.
- Verification: `cd frontend && flutter test` → all pass; total test count
  strictly greater than 146.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0 (modulo 2 pre-existing infos)
- [ ] `cd frontend && flutter test` exits 0 — **including**
      `frontend_flows_test.dart` (the pre-existing failure is fixed)
- [ ] `grep -n "TonightCard" frontend/lib/screens/home/household_hub_screen.dart` → ≥ 1 match
- [ ] `grep -n "recipeCook" frontend/lib/widgets/hub/tonight_card.dart` → ≥ 1 match
- [ ] `grep -n "onTap: plan == null ? onAdd : null" frontend/lib/screens/meal_plans/meal_plan_screen.dart` → no matches
- [ ] `grep -rn "Icons\.\|BorderRadius.circular" frontend/lib/widgets/hub/tonight_card.dart` → no matches
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The `recipeCook` or `recipeDetail` named routes are missing from
  `router.dart` (plan 018 not actually merged — drift).
- `_SlotRow` or the hub section list no longer matches the excerpts.
- The Step 1 test repair reveals the failure is NOT the missing-GoRouter
  issue described here (different root cause = different plan).
- The flows-test repair requires modifying `RecipesScreen` or
  `RecipeDetailScreen` themselves — fix tests, never screens, in Step 1.
- `listMealPlans` rejects `from == to` (same-day range) — check the
  backend's behavior via the existing week query before working around it.

## Maintenance notes

- If meal "slots" gain custom names beyond breakfast/lunch/dinner, the
  TonightCard slot-preference order and labels must be revisited.
- The provider re-fetches on every hub visit (no Drift caching, matching
  how the hub loads activities). If the hub gets a unified offline snapshot
  later, fold today's meals into it.
- Deliberately deferred: post-cook follow-through (activity entry + rating
  from cook mode's finished state — cycle-4 finding 4) and showing the
  assigned cook's name (`cookUserId` is on the model; resolving names needs
  a member lookup the hub doesn't currently do).
- Reviewer scrutiny: the repaired flows test must assert real navigation
  (marker widgets), not just "no exception"; TonightCard must not introduce
  a loading spinner that makes the hub jumpy on every visit (skeleton, not
  spinner).
