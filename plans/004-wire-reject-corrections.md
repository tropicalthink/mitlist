# Plan 004: Wire the reject path so the resolver can unlearn

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/scan/correction_memory_service.dart frontend/lib/services/scan/resolution/ensemble_resolver.dart frontend/lib/screens/scanner/scan_review_screen.dart frontend/lib/storage/app_database.dart frontend/lib/repositories/grocery_repository.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/003-correction-write-integrity.md (uses the same service; 003's normalisation must land first so reject keys match lookups)
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

`CorrectionMemoryService.recordReject` writes a `kind: 'reject'` correction event meaning "this text should not resolve to that." It has **zero callers**, and no resolution path ever reads reject events — so a user who repeatedly removes the same OCR misread teaches the system nothing, and a wrong auto-accept recurs on every scan of the same receipt format. This plan wires both halves: the review screen's ignore action records the reject, and the ensemble resolver demotes rejected resolutions out of auto-accept.

## Current state

- `frontend/lib/services/scan/correction_memory_service.dart:78-93` — `recordReject(groupId, userId, rawText)` inserts a `CorrectionsTableCompanion` with `kind: 'reject'`. Never called (grep `recordReject` in `lib/` → only the definition). Note: after Plan 003 it normalises with `normaliseText`. It currently does NOT store which canonical item was rejected — see Step 1.

- `frontend/lib/screens/scanner/scan_review_screen.dart:263-269` — the ignore action only mutates local state:

```dart
  void _removeItem(int index) {
    final item = _items[index];
    setState(() {
      _items.removeAt(index);
      _ignored.add(item);
    });
  }
```

There is also `_restoreIgnored(index)` (lines 270-276) that moves an item back.

- `frontend/lib/services/scan/resolution/ensemble_resolver.dart:48-82` — `resolve()` scores candidates and returns the argmax with `autoThreshold: scorer.tauAuto, reviewThreshold: scorer.tauReview`. It never consults corrections. The scan pipeline consumes the returned score vs thresholds via `ConfidenceService` to pick `autoAccept/review/ask`.

- Corrections table schema: `frontend/lib/storage/app_database.dart:217-235` — columns include `kind`, `raw_text`, `resolved_canonical_item_id` (nullable). `insertCorrection` exists (line 1304). There is **no query for reading rejects** — you will add one.

- Server upload: `frontend/lib/repositories/grocery_repository.dart:249-277` — `uploadCorrection` requires a `canonicalItemId` and guards on `isApiUuid`, so it cannot ship rejects as-is. The backend endpoint accepts `kind: 'reject'` with no canonical id (`backend/internal/services/grocery_service.go:110` only materialises an alias for `kind == "alias"`), so a reject upload is a plain POST.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Focused tests | `cd frontend && flutter test test/services/reject_corrections_test.dart` | all pass |
| Regression | `cd frontend && flutter test test/services/` | all pass |

## Scope

**In scope**:
- `frontend/lib/services/scan/correction_memory_service.dart` (extend `recordReject` signature)
- `frontend/lib/storage/app_database.dart` (one new query)
- `frontend/lib/services/scan/resolution/ensemble_resolver.dart` (consume rejects)
- `frontend/lib/screens/scanner/scan_review_screen.dart` (call sites)
- `frontend/lib/repositories/grocery_repository.dart` (add `uploadReject`)
- `frontend/test/services/reject_corrections_test.dart` (create)

**Out of scope**:
- The legacy (non-ensemble) resolver path in `canonical_resolver_service.dart` — only the ensemble runs in the scan pipeline (`scan_pipeline_service.dart:45` sets `useEnsemble: true`).
- Deleting/aging reject events — append-only log by design.
- Backend changes — the endpoint already accepts rejects (verify with the excerpt above; if it doesn't, STOP).

## Git workflow

- Branch: `advisor/004-wire-reject-corrections`
- Commit style: `feat(scan): record and honor reject corrections`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Record *what* was rejected, not just the text

Extend `recordReject` to accept the rejected resolution so the penalty can be target-specific:

```dart
  Future<void> recordReject({
    required String groupId,
    required String userId,
    required String rawText,
    String? rejectedCanonicalItemId,
  }) async {
    await _db.insertCorrection(CorrectionsTableCompanion.insert(
      id: _uuid.v4(),
      groupId: groupId,
      userId: Value(userId),
      scope: const Value('household'),
      kind: 'reject',
      rawText: Value(normaliseText(rawText)),
      resolvedCanonicalItemId: Value(rejectedCanonicalItemId),
      version: const Value(0),
      createdAt: DateTime.now(),
    ));
  }
```

(`resolved_canonical_item_id` on a reject row = "the canonical item this text must NOT auto-resolve to".)

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Add the read query

In `app_database.dart` next to `insertCorrection` (line 1304), add:

```dart
  /// Reject corrections for [rawText] in this household: rows saying this text
  /// must not auto-resolve (optionally to a specific canonical item).
  Future<List<CorrectionsTableData>> getRejectCorrections({
    required String groupId,
    required String rawText,
  }) {
    return (select(correctionsTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.kind.equals('reject') &
              t.rawText.equals(rawText)))
        .get();
  }
```

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 3: Demote rejected resolutions in `EnsembleResolver.resolve`

After the best candidate is chosen (before constructing the `ResolveResult` at line ~74), fetch rejects for the normalised query and clamp:

```dart
    final rejects =
        await _db.getRejectCorrections(groupId: groupId, rawText: query);
    var p = best.p;
    final rejectedThis = rejects.any((r) =>
        r.resolvedCanonicalItemId == null ||
        r.resolvedCanonicalItemId == best.c.canonicalItemId);
    if (rejectedThis && p >= scorer.tauAuto) {
      // A rejected mapping may still be offered, but never silently
      // auto-accepted again: demote to the review band.
      p = scorer.tauAuto - 0.01;
    }
```

Use `p` for the returned `score`. Semantics: a reject with a stored canonical id demotes only that mapping; a legacy/text-only reject demotes any auto-accept of that text.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 4: Call it from the review screen

In `scan_review_screen.dart`:

- `_removeItem` becomes async-fire-and-forget for the learning write. Only record when there *was* a resolution to reject (`canonicalItemId != null`) — ignoring an unresolved junk line is not a correction signal:

```dart
  void _removeItem(int index) {
    final item = _items[index];
    setState(() {
      _items.removeAt(index);
      _ignored.add(item);
    });
    if (item.canonicalItemId != null) {
      final svc = ref.read(correctionMemoryProvider);
      unawaited(svc.recordReject(
        groupId: widget.groupId,
        userId: widget.userId,
        rawText: item.rawText,
        rejectedCanonicalItemId: item.canonicalItemId,
      ));
      unawaited(_uploadReject(item));
    }
  }
```

- `_restoreIgnored` must NOT try to un-write the reject (append-only log; a restore followed by add-to-list simply produces a stronger, later alias signal via Plan 003's confirmed-edit path). Add a one-line comment saying so.

### Step 5: Server upload

In `grocery_repository.dart`, add alongside `uploadCorrection`:

```dart
  /// Upload a reject correction (kind='reject', no canonical id required).
  /// Fire-and-forget like [uploadCorrection]; offline failures are swallowed —
  /// the local reject row already demotes the mapping on this device.
  Future<int> uploadReject({
    required String groupId,
    required String rawText,
  }) async {
    try {
      final r = await _dio.post(
        '/groups/$groupId/grocery/corrections',
        data: {'raw_text': rawText, 'kind': 'reject', 'scope': 'household'},
      );
      return (r.data['version'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      _log.w('Reject upload failed: ${e.response?.statusCode}');
      return 0;
    } catch (e) {
      _log.w('Reject upload error: $e');
      return 0;
    }
  }
```

In the screen, `_uploadReject(item)` resolves the repo provider (`ref.read(groceryRepositoryProvider.future)`) and calls it. Do NOT send the local canonical id — it is a slug the backend can't store (see `uuid_validation.dart`); the text-only reject is the durable cross-device signal.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 6: Tests

Create `frontend/test/services/reject_corrections_test.dart` (in-memory Drift; model seeding on `frontend/test/services/canonical_resolver_service_test.dart`):

1. Seed an item + alias so `EnsembleResolver.resolve('melk', g)` auto-accepts (score ≥ 0.85 with `CalibratedScorer()` defaults; use an exact alias so `isExactAlias`/`nameSim` push it over — copy the seeding recipe from the existing ensemble tests in `canonical_resolver_service_test.dart:250-280`).
2. `recordReject(rawText: 'melk', rejectedCanonicalItemId: <that item>)`, resolve again → same item may be returned but `score < 0.85` (below `tauAuto`).
3. Reject stored for item A does not demote resolution to item B for the same text (target-specific case).
4. `getRejectCorrections` normalisation round-trip: reject written via `recordReject('Melk  ')` is found for query `'melk'`.

**Verify**: `cd frontend && flutter test test/services/reject_corrections_test.dart` → all pass; `flutter test test/services/` → all pass

## Test plan

Covered in Step 6; the key regression case is (2) — rejected mapping never auto-accepts again.

## Done criteria

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -rn "recordReject" frontend/lib --include="*.dart"` shows ≥1 caller outside the service
- [ ] `grep -n "getRejectCorrections" frontend/lib/services/scan/resolution/ensemble_resolver.dart` shows the consume site
- [ ] New tests pass; `flutter test test/services/` passes
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 003 has not landed (no `userConfirmed` on `GroceryPrediction`, or `recordAlias` still uses `.toLowerCase().trim()`) — dependency violated.
- The demotion in Step 3 makes any existing test in `test/services/` fail on a case that is NOT about rejects — the clamp is leaking; report which test.
- The backend corrections endpoint rejects `kind:'reject'` without a canonical id (check `backend/internal/services/grocery_service.go:105-119` — `InsertCorrection` runs for all kinds; the alias materialisation is gated on `kind == "alias"`). If the POST 500s in manual testing for another reason, that's Plan 001 territory — note it, don't fix it here.

## Maintenance notes

- The per-resolve reject lookup adds one indexed query per scanned line; if Plan 007's batching lands later, fold this lookup into its batch.
- Rejects are append-only and never expire; if households accumulate stale rejects (item renamed, taxonomy changed), a future plan can add recency weighting.
- Reviewer should scrutinize: the demotion clamps *below* `tauAuto`, not to zero — the item stays offered as a review-band suggestion, which is the intended UX.
