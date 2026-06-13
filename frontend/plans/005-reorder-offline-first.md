# Plan 005: Make `reorderItemsOfflineFirst` actually offline (route through the outbox)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command. Honor STOP conditions. Update `plans/README.md` when
> done.
>
> **Drift check (run first, from `frontend/`)**:
> `git diff --stat 6c868661..HEAD -- lib/repositories/list_repository.dart lib/repositories/outbox_drainer.dart`
> This plan assumes plan 002 has landed (`lib/repositories/outbox_drainer.dart`
> exists and `ListRepository.drainOutboxOnce` registers a handler map). If 002
> is not done, see "If 002 is not done yet" at the end of Steps.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: `plans/002-shared-outbox-drainer.md` (registers the new handler); compatible with `plans/001`
- **Category**: bug
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

`ListRepository.reorderItemsOfflineFirst` (`lib/repositories/list_repository.dart:176-218`)
is named "offline-first" but is not: after applying the new positions locally it
calls `_remote.reorderItems(...)` **directly**, and on failure runs
`await refreshItems(listId)` (which reloads from the server, discarding the
local reorder) then `rethrow`s. So reordering while offline either throws or is
immediately reverted — and the caller
(`lib/screens/lists/list_detail_screen.dart:991-998` `_persistReorder`) shows
"Couldn't reorder items. Please try again." That's the one list mutation that
breaks offline, inconsistent with create/update/delete which all queue.

This routes reorder through the same outbox so it persists locally and syncs on
reconnect like every other list write.

## Current state

`lib/repositories/list_repository.dart:176-218`:
```dart
Future<void> reorderItemsOfflineFirst(
  String listId,
  List<String> itemIdsInOrder,
) async {
  final existingRows = await _db.getItemsByListOnce(listId);
  final byId = {for (final row in existingRows) row.id: _toListItem(row)};
  final patched = <ListItemsTableCompanion>[];
  for (var i = 0; i < itemIdsInOrder.length; i++) {
    final existing = byId[itemIdsInOrder[i]];
    if (existing == null) continue;
    patched.add(_toListItemsRow(ListItem(/* ...same fields..., position: i, updatedAt: DateTime.now() */)));
  }
  await _db.upsertListItemsRows(patched);

  try {
    await _remote.reorderItems(listId, ReorderItemsRequest(itemIds: itemIdsInOrder));
  } catch (e) {
    await refreshItems(listId);   // <-- reverts the local reorder
    rethrow;                       // <-- surfaces an error to the UI even offline
  }
}
```

Supporting facts:
- `ListService.reorderItems(String listId, ReorderItemsRequest req)` exists
  (`lib/services/list_service.dart:215`).
- The outbox pattern (this file): `enqueueOutbox({id, type, payload, idempotencyKey})`,
  then `unawaited(drainOutboxOnce())` (after plan 001) for immediate
  best-effort sync. Op types for this repo currently: `createItem`,
  `updateItem`, `deleteItem`.
- After plan 002, `drainOutboxOnce()` registers handlers in a map and passes a
  `types` list to `OutboxDrainer.drain`. You will add `reorderItems` to both.
- Temp-ID safety: `_syncCreateItem` calls
  `rewriteOutboxPayloadIds(oldId: tempId, newId: created.id)`, a global
  `replace` across **all** queued payloads' JSON — so a `reorderItems` op that
  references a not-yet-synced temp item ID gets its IDs rewritten automatically
  when the create syncs. No special handling needed; just be aware.

## Commands you will need

| Purpose   | Command (from `frontend/`)                          | Expected |
|-----------|------------------------------------------------------|----------|
| Analyze   | `dart analyze lib/`                                 | `2 issues found.` (pre-existing); no new issues |
| Tests     | `flutter test test/repositories/list_repository_outbox_test.dart` | all pass |
| Full      | `flutter test`                                      | all pass |

## Scope

**In scope**:
- `lib/repositories/list_repository.dart`
- `test/repositories/list_repository_outbox_test.dart` (add reorder cases)

**Out of scope** (do NOT touch):
- `lib/screens/lists/list_detail_screen.dart` — `_persistReorder` already
  `await`s the repo method and catches errors; once reorder no longer throws
  offline, the spurious snackbar simply stops. No screen change needed. If you
  think it needs changing, STOP and report.
- `lib/services/list_service.dart` — the remote call is unchanged.
- The drainer's failure semantics (plans 002/003 own those).

## Git workflow

- Branch: `advisor/005-reorder-offline-first`.
- Conventional Commits, e.g. `fix: route list reorder through the outbox`.

## Steps

### Step 1: Make `reorderItemsOfflineFirst` enqueue instead of calling remote directly

Keep the optimistic local position update (the `patched` loop +
`upsertListItemsRows`). Replace the `try/catch` remote call with an outbox
enqueue + fire-and-forget drain:

```dart
await _db.upsertListItemsRows(patched);

await _db.enqueueOutbox(
  id: _uuid.v4(),
  type: 'reorderItems',
  payload: {
    'listId': listId,
    'itemIds': itemIdsInOrder,
  },
  idempotencyKey:
      'reorderItems:$listId:${DateTime.now().toIso8601String()}',
);

unawaited(drainOutboxOnce());
```

(`unawaited` is already imported in this file. If plan 001 has NOT landed, use
`await drainOutboxOnce();` to match the file's other methods — but prefer
`unawaited` per plan 001.)

