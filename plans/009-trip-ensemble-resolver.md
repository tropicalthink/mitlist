# Plan 009: Use the ensemble resolver (with shared context) in the shopping-trip aisle recompute

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/screens/shopping/shopping_trip_screen.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (better after 002, which reduces how many items need text resolution at all)
- **Category**: bug / tech-debt
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The shopping-trip screen resolves free-typed items to canonical ids so they can be aisle-sorted — using the **legacy sequential resolver with no ensemble, no models, and no household prior** (`CanonicalResolverService(db)`), while the scanner uses the full plan-037 ensemble. Same input class (messy human item names), two quality tiers. Worse, the legacy call runs once per item in a loop with no shared context, so it re-reads nothing but also learns nothing from the household. Upgrading is a two-line construction change plus using the context-sharing API that already exists for exactly this multi-item case.

## Current state

- `frontend/lib/screens/shopping/shopping_trip_screen.dart:151-187` — `_recomputeAisles`:

```dart
    final db = ref.read(appDatabaseProvider);
    final resolver = CanonicalResolverService(db);
    final result = <String, _ItemAisle>{};

    for (final items in _itemsByList.values) {
      for (final item in items) {
        // Prefer the canonical link stored on the item ... Fall back to
        // resolving the typed text for free-entered items with no link.
        final canonicalId = item.canonicalItemId ??
            (await resolver.resolve(item.name, groupId)).canonicalItemId;
        ...
```

- The production construction to mirror — `frontend/lib/services/scan/scan_pipeline_service.dart:37-46`:

```dart
        _resolver = CanonicalResolverService(
          db,
          classifier: GroceryClassifierService(),
          embedder: StaticEmbeddingService(),
          useEnsemble: true,
        ),
```

- The context-sharing API built for multi-item resolution — `frontend/lib/services/scan/canonical_resolver_service.dart:60-93`: `prepareContext(groupId, listContext: [...])` builds the household prior (purchase history + co-occurrence) once; `resolve(..., context: ctx)` reuses it per item.

- Ensemble results are calibrated probabilities with thresholds (`ResolveResult.score`, `autoThreshold`). For aisle sorting, accepting a sub-threshold guess just to place an item in an aisle is fine UX-wise (worst case: wrong aisle bucket, no data written) — but do NOT write anything back; this path is read-only today and must stay read-only.

- Providers exist for the shared services: `staticEmbeddingServiceProvider` (`frontend/lib/providers/grocery_provider.dart:16-18`). There is no provider for `GroceryClassifierService`; the pipeline constructs it directly. The embedder provider matters because `StaticEmbeddingService` lazily loads an ~10 MB bundle — reuse the provider's instance rather than constructing a second one.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Regression | `cd frontend && flutter test` | all pass |

## Scope

**In scope**:
- `frontend/lib/screens/shopping/shopping_trip_screen.dart`

**Out of scope**:
- Writing resolved ids back onto items (tempting, but that mutates list items from a recompute path — needs product thought; note as follow-up).
- `scan_pipeline_service.dart`, resolver internals, providers.
- The store-id space problem (Plan 011).

## Git workflow

- Branch: `advisor/009-trip-ensemble-resolver`
- Commit style: `fix(shopping): resolve trip items with the ensemble + shared household context`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Upgrade the resolver construction and share context

In `_recomputeAisles`, replace the construction and hoist a shared context (linked items double as list-context for the co-occurrence prior):

```dart
    final db = ref.read(appDatabaseProvider);
    final resolver = CanonicalResolverService(
      db,
      classifier: GroceryClassifierService(),
      embedder: ref.read(staticEmbeddingServiceProvider),
      useEnsemble: true,
    );
    final linkedIds = [
      for (final items in _itemsByList.values)
        for (final item in items)
          if (item.canonicalItemId != null) item.canonicalItemId!,
    ];
    final ctx = await resolver.prepareContext(groupId, listContext: linkedIds);
```

and pass it in the loop:

```dart
        final canonicalId = item.canonicalItemId ??
            (await resolver.resolve(item.name, groupId, context: ctx))
                .canonicalItemId;
```

Add the imports the file is missing (`grocery_classifier_service.dart`, `grocery_provider.dart` for the embedder provider; match the file's existing import style/ordering).

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Guard latency

`_recomputeAisles` is `unawaited(...)` from the load path (line 130), so it's already off the critical path. Two things to check by reading, not measuring: (a) the loop only calls `resolve` for items with `canonicalItemId == null` (already true — the `??` short-circuits); (b) `resolver` and `ctx` are built once per recompute, not per item (that's what Step 1 does). No further change.

### Step 3: Regression

**Verify**: `cd frontend && flutter test` → all pass. If any shopping-trip widget test constructs this screen without asset bundles, the ensemble's model loads fail soft (classifier/embedder return empty) — behavior matches the DB-only ensemble, which the resolution tests already cover.

## Test plan

Existing suites only — this is a construction swap on an already-fail-soft path. If `frontend/test/` contains a shopping-trip test (check `ls frontend/test/ | grep -ri shopping`), run it explicitly and confirm no timeout from model loading in the test env.

## Done criteria

- [ ] `grep -n "CanonicalResolverService(db)" frontend/lib/screens/shopping/shopping_trip_screen.dart` → no matches
- [ ] `grep -n "prepareContext" frontend/lib/screens/shopping/shopping_trip_screen.dart` → present
- [ ] `cd frontend && dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `prepareContext`'s signature changed (it returns `null` when `useEnsemble` is false — with `useEnsemble: true` it must return a context; if you get `null`, the flag didn't take).
- A widget test hangs on `StaticEmbeddingService` isolate spawn in the test environment — report; do not strip the embedder from the construction to make tests pass.

## Maintenance notes

- Follow-up (deliberately out of scope): persist high-confidence resolutions (`score >= autoThreshold`) back onto unlinked items so the next trip skips re-resolving — needs the same confirmation semantics as Plan 003 decided for scans.
- When Plan 002 lands, most items arrive linked and this loop's resolve branch becomes rare — the upgrade still matters for legacy items and free-typed adds.
