# Plan 002: Carry the canonical item link through the main list composer

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/widgets/list/list_composer_bar.dart frontend/lib/screens/lists/list_detail_screen.dart frontend/lib/screens/lists/list_detail_controller.dart frontend/lib/repositories/list_repository.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The app's grocery intelligence (aisle sorting on shopping trips, restock predictions, purchase history, co-occurrence learning) is entirely keyed on `ListItem.canonicalItemId`. The purchase signal at `frontend/lib/repositories/list_repository.dart:893-894` returns early when it is null. The **main list composer — the most-used way to add items — throws that id away**: tapping a grocery suggestion chip copies only the name into the text field, and `addItem` builds a `CreateListItemRequest` with no canonical id. Result: items added by typing are invisible to every downstream intelligence feature, which is why restock and aisle sorting feel empty. The quick-add dialog already does this correctly; this plan brings the composer to parity.

## Current state

- `frontend/lib/widgets/list/list_composer_bar.dart` — the composer above the keyboard on the list-detail screen. The lossy chip handler (lines ~41-56):

```dart
    void addChip(String name, {required bool fromSeed}) {
      final key = name.toLowerCase();
      if (name.isEmpty || !seen.add(key)) return;
      chips.add(AppChip(
        label: name,
        leading: fromSeed ? const AppIcon(name: 'bolt', size: 14) : null,
        onSelected: (_) {
          controller.text = name;
          onAdd();
        },
      ));
    }

    for (final g in grocerySuggestions) {
      addChip(g.name, fromSeed: true);
    }
    for (final p in productSuggestions) {
      addChip(p.name, fromSeed: false);
    }
```

`grocerySuggestions` is `List<GrocerySuggestion>`; the id is available right there and dropped. `GrocerySuggestion` (from `frontend/lib/services/scan/grocery_suggestion_service.dart:8-20`):

```dart
class GrocerySuggestion {
  final String canonicalItemId;
  final String name; // display name (German preferred, first market)
  final String category; // coarse aisle label
  final String unit;
  ...
}
```

- `frontend/lib/screens/lists/list_detail_screen.dart:1004-1012` — the composer is wired with `onAdd: _addItem` (a zero-arg callback at line 254 that reads `_newItemController.text` and calls `_controller.addItem(text)`).

- `frontend/lib/screens/lists/list_detail_controller.dart:382-400` — `addItem` sends no canonical id:

```dart
  Future<void> addItem(String text) async {
    ...
    final parsed = parseComposerItem(text);
    final ListItem created;
    if (parsed.quantity == 1 && parsed.unit.isEmpty) {
      created = await repo.createItemOfflineFirst(
        listId,
        CreateListItemRequest(name: parsed.name),
      );
    } else {
      created = await repo.addItemAmountOfflineFirst(
        listId,
        name: parsed.name,
        amount: parsed.quantity,
        unit: parsed.unit,
      );
    }
```

- `frontend/lib/repositories/list_repository.dart:161` — `createItemOfflineFirst` already persists `req.canonicalItemId` into the local row (line 186) and the outbox payload (line 211). **`addItemAmountOfflineFirst` (line 231) has no `canonicalItemId` parameter at all** — its new-item branch (lines ~272-284) creates a `ListItem` without one, and its outbox payload (lines ~289-299) omits it.

- **The exemplar to match** — the quick-add dialog does this correctly, including the deliberate product decision that a free-typed name gets NO canonical link (no guessing): `frontend/lib/screens/lists/lists_screen.dart:1003-1050`:

```dart
    String? selectedCanonicalId;
    ...
      body: GrocerySuggestionField(
        ...
        submitOnSelect: true,
        onSelected: (s) => selectedCanonicalId = s.canonicalItemId,
        ...
      // Typed-and-tapped-Add path: no suggestion chosen, so no canonical
      // link (a free-typed name shouldn't guess at one).
```

