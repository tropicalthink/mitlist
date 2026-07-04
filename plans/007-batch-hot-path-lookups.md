# Plan 007: Batch the N+1 lookups on the scan resolution hot path

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/scan/resolution/candidate_generator.dart frontend/lib/services/scan/suggestion_service.dart frontend/lib/storage/app_database.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (if plans 003/004 landed first, re-run their test suites at the end)
- **Category**: perf
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Scanning a receipt resolves every line through `CandidateGenerator.generate`, which currently issues one `getCanonicalItemById` query **per candidate** and one `findAlias` query **per classifier prediction** — for a 30-line receipt with ~10 union candidates each, that's 300+ single-row SQLite queries just to materialise rows it already holds ids for. `SuggestionService` has the same shape (2 queries per suggestion). The batch query these loops need (`getCanonicalItemsByIds`) already exists in the database layer; nothing uses it on this path.

## Current state

- `frontend/lib/services/scan/resolution/candidate_generator.dart:69-79` — per-prediction alias lookup:

```dart
    if (_classifier != null) {
      final preds = await _classifier.classify(rawText, topK: modelTopK);
      for (final p in preds) {
        final alias = await _db.findAlias(
            groupId: groupId, aliasText: normaliseText(p.label));
        if (alias == null) continue;
        ...
```

- `candidate_generator.dart:92-107` — per-candidate materialisation:

```dart
    // Materialise: fetch canonical rows, drop any that no longer exist.
    final out = <ResolutionCandidate>[];
    for (final entry in acc.entries) {
      final item = await _db.getCanonicalItemById(entry.key);
      if (item == null) continue;
      ...
```

- `frontend/lib/services/scan/suggestion_service.dart:60-78` — per-suggestion candidate + trigger lookups inside the ranking loop (`getCanonicalItemById(entry.key)` and `getCanonicalItemById(triggerId)`).

- Already available: `frontend/lib/storage/app_database.dart:1149-1156`:

```dart
  Future<List<CanonicalItemsTableData>> getCanonicalItemsByIds(
      Iterable<String> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const []);
    return (select(canonicalItemsTable)
          ..where((t) => t.id.isIn(list) & t.deletedAt.isNull()))
        .get();
  }
```

- Missing: a batch alias-by-texts lookup. `findAlias` (`app_database.dart:1209-1223`) returns the single top-weighted household-or-global row for ONE text. The classifier loop needs the same semantics for a set of texts.

- Behavioral note you must preserve: `getCanonicalItemById` does NOT filter `deletedAt`, but `getCanonicalItemsByIds` DOES. On the candidate-materialisation path this filter is correct (the loop's intent comment says "drop any that no longer exist"), and on the suggestion path a deleted item should not be suggested — so the batch swap slightly *improves* behavior; state this in the commit message.

- Tests covering this code: `frontend/test/services/candidate_generator_test.dart`, `frontend/test/services/canonical_resolver_service_test.dart`, `frontend/test/services/resolution_baseline_test.dart` — these are the regression net; they must pass unchanged.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Regression | `cd frontend && flutter test test/services/` | all pass |

## Scope

**In scope**:
- `frontend/lib/services/scan/resolution/candidate_generator.dart`
- `frontend/lib/services/scan/suggestion_service.dart`
- `frontend/lib/storage/app_database.dart` (one new query: `findAliasesByTexts`)

**Out of scope**:
- The legacy resolver's per-prediction `findAlias` in `canonical_resolver_service.dart:189` — legacy path, being displaced by the ensemble; not worth churning.
- `EnsembleResolver.buildContext`'s per-list-item co-occurrence loop — bounded by list size and shared per scan via `prepareContext`; leave it.
- Any scoring/ranking behavior change.

## Git workflow

- Branch: `advisor/007-batch-hot-path-lookups`
- Commit style: `perf(scan): batch canonical and alias lookups in candidate generation`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the batch alias lookup

In `app_database.dart`, next to `findAlias` (line 1209):

```dart
  /// Batch form of [findAlias]: for each text in [aliasTexts], the top-weighted
  /// non-deleted household-or-global alias row. Returns a map keyed by
  /// alias_text; texts with no alias are absent.
  Future<Map<String, ItemAliasesTableData>> findAliasesByTexts({
    required String groupId,
    required Set<String> aliasTexts,
  }) async {
    if (aliasTexts.isEmpty) return const {};
    final rows = await (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.aliasText.isIn(aliasTexts.toList()) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.weight)]))
        .get();
    final out = <String, ItemAliasesTableData>{};
    for (final r in rows) {
      out.putIfAbsent(r.aliasText, () => r); // first = heaviest per text
    }
    return out;
  }
```

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Use it in the classifier loop

In `candidate_generator.dart`, replace the per-prediction `findAlias` loop: classify once, normalise all labels, one `findAliasesByTexts` call, then iterate predictions consulting the map. Preserve the existing accumulation semantics (`if (p.score > c.classifierProb)`, `sources.add('classifier')`).

**Verify**: `cd frontend && flutter test test/services/candidate_generator_test.dart` → all pass

### Step 3: Batch the materialisation

Replace the `for (final entry in acc.entries) { getCanonicalItemById... }` loop with one `getCanonicalItemsByIds(acc.keys)` call, build `Map<String, CanonicalItemsTableData>` by id, then assemble `ResolutionCandidate`s from the map (absent id → skipped, same as today's null check).

**Verify**: `cd frontend && flutter test test/services/` → all pass

### Step 4: Batch `SuggestionService`

After sorting, collect the top-`maxSuggestions` candidate ids **plus** their trigger ids into one set, fetch via `getCanonicalItemsByIds`, and build results from the map. Preserve: skip when the candidate row is missing or its display name is empty; the `'often with <trigger>'` fallback to `'often bought together'` when the trigger row/name is missing.

**Verify**: `cd frontend && flutter test test/services/` → all pass

## Test plan

No new behavior — the existing suites are the net. If `test/services/` has no direct `SuggestionService` test (check `ls frontend/test/services/ | grep -i suggestion`), add one small case in a new `frontend/test/services/suggestion_service_test.dart`: seed two canonical items + one co-occurrence row (see `canonical_resolver_service_test.dart` for the seeding pattern), assert one suggestion with the trigger-based reason string. This pins the map-based rewrite to the old semantics.

## Done criteria

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -n "getCanonicalItemById" frontend/lib/services/scan/resolution/candidate_generator.dart frontend/lib/services/scan/suggestion_service.dart` → no matches
- [ ] `grep -c "await _db.findAlias(" frontend/lib/services/scan/resolution/candidate_generator.dart` → 0 (the exact-alias `findAliasesByText` at the top of `generate` is a different method and stays)
- [ ] `cd frontend && flutter test test/services/` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any existing resolution test fails after Step 3 in a way that traces to the `deletedAt` filter difference — that means production data relies on resolving deleted items; report, don't loosen the filter silently.
- `acc` keys exceed ~500 in a test (SQLite `IN` limits) — not expected (candidate unions are tens), but if hit, report rather than chunking ad hoc.

## Maintenance notes

- Plan 004 adds a per-resolve reject lookup in `EnsembleResolver`; if both land, consider folding that into this batching pass later (noted in 004 too).
- Reviewer should scrutinize: `putIfAbsent` in Step 1 relies on the weight-desc ordering — one query, first row per text wins; a future change to that `orderBy` silently changes alias precedence.
