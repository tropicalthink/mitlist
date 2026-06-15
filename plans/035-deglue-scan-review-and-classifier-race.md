# Plan 035: De-glue the scan review screen and fix the classifier load race

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update this plan's status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 45ae60c2..HEAD -- frontend/lib/screens/scanner/scan_review_screen.dart frontend/lib/services/scan/grocery_classifier_inference_native.dart`
> If either in-scope file changed, compare the "Current state" excerpts against
> the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `45ae60c2`, 2026-06-15

## Why this matters

The scan-review screen — one of the newest, most-touched surfaces — is the only
place in the app still built from **raw Material widgets** (`TextButton`,
`Icon(Icons.*)`, `DropdownButton`, `ActionChip`) instead of the App* design
system every other screen uses. That is exactly the "feels glued on"
inconsistency: different button ripple, different icon weights, hardcoded
colors, and a `DropdownButton` that ignores `AppDropdown` styling. Bringing this
screen onto the design system makes the scan flow feel native to the app.

Separately, `grocery_classifier_inference_native.dart` has an **unguarded async
load**: `_ensureLoaded()` checks `_interpreter != null` then `await`s the asset
load with no in-flight guard. The pipeline calls `classify()` per OCR line, and
those can run concurrently — two concurrent first-calls both pass the nil check
and both load the interpreter/labels/vocab, racing on the shared fields. The
sibling embedder already solved this with a `_loadFuture` guard; the classifier
should match.

## Current state

### Part A — raw Material widgets in `scan_review_screen.dart`

The screen already imports and uses the design system elsewhere (e.g. the app
bar `leading` uses `AppIcon(name: 'arrowLeft')` at `:387`). The remaining raw
widgets (confirmed via grep at `45ae60c2`):

- `TextButton` at `:393` ("Accept all (N)" app-bar action) and `:813`.
- `Icon(Icons.store_outlined)` `:408`, `Icon(Icons.shopping_cart_outlined)` `:542`, `Icon(Icons.edit_outlined)` `:741`, `Icon(Icons.check_circle_outline)` `:743`, `Icon(Icons.remove_circle_outline)` `:750`, `Icon(Icons.remove_done_outlined)` `:800`.
- `DropdownButton<ShoppingLocation>` at `:419` (store picker).
- `ActionChip` at `:612` and `:925`.

Example (`:392-397`):

```dart
actions: [
  if (pendingCount > 0)
    TextButton(
      onPressed: _acceptAll,
      child: Text('Accept all ($pendingCount)'),
    ),
],
```

The design-system components and their APIs:

- `AppButton` (`frontend/lib/widgets/app_button.dart`): `AppButton({String? text, Widget? icon, VoidCallback? onPressed, AppButtonVariant variant, AppButtonColor color, AppButtonSize size, ...})`. Variants: `solid|outline|ghost|soft`. For a text action like "Accept all", use `variant: AppButtonVariant.ghost, size: AppButtonSize.sm`.
- `AppIcon` (`frontend/lib/widgets/app_icon.dart`): `AppIcon({required String name, double size = 20, Color? color})`. Names resolve via `AppIcons.resolve` in `frontend/lib/widgets/icons.dart`.
- `AppDropdown` (`frontend/lib/widgets/app_dropdown.dart`): read its constructor before use; it is generic over the value type like `DropdownButton`.

Icon-name mapping (verify each against `frontend/lib/widgets/icons.dart`'s
`resolve` switch before using; **if a name is absent, add a registry entry** in
`icons.dart` following the existing `static const IconData x = Icons.y;` +
`'x' => x,` pattern rather than falling back to a raw `Icon`):

| Raw Material icon            | Existing AppIcon name (verify)        |
|------------------------------|----------------------------------------|
| `Icons.shopping_cart_outlined` | `shoppingCart` or `shoppingBagOutline` |
| `Icons.check_circle_outline` | `checkCircleOutline`                   |
| `Icons.remove_circle_outline`| `minusCircleOutline`                   |
| `Icons.edit_outlined`        | `pencil` or `editNote`                 |
| `Icons.store_outlined`       | **likely missing — add `'storeOutline' => storeOutline` (`Icons.store_outlined`)** |
| `Icons.remove_done_outlined` | **likely missing — add a registry entry** |

`ActionChip` has no direct App* equivalent in `frontend/lib/widgets/` (confirm
with `ls frontend/lib/widgets/`). If none exists, **leave the two `ActionChip`s
as-is** (out of scope — see Scope) and only restyle their `avatar:
Icon(Icons.add)` to `AppIcon(name: 'plus')`. Do **not** invent a new shared
component in this plan.