Remove the now-unused `byId`/`existingRows` only if they become unused — they
are still used to build `patched`, so keep them.

### Step 2: Register the `reorderItems` handler in the drain

In `drainOutboxOnce()` (post-002 handler-map form), add `reorderItems` to the
`types` list and a handler:

```dart
types: const ['createItem', 'updateItem', 'deleteItem', 'reorderItems'],
handlers: {
  // ...existing...
  'reorderItems': (op, payload) => _syncReorderItems(op.id, payload),
},
```

Add the handler method, mirroring the other `_sync*` methods (validate, call
remote, delete op on success):

```dart
Future<void> _syncReorderItems(
    String opId, Map<String, dynamic> payload) async {
  final listId = payload['listId'] as String?;
  final rawIds = payload['itemIds'];
  if (listId == null || rawIds is! List) {
    await _db.deleteOutboxOp(opId);
    return;
  }
  final itemIds = rawIds.map((e) => e.toString()).toList();
  await _remote.reorderItems(listId, ReorderItemsRequest(itemIds: itemIds));
  await _db.deleteOutboxOp(opId);
}
```

`ReorderItemsRequest` is already imported (used by the old code). On failure the
handler throws and the shared drainer handles it (transient → retry, permanent
→ dead-letter, per plan 003).

**Verify**: `dart analyze lib/` → `2 issues found.`, no new issues.

### Step 3: Tests

Add to `test/repositories/list_repository_outbox_test.dart`, following the file's
existing structure (in-memory DB, `FakeListService`, `_insertList` helper):

1. **Enqueues and syncs**: insert a list + a few items with known IDs; call
   `repo.reorderItemsOfflineFirst(listId, [id3, id1, id2])`; assert local
   `position` values updated optimistically (item id3 → 0, id1 → 1, id2 → 2);
   then `await repo.drainOutboxOnce();` and assert the `FakeListService`
   recorded a `reorderItems` call with the right order and the outbox is empty
   (`outboxCount() == 0`). You may need to extend `FakeListService` to record
   `reorderItems` calls — add a `List<ReorderItemsCall>` recorder mirroring the
   other recorders in `test/support/fakes.dart` (e.g. `createItemCalls`). Keep
   the fake's `noSuchMethod` fallback for anything unrecorded.
2. **Offline persists (no throw, op stays)**: make the fake's `reorderItems`
   throw `fakeDioException(statusCode: 503)`; call
   `reorderItemsOfflineFirst`; assert it **does not throw**, the local
   positions are still updated, and the outbox still has the `reorderItems` op
   (`attemptCount == 1` after the inline drain attempt). This is the
   regression-prevention test for the original bug (offline reorder used to
   throw + revert).

**Verify**:
`flutter test test/repositories/list_repository_outbox_test.dart` → all pass.

### Step 4: Full suite

**Verify**: `flutter test` → all pass.

## If 002 is not done yet

If you must do this before plan 002, the drain loop in `ListRepository` is still
the hand-rolled `switch`. Then: add a `case 'reorderItems': await
_syncReorderItems(op.id, payload); break;` to that switch, add `'reorderItems'`
to the `getOutboxBatchByTypes([...])` list, and add `_syncReorderItems` as in
Step 2. Everything else is identical. Note this in your status update so plan
002 folds it into the handler map.

## Test plan

- Extend `test/repositories/list_repository_outbox_test.dart` with the two cases
  in Step 3, modeled on the existing create/update cases in the same file.
- Extend `FakeListService` in `test/support/fakes.dart` to record/throw on
  `reorderItems` (mirror `createItemCalls` / `throwOnCreateItem`).
- Verification: `flutter test` → all pass; 2 new reorder tests.

## Done criteria

ALL must hold:

- [ ] `reorderItemsOfflineFirst` enqueues a `reorderItems` outbox op and does NOT call `_remote.reorderItems` directly (`grep -n "_remote.reorderItems" lib/repositories/list_repository.dart` appears only inside `_syncReorderItems`).
- [ ] `reorderItemsOfflineFirst` no longer calls `refreshItems` or `rethrow`s on the reorder path (`grep -n "rethrow" lib/repositories/list_repository.dart` — the reorder method no longer contains it).
- [ ] `reorderItems` is in the drained `types` list and has a handler.
- [ ] `dart analyze lib/` → `2 issues found.`, no new issues.
- [ ] `flutter test` exits 0; 2 new reorder tests pass, including the offline "does not throw, op retained" case.
- [ ] No files outside the in-scope list + `test/support/fakes.dart` modified (`git status`).
- [ ] `plans/README.md` status row for 005 updated.

## STOP conditions

Stop and report (do not improvise) if:
- `list_detail_screen.dart` appears to depend on `reorderItemsOfflineFirst`
  throwing on failure (it currently catches and shows a snackbar; with the
  change it won't throw offline — that's the intended improvement, not a
  regression).
- `ReorderItemsRequest`'s constructor signature differs from
  `ReorderItemsRequest(itemIds: ...)` as used in the current code.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Reorder ops are not deduplicated: rapid reorders enqueue multiple ops,
  processed in order (last wins on the server). If reorder volume becomes a
  problem, collapse consecutive `reorderItems` ops for the same `listId` at
  enqueue time — deferred as premature for now.
- A reorder queued before its items finish creating relies on
  `rewriteOutboxPayloadIds` rewriting temp IDs in the reorder payload; if that
  mechanism changes, re-check reorder-with-temp-IDs.
