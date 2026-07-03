# Plan 011: Make the scan-review store picker use the store-id space the aisle data actually lives in

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/screens/scanner/scan_review_screen.dart frontend/lib/providers/store_provider.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The app has two disjoint store identities. The bundled aisle layouts (`assets/grocery/store_aisles.json`) and the store selector used by the scan pipeline and the shopping trip use **seed slugs** (`de_rewe`, `en_tesco`, … — verified in the asset). The scan-review screen instead loads the household's backend `ShoppingLocation`s (server UUIDs) and queries local aisle rows with those ids — which never match seeded rows. Its store dropdown is therefore decorative: switching stores in review silently changes nothing, and the aisle feedback it uploads is tagged with a store id no layout knows. The fix is to use the same provider-based store selection the rest of the app already standardised on.

## Current state

- `frontend/lib/screens/scanner/scan_review_screen.dart:94-125` — the wrong id space:

```dart
  Future<void> _loadStores() async {
    ...
      final svc = await ref.read(listServiceProviderAsync.future);
      final stores = await svc.listShoppingLocations(widget.groupId);
      ...
        _activeStore = stores.isNotEmpty ? stores.first : null;
      });
      if (_activeStore != null) await _refreshAisles(_activeStore!.id);
    ...
  Future<void> _refreshAisles(String storeId) async {
    final db = ref.read(appDatabaseProvider);
    final aisles = await db.getStoreAisles(
      groupId: widget.groupId,
      storeId: storeId,          // ← backend UUID; seeded rows carry 'de_rewe' etc.
    );
```

`_activeStore` (`ShoppingLocation`) also feeds `_uploadAisleFeedback` (`scan_review_screen.dart:205-220`) as `storeId`.

- The id space the aisle data actually uses — `frontend/lib/providers/store_provider.dart`:
  - `storeCatalogProvider` reads the shipped stores (`id: 'de_rewe'`-style) from `assets/grocery/store_aisles.json`.
  - `selectedStoreIdProvider` is the persisted household choice (SharedPreferences).
- Consumers already on the correct space: `frontend/lib/widgets/list/list_scan_launcher.dart:99` (passes `selectedStoreIdProvider` into the pipeline) and `frontend/lib/screens/shopping/shopping_trip_screen.dart:152` (`_recomputeAisles` reads `selectedStoreIdProvider`). The trip screen also has a store-picker UI built on `storeCatalogProvider` (lines ~357, ~484) — that is the exemplar picker.
- The scan pipeline already received a `storeId` for aisle mapping when the scan launched, so review's own aisle refresh is a *re*-sort after the user changes store mid-review.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Full tests | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `frontend/lib/screens/scanner/scan_review_screen.dart`

**Out of scope**:
- `store_provider.dart`, the trip screen, the launcher — already correct.
- Mapping backend `ShoppingLocation`s to shipped layouts (a real feature: "my REWE at Hauptstraße uses the de_rewe layout") — that is a design decision for Plan 019's spike; do not invent a mapping table here.
- `updateAisleFeedback` internals in `grocery_repository.dart` (Plan 005 already adjusts the non-UUID store-id upload behavior).

## Git workflow

- Branch: `advisor/011-store-id-unification`
- Commit style: `fix(scan): review store picker uses shipped layout ids like the rest of the app`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Swap the data source

In `scan_review_screen.dart`:

- Delete `_loadStores` and the `_stores`/`_activeStore` fields typed on `ShoppingLocation`.
- Replace with the provider pair the trip screen uses: watch `storeCatalogProvider` (for options) and `selectedStoreIdProvider` (for the current choice). Local state: `String? _activeStoreId`, initialised from `ref.read(selectedStoreIdProvider)` in `initState`, falling back to the launcher-provided store if the screen receives one (check the widget's constructor params — if the scan result carries the storeId used at pipeline time, prefer it).
- The dropdown items become `StoreOption.label` entries; on change: `setState(() => _activeStoreId = id); await _refreshAisles(id);` and persist the choice via `ref.read(selectedStoreIdProvider.notifier).select(id)` — review is a legitimate place to set the household's store, and persisting keeps review/trip/launcher agreeing.
- `_refreshAisles` body is unchanged — it now receives ids that match seeded rows.
- `_uploadAisleFeedback` uses `_activeStoreId` for `storeId`.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Confirm the aisle refresh now matches rows

Add a temporary debug assertion? No — prove it with a test instead (Step 3). Manually trace once by reading: `db.getStoreAisles(groupId, storeId)` (`app_database.dart:1361`-area) filters `storeId.equals(...)`; the seed loader ingests aisle rows with `storeId` from the asset (`grocery_seed_loader.dart:117-119`). Same strings now flow both sides.

### Step 3: Widget/unit test

Add `frontend/test/services/store_aisle_refresh_test.dart` (in-memory Drift): seed one canonical item and one `StoreAislesTableCompanion` row with `storeId: 'de_rewe'`, `aisle: 'dairy'`, `sortOrder: 5` for group `'__global__'`; assert `getStoreAisles(groupId: <g>, storeId: 'de_rewe')` returns it — mirroring exactly what `_refreshAisles` queries. (Check the actual `getStoreAisles` signature/group handling in `app_database.dart` first — if it filters household-or-global like the alias queries, the test group can be arbitrary; if not, use `'__global__'`.)

**Verify**: `cd frontend && flutter test test/services/store_aisle_refresh_test.dart` → pass; `flutter test` → pass

## Test plan

Step 3, plus a compile-level guarantee that `ShoppingLocation` no longer appears in the review screen (done criteria grep). If a widget test drives the review screen with a fake `listServiceProviderAsync`, it may need its override removed — adjust rather than re-adding the service dependency.

## Done criteria

- [ ] `grep -n "listShoppingLocations\|ShoppingLocation" frontend/lib/screens/scanner/scan_review_screen.dart` → no matches
- [ ] `grep -n "selectedStoreIdProvider\|storeCatalogProvider" frontend/lib/screens/scanner/scan_review_screen.dart` → present
- [ ] `cd frontend && dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The review screen's store dropdown turns out to serve a second purpose tied to backend locations (e.g. expense/receipt attribution reads `_activeStore`) — grep `_activeStore` usages first; if any non-aisle consumer exists, report before deleting.
- `storeCatalogProvider`'s asset shape lacks the `stores` array (asset regenerated differently since planning).

## Maintenance notes

- Backend `ShoppingLocation`s remain the right entity for *where the household shops* (addresses, expense attribution); shipped layout ids are *how a store is laid out*. The eventual mapping between them (location → layout) is Plan 019 spike material; this plan just stops the two from being conflated in one dropdown.
- Reviewer should scrutinize: the persisted-selection side effect (review now writes `selectedStoreIdProvider`) — intended, but call it out in the PR.