### Part B — classifier load race

`frontend/lib/services/scan/grocery_classifier_inference_native.dart:30-58`:

```dart
Future<void> _ensureLoaded() async {
  if (_unavailable || _interpreter != null) return;
  try {
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    // ... loads _labels, _idf, _stripChars, _vocabIndex ...
  } catch (_) {
    _interpreter?.close();
    _interpreter = null;
    _unavailable = true;
  }
}
```

The proven pattern is in the sibling embedder
`frontend/lib/services/scan/static_embedding_service.dart:199-205`:

```dart
Future<void> _load() async {
  _loadFuture ??= _doLoad();   // single in-flight future, shared by all callers
  await _loadFuture;
}
Future<void> _doLoad() async { ... }
```

`dispose()` already exists (`grocery_classifier_inference_native.dart:93-95`)
and is wired through `GroceryClassifierService.dispose()`
(`grocery_classifier_service.dart:68`). The owning `scanPipelineProvider`
(`frontend/lib/providers/grocery_provider.dart:35`) is a `FutureProvider` with
no `ref.onDispose`, so the interpreter is never closed on provider invalidation
(minor leak — see Maintenance notes; not fixed here unless trivial).

### Conventions

- No raw Material widgets, no hardcoded pixels — use `MitlistSpacing.*` and `theme.textTheme`/`colorScheme` (the screen already does this around the raw widgets).
- Web safety: the classifier is the **native** implementation; do not change the stub web variant. The `_loadFuture` guard is pure Dart and web-safe.

## Commands you will need

| Purpose   | Command                                                          | Expected            |
|-----------|------------------------------------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`                               | no new issues       |
| Format    | `cd frontend && dart format lib/screens/scanner/scan_review_screen.dart lib/services/scan/grocery_classifier_inference_native.dart lib/widgets/icons.dart` | exit 0 |
| Tests     | `cd frontend && flutter test`                                   | all pass            |

## Scope

**In scope**:
- `frontend/lib/screens/scanner/scan_review_screen.dart`
- `frontend/lib/services/scan/grocery_classifier_inference_native.dart`
- `frontend/lib/widgets/icons.dart` (only to **add** missing icon-name entries; do not remove/rename existing ones)

**Out of scope**:
- `ActionChip` → no new shared component; only restyle their inner icons. Replacing chips wholesale is deferred.
- The web stub classifier (`grocery_classifier_inference_web.dart` or equivalent) — leave its `const []` fail-soft contract untouched.
- Any change to scan **behaviour** (resolution tiers, accept/ignore logic) — this is a presentation + concurrency-safety pass only.
- `account_screen.dart` — its previously-noted raw `Switch` is already gone; do not touch it.

## Git workflow

- Branch: `advisor/035-deglue-scan-review-and-classifier-race`
- Commit per part; conventional-commit style. Examples: `refactor(scan): move scan review onto App* design system`, `fix(scan): guard classifier asset load against concurrent init`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add the classifier load guard (Part B first — smallest, isolated)

In `grocery_classifier_inference_native.dart`, add a `Future<void>? _loadFuture;`
field next to `_unavailable`, and restructure so all callers await one shared
future. Rename the existing body to `_doLoad()` and make `_ensureLoaded()`:

```dart
Future<void>? _loadFuture;

Future<void> _ensureLoaded() {
  _loadFuture ??= _doLoad();
  return _loadFuture!;
}