- Repo conventions: design-system widgets (`AppChip`, `AppIcon`), no raw Material; `dart analyze lib/` must stay clean.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0, no issues |
| Tests | `cd frontend && flutter test test/frontend_flows_test.dart` | all pass |
| Focused test | `cd frontend && flutter test test/<new file>` | all pass |

Note: `flutter test` needs libsqlite3 on the host (Drift native). If tests fail with a missing-sqlite error, report it — do not try to install system packages.

## Scope

**In scope** (the only files you should modify):
- `frontend/lib/widgets/list/list_composer_bar.dart`
- `frontend/lib/screens/lists/list_detail_screen.dart`
- `frontend/lib/screens/lists/list_detail_controller.dart`
- `frontend/lib/repositories/list_repository.dart` (only `addItemAmountOfflineFirst`)
- `frontend/test/` (new test file)

**Out of scope** (do NOT touch, even though they look related):
- `frontend/lib/widgets/grocery_suggestion_field.dart` and the quick-add flow — already correct.
- Resolving free-typed text to a canonical id (no chip tapped) — deliberate product decision to not guess; that is direction work (plans/018), not this fix.
- The restock strip path — `addRestockSuggestion` already passes `canonicalItemId` (`list_detail_controller.dart:418-426`).
- Backend/outbox drainer code — `createItem` payload already carries the field.
- Converging `ListComposerBar` onto `GrocerySuggestionField` (widget unification) — deferred; note it in the PR description instead.

## Git workflow

- Branch: `advisor/002-composer-canonical-link`
- Commit style: conventional commits, e.g. `fix(lists): carry canonical item id through composer suggestion chips`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Pass the selected suggestion out of `ListComposerBar`

In `list_composer_bar.dart`, add an optional callback field:

```dart
  /// Called when a grocery (seed) suggestion chip is tapped, before [onAdd],
  /// so the caller can capture the canonical link for the item about to be
  /// created. Product-history chips carry no canonical id and don't call this.
  final ValueChanged<GrocerySuggestion>? onGrocerySuggestionSelected;
```

Change the seed-chip loop so the suggestion object reaches the callback. The `addChip` closure currently takes only a name; restructure so the grocery loop passes the suggestion:

```dart
    for (final g in grocerySuggestions) {
      addChip(g.name, fromSeed: true, suggestion: g);
    }
```

and inside `addChip`, before `onAdd()`:

```dart
        onSelected: (_) {
          controller.text = name;
          if (suggestion != null) onGrocerySuggestionSelected?.call(suggestion);
          onAdd();
        },
```

Import of `GrocerySuggestion` already exists in this file (it declares `List<GrocerySuggestion> grocerySuggestions`).

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Capture the id in the screen and thread it into `addItem`

In `list_detail_screen.dart`:

- Add a field `String? _pendingCanonicalId;` on the state class near `_isSaving`.
- Wire the new callback in `_buildBottomBar()`:

```dart
    return ListComposerBar(
      ...
      onGrocerySuggestionSelected: (s) => _pendingCanonicalId = s.canonicalItemId,
```

- In `_addItem` (line 254): read and clear the pending id at the top (after the `text.isEmpty` guard), and pass it to the controller:

```dart
    final canonicalId = _pendingCanonicalId;
    _pendingCanonicalId = null;
    ...
      await _controller.addItem(text, canonicalItemId: canonicalId);
```

