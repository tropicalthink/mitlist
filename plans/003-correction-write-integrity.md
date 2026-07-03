# Plan 003: Stop correction memory from polluting itself

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/scan/correction_memory_service.dart frontend/lib/screens/scanner/scan_review_screen.dart frontend/lib/services/scan/scan_models.dart frontend/lib/services/grocery_seed_loader.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Correction memory is the mechanism that makes grocery resolution improve with use: user fixes → household alias → next scan resolves right. Today it has three defects that make it **degrade** with use instead:

1. **Unreviewed guesses are recorded as confirmed corrections.** After a scan, every item whose OCR text differs from the resolved display name gets an alias written and weight-incremented — including auto-accepted items the user never looked at. A wrong auto-accept therefore reinforces itself: next scan, the exact-alias lookup hits the poisoned alias at score 1.0.
2. **A correction can hijack a global seed alias row.** When the top-weighted existing alias for the text is a *global* row pointing at a different item, the upsert reuses that row's primary key, converting the shipped global alias into a household row — destroying the global mapping and the alias collision the ensemble scorer deliberately relies on.
3. **Corrections are stored with a different normalisation than lookups use.** Writes do `toLowerCase().trim()`; every lookup normalises with whitespace-collapse too. An OCR string with a doubled space gets stored in a form the exact-match lookup can never produce — the user's correction silently doesn't stick.

## Current state

- `frontend/lib/services/scan/correction_memory_service.dart` — the whole file is 94 lines; the write path (lines 22-75):

```dart
  Future<void> recordAlias({ ... String source = 'manual_review', }) async {
    final normalised = rawText.toLowerCase().trim();          // ← defect 3
    ...
    final existing = await _db.findAlias(
      groupId: groupId,
      aliasText: normalised,
    );

    if (existing != null && existing.canonicalItemId == canonicalItemId) {
      await _db.incrementAliasWeight(existing.id);
    } else {
      // Upsert with household scope (overrides any global seed).
      await _db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: existing?.id ?? _uuid.v4(),                     // ← defect 2
          groupId: groupId,
          canonicalItemId: canonicalItemId,
          ...
```

`findAlias` (`frontend/lib/storage/app_database.dart:1209-1223`) returns household **or** `__global__` rows (highest weight first), and `upsertItemAliases` (line 1281) is `insertAllOnConflictUpdate` keyed on primary key `id` — so when `existing` is a global row with a different canonical id, the write **overwrites the global row in place**.

- `frontend/lib/screens/scanner/scan_review_screen.dart:302-317` — the over-eager write (defect 1):

```dart
    for (final item in _items) {
      if (item.canonicalItemId != null &&
          item.rawText.toLowerCase() != item.displayName.toLowerCase()) {
        await correctionSvc.recordAlias(...);
        unawaited(groceryRepo.uploadCorrection(...));
      }
    }
```

There is no check that the user edited the item, and no gate on `confidenceLevel`.

- How user edits happen in that screen: items are `GroceryPrediction` (immutable, `frontend/lib/services/scan/scan_models.dart:55+`, has `copyWith`). Edits flow through `_updateItem(index, updated)` (`scan_review_screen.dart:259-261`), fed by `_ItemEditorSheet.onSave` (line 894/984) and inline accept actions. `_acceptAll` (line 278-284) bulk-maps items to `ConfidenceLevel.autoAccept` — bulk-accept is *not* an item-level confirmation.

- The correct normalisation helper already exists: `normaliseText` in `frontend/lib/services/scan/resolution/string_sim.dart:7-8` (`toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ')`). Its doc comment calls it "the single normalisation the resolver and the alias table agree on" — this plan makes that claim true.