Future<void> _doLoad() async {
  if (_unavailable || _interpreter != null) return;
  try {
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    // ... unchanged load body ...
  } catch (_) {
    _interpreter?.close();
    _interpreter = null;
    _unavailable = true;
  }
}
```

In `dispose()`, also reset the guard so a disposed instance can reload if reused:
`_loadFuture = null;` (alongside the existing `_interpreter = null;`).

**Verify**: `cd frontend && dart analyze lib/services/scan/grocery_classifier_inference_native.dart` → no new issues. Then `cd frontend && flutter test test/services/` (run the scan/classifier tests if present; `ls test/services/`).

### Step 2: Replace TextButtons with AppButton

Replace the `TextButton` at `:393` and `:813` with `AppButton` using
`variant: AppButtonVariant.ghost`, an appropriate `size`, the same `onPressed`,
and `text:` (read the surrounding code at `:813` to preserve any style intent).

**Verify**: `cd frontend && dart analyze lib/screens/scanner/scan_review_screen.dart` → no new issues.

### Step 3: Replace raw Icons with AppIcon

Replace each `Icon(Icons.*)` listed in "Current state" with `AppIcon(name: ...,
size: <same>, color: <same>)`. For names not in `icons.dart`'s `resolve` switch,
add a registry entry first (Step driver: `store_outlined`, `remove_done_outlined`
are the likely additions). Preserve each call's existing `size` and `color`
arguments exactly.

**Verify**: `cd frontend && dart analyze lib/screens/scanner/scan_review_screen.dart lib/widgets/icons.dart` → no new issues. Confirm no unknown-name fallback: `grep -n "Icon(Icons\." lib/screens/scanner/scan_review_screen.dart` → only the `avatar:` icons inside the two out-of-scope `ActionChip`s may remain; everything else gone.

### Step 4: Replace the store-picker DropdownButton with AppDropdown

Read `frontend/lib/widgets/app_dropdown.dart` for its exact constructor, then
replace the `DropdownButton<ShoppingLocation>` at `:419` with `AppDropdown`,
preserving `value: _activeStore`, the item label mapping (`s.name`), and
`onChanged: _onStoreChanged`. If `AppDropdown`'s API cannot express the
`isDense`/`underline: SizedBox.shrink()` inline-compact look, accept the
design-system default styling (that is the point of de-gluing) — do not
re-add raw styling overrides.

**Verify**: `cd frontend && dart analyze lib/screens/scanner/scan_review_screen.dart` → no new issues.

### Step 5: Restyle ActionChip inner icons; format; full analyze

Change the two `ActionChip` `avatar: Icon(Icons.add, ...)` to
`AppIcon(name: 'plus', size: 14)` (keep the chips themselves). Then run format
and a full analyze.

**Verify**:
- `cd frontend && dart format lib/screens/scanner/scan_review_screen.dart lib/services/scan/grocery_classifier_inference_native.dart lib/widgets/icons.dart` → exit 0
- `cd frontend && dart analyze lib/` → no new issues
- `cd frontend && flutter test` → all pass

## Test plan

- This is primarily a presentation + concurrency-safety refactor; rely on the existing widget/unit suite to catch regressions (`flutter test`).
- If a classifier test exists under `test/services/`, add a case that calls `classify()` twice concurrently (`await Future.wait([svc.classify('milk'), svc.classify('eggs')])`) and asserts both resolve without error and the interpreter loaded once — model it on the existing classifier test structure. If no such test file exists, do not create a new test harness from scratch; note it in the PR description instead.
- Verification: `cd frontend && flutter test` → all pass.

## Done criteria

ALL must hold:

- [ ] `cd frontend && dart analyze lib/` reports no new issues vs. baseline
- [ ] `cd frontend && flutter test` exits 0
- [ ] `grep -n "TextButton\|DropdownButton<" frontend/lib/screens/scanner/scan_review_screen.dart` returns no matches
- [ ] `grep -n "Icon(Icons\." frontend/lib/screens/scanner/scan_review_screen.dart` returns at most the two `ActionChip` avatars (now `AppIcon`, so ideally zero)
- [ ] `grep -n "_loadFuture" frontend/lib/services/scan/grocery_classifier_inference_native.dart` shows the guard present
- [ ] `cd frontend && dart format --output=none --set-exit-if-changed lib/screens/scanner/scan_review_screen.dart` exits 0
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- "Current state" excerpts/line numbers don't match live code (drift since `45ae60c2`) — re-grep to relocate, but if the widgets are structurally different, STOP.
- `AppDropdown`'s API genuinely cannot represent a single-select store picker (Step 4) — report rather than reverting to `DropdownButton`.
- Replacing a raw icon would require a Material icon with no sensible semantic name and you are unsure what to name it — report the specific icon.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The `scanPipelineProvider` (`grocery_provider.dart:35`) never disposes the classifier on invalidation. A follow-up could add `ref.onDispose(() => service.dispose())` — deferred here to keep this plan presentation-focused. The `_loadFuture` reset in `dispose()` (Step 1) makes that follow-up safe.
- Reviewer should scrutinise: the icon-name additions in `icons.dart` (correct `IconData` mapping) and that `AppDropdown` preserves store-selection behaviour.
- Deferred sibling findings (not in this plan): FX-rate input hardening in `expense_creation_sheet.dart` (H7) and FX audit-trail display in `expenses_screen.dart` (C3) — they share no files with this scan work, so per the operator's "fold only where files overlap" they are recorded as deferred in `plans/README.md`.
