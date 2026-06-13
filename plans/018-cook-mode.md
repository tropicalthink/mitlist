# Plan 018: Build a cook mode that is genuinely better than reading the recipe page

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 62741654..HEAD -- frontend/lib/screens/recipes/ frontend/lib/router.dart frontend/lib/models/recipe_models.dart frontend/pubspec.yaml`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED (new dependency, new UX surface; no backend changes)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `62741654`, 2026-06-12

## Why this matters

mitlist's own README concedes "cook mode" to Paprika, and PRODUCT.md names the
exact moment: "users open the app… while cooking." The recipe detail screen
(landed at `62741654`) is a reading surface — fine on the couch, useless at the
counter: text too small to read at arm's length, quantities live in a separate
ingredient card from the step that needs them, the screen sleeps onto wet
hands, and timers happen on a different app.

**The maintainer's explicit brief** (this is the design constitution for the
whole plan — every decision below traces to it):

1. Cook mode must be **better than the normal page** — if it's just the steps
   with bigger padding in a swipe-pager, it has failed.
2. **Minimize required screen interaction.** Hands are wet, floury, or holding
   a knife. Every forced touch is a cost. The mode must never be annoying.
3. **Design around how people actually cook**, not around a data structure.
   People cook non-linearly: they re-read the last step, peek ahead, run two
   things in parallel, and need "how much flour?" *inside* "add the flour."
4. Same philosophy as the chore-system redesign: "a card list ain't how people
   function." A flat numbered card list forces the user to think; the mode
   should remove thinking.

## The design (what you are building)

One new full-screen route: `/recipes/:recipeId/cook`, entered from a "Cook"
button on the recipe detail screen. Two phases inside one screen:

### Phase A — Mise en place (entry state)

Before cooking, one screen that answers "am I ready?":

- **Servings stepper** at the top: `− 4 servings +` (defaults to
  `recipe.servings`, min 1). This sets the scale factor for everything after.
- **Ingredient gather list**: each ingredient as a tall tappable row
  (min 56px) with a fat checkbox, name, and the *scaled* quantity in
  `MitlistTypography.monoBody`. Checking is a memory aid only — it never
  gates the start button.
- **Equipment chips** (from `recipe.equipmentJson`) if present.
- Full-width `Start cooking` AppButton (size lg) pinned at the bottom.

### Phase B — Cook flow (the core)

**Not a pager.** A single vertical flow of ALL steps, always scrollable, with
one step "current":

- **Current step**: rendered huge — Space Grotesk via
  `theme.textTheme.headlineSmall.copyWith(fontSize: 28, height: 1.35)` or
  larger; must be comfortably readable at ~70 cm (test: hold the phone at
  arm's length). Left-bordered with a 4px `colorScheme.primary` bar (hard
  edges, no rounding — brand).
- **Done steps**: collapse to a single dim line each (`bodySmall`,
  `onSurfaceVariant`, struck or check-prefixed) so the recent past is
  glanceable without dominating.
- **Upcoming steps**: full text at `bodyMedium`, slightly dimmed — peeking
  ahead requires zero interaction, just eyes.
- **Advancing**: ONE primary gesture — a full-width, ≥ 88px tall "Done →"
  zone fixed at the bottom (knuckle-friendly; a wet knuckle can hit it
  without precision). Advancing scrolls the new current step into view and
  fires `Haptics.light()`.
- **Jumping**: tapping any step makes it current (non-linear cooking is
  normal, not an error). Free scrolling NEVER changes the current step; when
  the current step is scrolled off-screen, show a small "Back to step N"
  pill (floating, `colorScheme.primary` background) that scrolls home.
- **Glance bar**: slim persistent top bar: `Step 3 of 8` + active timer
  countdowns + close (X) button. This is the across-the-kitchen readout.

### Inline quantities (kills the scroll-back-to-ingredients failure)

When rendering the *current* step's text, match ingredient names from
`_ingredients` against the step text (case-insensitive, longest name first,
whole-word match) and append the scaled quantity inline in mono + bold:
"Fold in the **flour · 300 g** and stir." Implement as a pure function
returning `List<InlineSpan>` so it's unit-testable. Also keep a persistent
"Ingredients" handle (bottom-left, above the Done zone) that opens the full
scaled list via `showAppBottomSheet` — the fallback when matching misses.

### Timers (kills the separate-timer-app failure)

- Parse durations from each step's text with a pure function
  (`parseStepDurations`): handle `10 min`, `10 minutes`, `1 hour`,
  `1–2 hours`, `90 seconds`, `1 hr 30 min` (for ranges take the lower
  bound). Implement with regex; return `List<Duration>`.
- Steps with parsed durations show a timer chip (`AppChip` style, mono
  countdown text when running): one tap starts it. Multiple timers run
  concurrently; all running timers tick in the glance bar.
- On completion: `Haptics` heavy/success + a full-screen 300ms primary-color
  flash (skipped under reduced motion — use an instant color change + 
  SnackBar instead) + the chip turns to "Done". v1 is in-app only: no
  notifications, no background ringing (deferred — see Maintenance notes).

### Scaling rules

`scale = selectedServings / recipe.servings` (guard `recipe.servings < 1` →
treat as 1).

- Structured ingredients (`quantity > 0`): display `quantity * scale`,
  formatted: round to 2 decimals, strip trailing zeros, render `.5` as `½`,
  `.25` as `¼`, `.75` as `¾` when the fractional part matches exactly.
- rawText-only ingredients (`quantity == 0`): show `rawText` unchanged, with
  an `(unscaled)` suffix in `onSurfaceVariant` ONLY when `scale != 1.0`.
  Never attempt to parse-and-scale rawText.

### Always

- **Keep the screen awake** for the entire route (wakelock; see Step 1).
- Honor reduced motion: `MediaQuery.of(context).disableAnimations` — follow
  the exact pattern in `frontend/lib/widgets/odometer.dart:29-30`
  (`effectiveDuration = disableAnimations ? Duration.zero : duration`).
- Brand: `BorderRadius.zero` everywhere, 2px borders, `AppIcon` (never raw
  `Icon(Icons.*)`), spacing via `MitlistSpacing` tokens, sentence-case labels
  ("Start cooking", not "Start Cooking").
- Semantics labels on the advance zone, timer chips, and step jumps; touch
  targets ≥ 44pt (the advance zone is deliberately double that).

## Current state

- `frontend/lib/screens/recipes/recipe_detail_screen.dart` — the detail
  screen this mode launches from. It loads recipe + ingredients + steps in
  `_load()` (lines 50–80) and currently renders steps as a numbered card
  list (lines 400–445). Its bottom bar (lines 156–175) holds a single
  full-width "Add to list" AppButton — you will put "Cook" next to it.
- `frontend/lib/models/recipe_models.dart` — data you'll consume:

  ```dart
  // recipe_models.dart:411-418
  class RecipeIngredient {
    final String id;
    final String recipeId;
    final String name;
    final double quantity;   // 0 when unstructured
    final String unit;       // '' when unstructured
    final String rawText;    // original line, always safe to display
    final int position;
  ```

  ```dart
  // recipe_models.dart:118-131
  class RecipeStep {
    final String id;
    final String recipeId;
    final String name;        // often ''
    final String description; // the step text
    final int position;
  ```

  `Recipe` has `servings` (int, json default 1), `cookTime`/`prepTime`
  (minutes, 0 = unset), `equipmentJson` (JSON array string — see
  `_parseEquipment` at `recipe_detail_screen.dart:498-509` for the parsing
  pattern to reuse).
- `frontend/lib/services/recipe_service.dart:197,209` —
  `getRecipeIngredients(recipeId)` / `getRecipeSteps(recipeId)` already
  exist. The detail screen already fetched them; pass the loaded data into
  the cook route via `state.extra` AND re-fetch inside the cook screen if
  extra is null (deep-link safety).
- `frontend/lib/router.dart:204-240` — the recipes branch. Existing child
  route pattern to copy:

  ```dart
  GoRoute(
    path: ':recipeId',
    name: 'recipeDetail',
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => RecipeDetailScreen(
      recipeId: state.pathParameters['recipeId']!,
    ),
  ),
  ```

- Design system: tokens in `frontend/lib/theme/` (`colors.dart`,
  `spacing.dart` — xs=4 sm=8 md=16 lg=24 xl=32, `typography.dart` —
  `MitlistTypography.monoBody`), shared widgets in `frontend/lib/widgets/`
  (`AppButton`, `AppCard`, `AppChip`, `AppIcon`, `app_bottom_sheet.dart`).
  Haptics helper: `frontend/lib/utils/haptics.dart` (`Haptics.light()` —
  see usage at `recipe_detail_screen.dart:122`).
- `frontend/pubspec.yaml` — `environment: sdk: ^3.6.1`. Drift is
  deliberately pinned for this SDK; do not touch any existing version pins.

## Commands you will need

| Purpose   | Command                              | Expected on success |
|-----------|--------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`   | exit 0 (2 pre-existing info-level `dart:html` deprecations in web-only files are OK) |
| Tests     | `cd frontend && flutter test`        | all pass (99 existing + your new ones) |
| Deps      | `cd frontend && flutter pub get`     | exit 0 |

Linux test hosts need `libsqlite3-dev` (documented in `frontend/README.md`).

## Suggested executor toolkit

- If the `impeccable` skill/plugin is available in your environment, Step 7
  uses it as the design-critique gate. If unavailable, perform the critique
  manually against the checklist in Step 7.

## Scope

**In scope** (the only files you should modify or create):
- `frontend/lib/screens/recipes/cook_mode_screen.dart` (create)
- `frontend/lib/utils/cook_mode.dart` (create — pure logic: duration parser,
  ingredient matcher, scaling formatter)
- `frontend/lib/screens/recipes/recipe_detail_screen.dart` (add the Cook
  button + route push only)
- `frontend/lib/router.dart` (add the cook route only)
- `frontend/pubspec.yaml` (add `wakelock_plus` only)
- `frontend/test/utils/cook_mode_test.dart` (create)
- `frontend/test/cook_mode_screen_test.dart` (create)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- Anything in `backend/` — this is a pure frontend feature over existing
  endpoints.
- `frontend/lib/sheets/recipe_add_to_list_sheet.dart` and the
  add-to-list flow — separate concern.
- `frontend/lib/services/recipe_service.dart` — the two getters you need
  already exist.
- Recipe creation/edit, scraping, meal plans.
- Voice control, notifications, background timer ringing — explicitly
  deferred (Maintenance notes).
- Existing version pins in `pubspec.yaml` (especially Drift).

## Git workflow

- Branch: `feat/cook-mode` off `new-main-fr`.
- Conventional-commit style, matching repo history (e.g.
  `feat: implement recipe detail screen and enhance recipe navigation`).
  Commit per step or logical unit.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add wakelock_plus

Add `wakelock_plus: ^1.2.8` to `frontend/pubspec.yaml` dependencies (next to
the other platform plugins, around `url_launcher`). Run `flutter pub get`.
wakelock_plus 1.2.x requires Dart >= 3.0, compatible with the `^3.6.1` pin.

**Verify**: `cd frontend && flutter pub get` → exit 0, no resolution
conflicts. If the resolver fights the Drift/SDK pins, see STOP conditions.

### Step 2: Pure logic in `lib/utils/cook_mode.dart`

Write, with doc comments, no Flutter imports beyond `flutter/painting.dart`
if needed for spans (prefer returning data, building spans in the widget):

1. `double cookScale(int baseServings, int selectedServings)` — guard
   `baseServings < 1` → 1.
2. `String formatScaledQuantity(double quantity, double scale)` — the
   scaling rules from the design section (2-decimal round, strip zeros,
   ½/¼/¾ for exact .5/.25/.75 fractional parts).
3. `List<Duration> parseStepDurations(String text)` — the formats listed in
   the design section. Case-insensitive. `1 hr 30 min` → one Duration of 90
   minutes (adjacent hour+minute pairs combine); `1–2 hours` → 1 hour.
4. `List<IngredientMatch> matchIngredients(String stepText, List<RecipeIngredient> ingredients)`
   — case-insensitive, whole-word, longest-name-first, each text region
   matched at most once. Return match offsets + the ingredient, so the
   widget can build styled spans. Skip ingredients whose `name` is shorter
   than 3 characters (avoids "egg" matching inside "eggs" is fine — whole-word
   handles plurals poorly; match `name` and `name + 's'` as a cheap plural).

**Verify**: `cd frontend && dart analyze lib/` → exit 0.

### Step 3: Cook mode screen — skeleton, route, entry button

- Create `cook_mode_screen.dart` with `CookModeScreen({recipeId, recipe?, ingredients?, steps?})`:
  loads via `recipeServiceProviderAsync` when the optional data isn't passed
  (copy the `_load()` pattern from `recipe_detail_screen.dart:50-80`,
  including the best-effort try/catch around ingredients/steps).
- `WakelockPlus.enable()` in `initState`, `WakelockPlus.disable()` in
  `dispose`.
- Register in `router.dart` under the `:recipeId` route as a child:
  `path: 'cook'`, `name: 'recipeCook'`, `parentNavigatorKey: _rootNavigatorKey`,
  passing loaded data through `state.extra` as a `Map<String, Object?>`.
- In `recipe_detail_screen.dart`, change the bottom bar to a `Row`: keep
  "Add to list" (outline variant now) and add a primary "Cook" AppButton
  (size lg, expanded) that pushes the cook route with the already-loaded
  `_recipe`/`_ingredients`/`_steps`. Show the Cook button ONLY when
  `_steps.isNotEmpty`.

**Verify**: `dart analyze lib/` → exit 0. `flutter test` → existing suite
still green.

### Step 4: Phase A — mise en place

Build the entry state per the design: servings stepper, gather list with
scaled mono quantities (via `formatScaledQuantity`; rawText-only ingredients
per the scaling rules), equipment chips, pinned "Start cooking" button.
State: `selectedServings` (int), `gathered` (Set of ingredient ids) — plain
`setState` locals; this is ephemeral session state, do NOT persist it or
route it through Riverpod/outbox.

**Verify**: `dart analyze lib/` → exit 0.

### Step 5: Phase B — cook flow

Build the flow per the design: glance bar, vertical step flow
(done-collapsed / current-huge / upcoming-dim), bottom Done zone, tap-to-jump,
"Back to step N" pill (track visibility with a `ScrollController` and the
current step's context — a `GlobalKey` per current step +
`Scrollable.ensureVisible` on advance is acceptable), inline ingredient
quantities on the current step via `matchIngredients`, the Ingredients
bottom-sheet handle, and a terminal "Finished — nice work" state with an
exit button when the last step is done. Honor `disableAnimations` for the
ensureVisible scroll (Duration.zero) per the odometer pattern.

**Verify**: `dart analyze lib/` → exit 0.

### Step 6: Timers

Per the design: chips on steps with `parseStepDurations` hits, concurrent
countdowns (one `Timer.periodic` ticking a map of end-times is fine —
cancel it in `dispose`; the repo's resource-safety lints will flag you if
you don't), glance-bar display, completion haptic + flash (instant
color + SnackBar under reduced motion).

**Verify**: `dart analyze lib/` → exit 0 (including `cancel_subscriptions` /
resource lints).

### Step 7: Design critique gate

The maintainer explicitly asked for this. Run the `impeccable` critique
skill on the cook mode screen if available; otherwise self-critique. Either
way, evaluate against the brief and fix what fails:

- [ ] At arm's length (~70 cm), is the current step readable and is "what do
      I do next" answerable with zero touches?
- [ ] Can a user advance with one imprecise knuckle tap?
- [ ] Can they check "how much flour" without leaving the current step?
- [ ] Can they peek ahead / re-read behind without changing state?
- [ ] Is anything animated, modal, or chatty enough to be *annoying* on the
      fifth use? (Confirmation dialogs, tips, tooltips → remove.)
- [ ] Does it look like mitlist (hard edges, orange, mono quantities) and
      not like a generic recipe app?
- [ ] Reduced motion: no scroll animations or flashes when
      `disableAnimations` is true?

Apply at most one iteration of fixes from the critique, staying inside Scope.

**Verify**: `dart analyze lib/` → exit 0; checklist items all checked in
your report.

### Step 8: Tests

See Test plan.

**Verify**: `cd frontend && flutter test` → all pass.

## Test plan

- `frontend/test/utils/cook_mode_test.dart` (pure logic — model after the
  existing tests under `frontend/test/utils/`):
  - `formatScaledQuantity`: 300×1.0→"300", 300×1.5→"450", 0.5×1→"½",
    1.25×1→"1¼", 0.33×1→"0.33", trailing-zero stripping.
  - `cookScale`: base 0 or negative → 1.0; 4→6 = 1.5.
  - `parseStepDurations`: "simmer 10 min", "bake 1 hour", "1 hr 30 min"→90m,
    "1–2 hours"→60m, "90 seconds", text with no duration → empty, two
    durations in one step → two entries.
  - `matchIngredients`: basic hit, case-insensitive, longest-first ("red
    onion" wins over "onion"), plural ("eggs" matches ingredient "egg"),
    no partial-word hits ("flour" must not match "flourish"), each region
    matched once.
- `frontend/test/cook_mode_screen_test.dart` (widget — model the structure
  of `frontend/test/widget_test.dart` / the fakes under
  `frontend/test/support/`): pump `CookModeScreen` with injected
  recipe/ingredients/steps (constructor params — no network), then:
  - mise en place shows scaled quantity after tapping the stepper,
  - "Start cooking" reveals the flow with step 1 current (`Step 1 of N`
    visible),
  - tapping "Done" advances to `Step 2 of N`,
  - tapping a later step jumps current to it,
  - finishing the last step shows the finished state.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0 (modulo the 2 pre-existing
      web-only infos)
- [ ] `cd frontend && flutter test` exits 0; new test files exist with ≥ 15
      new tests passing
- [ ] `grep -n "recipeCook" frontend/lib/router.dart` → 1 match
- [ ] `grep -n "WakelockPlus.enable" frontend/lib/screens/recipes/cook_mode_screen.dart` → ≥ 1 match, and a matching `disable` in `dispose`
- [ ] `grep -rn "Icons\." frontend/lib/screens/recipes/cook_mode_screen.dart` → no matches (AppIcon only)
- [ ] `grep -rn "BorderRadius.circular" frontend/lib/screens/recipes/cook_mode_screen.dart` → no matches
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] Step 7 checklist reported with all items checked
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `flutter pub get` cannot resolve `wakelock_plus` against the `sdk: ^3.6.1`
  / Drift pins at any `1.x` version. Do NOT hand-roll a platform channel and
  do NOT loosen existing pins — report, and note that shipping without
  keep-awake is a maintainer decision, not yours.
- The recipe detail screen's bottom bar or `_load()` no longer matches the
  excerpts (drift — e.g. someone restructured the screen).
- `getRecipeSteps` turns out to return data in a shape other than
  `List<RecipeStep>` with `description`/`position`.
- The widget tests cannot inject data without network because the screen's
  constructor params were not implemented as specified — fix the screen, not
  the tests, and stop if that conflicts with the router contract.
- Step 7's critique demands changes outside Scope (e.g. backend timer
  persistence) — record them as follow-ups in your report instead.

## Maintenance notes

- **Deferred, deliberately**: background/notification timers (ringing when
  the app is backgrounded — needs local-notifications plumbing and platform
  permissions); voice/gesture advancement; per-step images; syncing "who is
  cooking" to the household. Any of these is a new plan.
- The ingredient matcher is heuristic. If recipe scraping later produces
  ingredient names with quantities embedded in `name`, inline quantities
  will double-display — the matcher and scraper should be reviewed together.
- If recipe *editing* lands, the cook route's `state.extra` fast-path can
  serve stale data; the re-fetch fallback already covers deep links, but an
  edit-while-cooking scenario should invalidate or just always re-fetch.
- Reviewer scrutiny: timer disposal (one periodic ticker, cancelled), the
  wakelock disable path on all exits (pop, finish, error), and that the
  advance zone really is reachable one-handed on small phones.