Important: `_pendingCanonicalId` must be cleared on every add attempt (including failures — do not restore it in the catch block; the text is restored but a retyped/edited entry shouldn't inherit a stale link). Chips call `onAdd()` immediately after setting the text, so the id cannot go stale between tap and add.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 3: Accept the id in the controller and repository

In `list_detail_controller.dart`, change the signature to `Future<void> addItem(String text, {String? canonicalItemId})` and pass it into both branches:

- `CreateListItemRequest(name: parsed.name, canonicalItemId: canonicalItemId)`
- `repo.addItemAmountOfflineFirst(listId, name: parsed.name, amount: parsed.quantity, unit: parsed.unit, canonicalItemId: canonicalItemId)`

In `list_repository.dart`, add `String? canonicalItemId` as a named parameter to `addItemAmountOfflineFirst` and:

- In the **merge branch** (existing row matched by name+unit): keep `canonicalItemId: existing.canonicalItemId` as-is, but if `existing.canonicalItemId == null && canonicalItemId != null`, use the new id (a merge onto an unlinked row is an upgrade, not a conflict).
- In the **new-item branch**: set `canonicalItemId: canonicalItemId` on the `ListItem`.
- In the outbox payload map: add `if (canonicalItemId != null) 'canonicalItemId': canonicalItemId,` — matching the `createItem` payload shape at line 211.

Check `frontend/lib/services/outbox/` (or wherever `addItemAmount` outbox entries are drained — search `'addItemAmount'`) for whether the drainer forwards payload fields to the API; if the API's add-amount endpoint has no canonical field, the local row still carries the id (which is what the on-device intelligence reads) — that is acceptable; note it in the PR description. `CreateListItemRequest.toJson` already guards with `isApiUuid` (`list_models.dart:174`), so local slug ids are never sent to the server.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 4: Test

Write `frontend/test/widgets/list_composer_canonical_test.dart`. Pattern: existing widget tests in `frontend/test/` use `ProviderScope` overrides (see AGENTS.md "Riverpod override pattern") — but for this, a plain widget test of `ListComposerBar` suffices:

- Pump `ListComposerBar` with one `GrocerySuggestion(canonicalItemId: 'milk', name: 'Milch', category: 'dairy', unit: 'l')` and `showProductSuggestions: true`.
- Tap the "Milch" chip.
- Assert `onGrocerySuggestionSelected` fired with `canonicalItemId == 'milk'` and `onAdd` fired after it, and `controller.text == 'Milch'`.

Plus a repository-level test (pattern: any existing test constructing `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))` — see AGENTS.md) asserting `addItemAmountOfflineFirst(..., canonicalItemId: 'x')` writes a local row whose `canonicalItemId` is `'x'`.

**Verify**: `cd frontend && flutter test test/widgets/list_composer_canonical_test.dart` → all pass

## Test plan

- Widget: chip tap → callback carries the id, add fires, text filled (new file above).
- Repository: `addItemAmountOfflineFirst` new-item branch persists the id; merge branch upgrades a null id and never downgrades a non-null one.
- Regression: `flutter test test/frontend_flows_test.dart` still passes.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] New tests pass; `flutter test test/frontend_flows_test.dart` passes
- [ ] `grep -n "onGrocerySuggestionSelected" frontend/lib/screens/lists/list_detail_screen.dart` shows the screen wiring
- [ ] `grep -n "canonicalItemId" frontend/lib/screens/lists/list_detail_controller.dart` shows `addItem` threading it
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `ListComposerBar` no longer receives `List<GrocerySuggestion>` (someone reduced it to names since planning).
- `addItemAmountOfflineFirst` gained a canonical-id parameter already (fix landed independently) — verify and mark the plan REJECTED in the index.
- Threading the id appears to require changing the outbox drainer's API contract — the local write is the required part; server-side add-amount canonical support is out of scope.

## Maintenance notes

- After this lands, purchase signals (`list_repository.dart:893`) start flowing for chip-selected items; restock (`restock_service.dart`) needs ≥3 purchases per item before it predicts, so visible impact lags by a few shopping cycles.
- Future widget unification (composer → `GrocerySuggestionField`) should preserve this callback contract; the quick-add's "no guessing for free-typed names" rule is a product decision — keep it.
- Reviewer should scrutinize: `_pendingCanonicalId` lifecycle — set only on chip tap, cleared on every add attempt, never restored on failure.