- Same stale normalisation (no whitespace collapse) in the seed ingest paths: `frontend/lib/services/grocery_seed_loader.dart:76` (OFF aliases) and `:159` (seed aliases). Seed data is generated and unlikely to contain internal double spaces, but making the writes uniform is one-line each and removes the class of bug.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Focused tests | `cd frontend && flutter test test/services/correction_memory_test.dart` | all pass |
| Regression | `cd frontend && flutter test test/services/` | all pass |

`flutter test` needs libsqlite3 on the host; if it errors on missing sqlite, report instead of installing packages.

## Scope

**In scope** (the only files you should modify):
- `frontend/lib/services/scan/correction_memory_service.dart`
- `frontend/lib/screens/scanner/scan_review_screen.dart`
- `frontend/lib/services/scan/scan_models.dart` (add one field to `GroceryPrediction`)
- `frontend/lib/services/grocery_seed_loader.dart` (normalisation only)
- `frontend/test/services/correction_memory_test.dart` (create)

**Out of scope** (do NOT touch):
- `findAlias` / `upsertItemAliases` in `app_database.dart` — their semantics are relied on elsewhere; fix the caller.
- The reject path (`recordReject`) — Plan 004.
- `uploadCorrection` retry/outbox behavior — Plan 005/008 territory.
- Renormalising rows already written with the old form on user devices — the app is pre-release (see RELEASING.md); existing installs are dev devices. Do not write a data migration.

## Git workflow

- Branch: `advisor/003-correction-write-integrity`
- Commit style: conventional commits, e.g. `fix(scan): only record user-confirmed corrections; never overwrite global aliases`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Unify normalisation on `normaliseText`

- `correction_memory_service.dart`: import `resolution/string_sim.dart`; in `recordAlias` replace `rawText.toLowerCase().trim()` with `normaliseText(rawText)`; in `recordReject` replace `rawText.toLowerCase().trim()` likewise.
- `grocery_seed_loader.dart`: in `_loadOffAliasesIfNeeded` (line 76) and `_ingestSeed`'s `addAlias` (line 159), replace `.toLowerCase().trim()` with `normaliseText(...)` (import `../services/scan/resolution/string_sim.dart` — check the relative path compiles; the file lives at `frontend/lib/services/grocery_seed_loader.dart` so the import is `scan/resolution/string_sim.dart`).

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Fix the global-row hijack in `recordAlias`

Replace the upsert branch so a row id is only ever reused for a **household-owned** row:

```dart
    if (existing != null && existing.canonicalItemId == canonicalItemId) {
      await _db.incrementAliasWeight(existing.id);
    } else {
      // Never reuse a global seed row's id: overwriting it would destroy the
      // shipped mapping (and the alias collision the ensemble scores against).
      // A household correction gets its own row; findAlias prefers it via
      // weight ordering.
      final reuseId =
          (existing != null && existing.groupId == groupId) ? existing.id : null;
      await _db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: reuseId ?? _uuid.v4(),
          groupId: groupId,
          canonicalItemId: canonicalItemId,
          aliasText: normalised,
          lang: const Value('und'),
          source: const Value('correction'),
          weight: Value((existing?.weight ?? 0) + 1),
          version: const Value(0),
          createdAt: (reuseId != null ? existing!.createdAt : now),
          updatedAt: now,
        ),
      ]);
    }
```

Note the weight: `existing.weight + 1` is kept deliberately even when `existing` is global, so the new household row outranks the global row in `findAlias`'s `ORDER BY weight DESC`.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 3: Add a `userConfirmed` flag to `GroceryPrediction`

In `scan_models.dart`, add to `GroceryPrediction`: `final bool userConfirmed;` (default `false` in the constructor), and thread it through `copyWith` (the class already has one — extend it; if `copyWith` uses explicit params, add `bool? userConfirmed` handling like its siblings).

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 4: Set the flag only on genuine user actions in `scan_review_screen.dart`

- In `_updateItem(index, updated)` — this is the single funnel for editor-sheet saves and inline corrections. Set the flag when the canonical target or display name actually changed:

```dart
  void _updateItem(int index, GroceryPrediction updated) {
    final prev = _items[index];
    final confirmed = updated.userConfirmed ||
        updated.canonicalItemId != prev.canonicalItemId ||
        updated.displayName != prev.displayName;
    setState(() => _items[index] = updated.copyWith(userConfirmed: confirmed));
  }
```

- Do **NOT** set the flag in `_acceptAll` (bulk accept is not per-item confirmation) or in `_addSuggestion` (a suggestion the user tapped is already a direct canonical pick — no alias learning needed; its rawText equals its displayName anyway).

### Step 5: Gate the correction write on the flag

In `_addToList` (line ~302), change the condition to:

```dart
      if (item.userConfirmed &&
          item.canonicalItemId != null &&
          item.rawText.toLowerCase() != item.displayName.toLowerCase()) {
```

Leave the `recordAlias` + `uploadCorrection` calls unchanged inside.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 6: Tests

Create `frontend/test/services/correction_memory_test.dart` using the in-memory Drift pattern from AGENTS.md (`AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`). Model setup on `frontend/test/services/canonical_resolver_service_test.dart` (it seeds canonical items + aliases directly). Cases:

1. **Hijack regression**: seed a global alias row (`groupId: '__global__'`, `aliasText: 'spaghetti'`, canonical `egg_spaghetti`). Call `recordAlias(groupId: 'g1', rawText: 'spaghetti', canonicalItemId: 'spaghetti_plain')`. Assert: the global row still exists unchanged (same id, same groupId `__global__`, same canonical), AND a new household row exists with `groupId: 'g1'`, canonical `spaghetti_plain`, weight 2 (global was 1), AND `findAlias(groupId: 'g1', aliasText: 'spaghetti')` now returns the household row.
2. **Reinforce path**: call `recordAlias` twice with the same household mapping → one alias row, weight incremented.
3. **Normalisation**: `recordAlias(rawText: 'voll  milch\t')` → stored `aliasText == 'voll milch'`, and `findAliasesByText(groupId, 'voll milch')` finds it.
4. **Household-row overwrite still allowed**: an existing *household* alias for the same text pointing at item A, corrected to item B → same row id, canonical now B.

**Verify**: `cd frontend && flutter test test/services/correction_memory_test.dart` → all pass, and `flutter test test/services/` → all pass (the resolver/ensemble suites must not regress)

## Test plan

Covered by Step 6. Additionally run the full `flutter test test/services/` to confirm the resolver tests (which exercise alias data) still pass with the normalisation change.

## Done criteria

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -n "toLowerCase().trim()" frontend/lib/services/scan/correction_memory_service.dart frontend/lib/services/grocery_seed_loader.dart` → no matches
- [ ] New test file passes; `flutter test test/services/` passes
- [ ] `grep -n "userConfirmed" frontend/lib/screens/scanner/scan_review_screen.dart` shows the gate in `_addToList` and the funnel in `_updateItem`
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `GroceryPrediction` has no `copyWith`, or `_updateItem` is no longer the single edit funnel (extra mutation paths exist) — enumerate the paths you found and report.
- The hijack test (case 1) fails because `findAlias` ordering does not prefer the heavier household row — that means weight-based override is broken more deeply; report rather than patching `findAlias`.
- You find production code depending on auto-accept alias writes (e.g. a test asserting aliases exist after an unedited scan) — the intent change needs a human decision.

## Maintenance notes

- Alias volume will drop sharply (only user-confirmed edits write). That is intended: quality over quantity of learning signal. If growth is later wanted, add *low-weight* confirmations for auto-accepts rather than reverting the gate.
- Plan 004 (reject path) builds on the same screen and service; it assumes `userConfirmed` exists.
- Reviewer should scrutinize: Step 2's `createdAt` handling (reused household row keeps its `createdAt`; new row uses `now`), and that `_addSuggestion` items can never enter the correction loop (rawText == displayName).
