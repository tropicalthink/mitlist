import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Insert a minimal list row so item upserts have a valid parent.
Future<void> _insertList(AppDatabase db, String listId,
    {String groupId = 'group-1'}) async {
  await db.upsertListsRows([
    ListsTableCompanion(
      id: drift.Value(listId),
      groupId: drift.Value(groupId),
      name: const drift.Value('My List'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
}

void main() {
  group('ListRepository outbox —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote);
    });

    tearDown(() => db.close());

    // -------------------------------------------------------------------------
    // Case 1: createItemOfflineFirst while API succeeds
    // -------------------------------------------------------------------------
    test(
        'createItemOfflineFirst: temp row replaced by server row after successful drain',
        () async {
      const listId = 'list-001';
      await _insertList(db, listId);

      final result = await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Apples', quantity: 2, unit: 'kg'),
      );

      // The returned item carries a temp UUID (not the server ID prefix).
      expect(result.name, equals('Apples'));
      expect(result.quantity, equals(2));

      // After successful drain, exactly one item exists with server ID.
      final items = await db.getItemsByListOnce(listId);
      expect(items.length, equals(1));
      expect(items.first.id, equals('${remote.serverItemIdPrefix}1'),
          reason: 'temp ID should be replaced by server ID after drain');

      // Outbox op deleted after success.
      expect(await db.outboxCount(), equals(0));

      // API called once with correct name.
      expect(remote.createItemCalls.length, equals(1));
      expect(remote.createItemCalls.first.req.name, equals('Apples'));
    });

    // -------------------------------------------------------------------------
    // Case 2: temp-ID reconciliation — dependent update op
    //
    // KNOWN BUG: drainOutboxOnce fetches the batch of ops into memory BEFORE
    // processing them. _syncCreateItem calls rewriteOutboxPayloadIds to update
    // the DB, but the subsequent _syncUpdateItem in the same loop uses the
    // in-memory (stale) payload, which still contains the temp ID. As a result
    // _remote.updateItem is called with the temp ID and the "updated" item is
    // re-inserted with the temp ID, leaving 2 rows: [server-id, temp-id].
    //
    // This test pins CURRENT behavior. A fix should re-read the op from the DB
    // (or re-fetch the batch payload) after each successful op.
    // -------------------------------------------------------------------------
    test(
        'KNOWN BUG: dependent updateItem op uses stale in-memory payload — temp ID re-inserted',
        () async {
      const listId = 'list-002';
      await _insertList(db, listId);

      // Create item offline — make first API call fail so temp row stays.
      remote.throwOnCreateItem = fakeDioException(statusCode: 503);
      final localItem = await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Milk', quantity: 1, unit: 'L'),
      );
      final tempId = localItem.id;

      // Manually enqueue a dependent update op referencing the temp ID.
      await db.enqueueOutbox(
        id: 'update-op-001',
        type: 'updateItem',
        payload: {
          'listId': listId,
          'itemId': tempId, // should be rewritten during sync
          'patch': {'checked': true},
        },
        idempotencyKey: 'updateItem:$tempId:2026',
      );

      // Both ops present before drain.
      expect(await db.outboxCount(), equals(2));

      // Reset backoff so ops are eligible for drain.
      await db.customUpdate(
        'UPDATE outbox_ops SET last_attempt_at = NULL',
        updates: {db.outboxOps},
      );

      await repo.drainOutboxOnce();

      // All ops deleted from outbox.
      expect(await db.outboxCount(), equals(0));

      // KNOWN BUG: because _syncUpdateItem uses the stale in-memory payload
      // (tempId instead of server ID), the update inserts the temp-ID row back.
      // Current behavior: 2 rows exist (server-id + temp-id).
      final itemsAfter = await db.getItemsByListOnce(listId);
      final ids = itemsAfter.map((i) => i.id).toSet();
      expect(ids.contains('${remote.serverItemIdPrefix}1'), isTrue,
          reason: 'server row should exist');
      // KNOWN BUG: temp row is re-inserted by _syncUpdateItem (stale payload).
      expect(ids.contains(tempId), isTrue,
          reason:
              // ignore: lines_longer_than_80_chars
              'KNOWN BUG: temp row is re-inserted because drainOutboxOnce '
              'uses stale in-memory payloads after rewriteOutboxPayloadIds');
      expect(itemsAfter.length, equals(2),
          reason: 'KNOWN BUG: should be 1 after fix; currently 2');
    });

    // -------------------------------------------------------------------------
    // Case 3: full drain/sync sequence — create then update, ops deleted
    // -------------------------------------------------------------------------
    test('full drain: createItem then updateItem synced; all ops deleted',
        () async {
      const listId = 'list-003';
      await _insertList(db, listId);

      // Create item online (API succeeds immediately).
      await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Butter', quantity: 1, unit: 'pack'),
      );

      // Outbox empty after first successful drain.
      expect(await db.outboxCount(), equals(0));

      // Update the synced item.
      final serverItemId = '${remote.serverItemIdPrefix}1';
      await repo.updateItemOfflineFirst(
        listId,
        serverItemId,
        const UpdateListItemRequest(checked: true),
      );

      // updateItem op synced as well.
      expect(await db.outboxCount(), equals(0),
          reason: 'update op should be cleaned up after sync');

      expect(remote.updateItemCalls.length, equals(1));
      expect(remote.updateItemCalls.first.req.checked, isTrue);
    });

    // -------------------------------------------------------------------------
    // Case 4: deleteItemOfflineFirst — local row removed; op synced
    // -------------------------------------------------------------------------
    test(
        'deleteItemOfflineFirst: removes local row and calls API; op cleaned up',
        () async {
      const listId = 'list-004';
      const itemId = 'item-server-99';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const drift.Value(itemId),
          listId: const drift.Value(listId),
          name: const drift.Value('Bread'),
          quantity: const drift.Value(1.0),
          unit: const drift.Value('loaf'),
          checked: const drift.Value(false),
          position: const drift.Value(0),
          createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
        ),
      ]);

      await repo.deleteItemOfflineFirst(listId, itemId);

      // Local row gone.
      final items = await db.getItemsByListOnce(listId);
      expect(items.where((i) => i.id == itemId), isEmpty);

      // Delete API call recorded.
      expect(remote.deleteItemCalls.contains(itemId), isTrue);

      // Op cleaned up.
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 5: createItemOfflineFirst while API throws — op stays with attempt_count=1
    // -------------------------------------------------------------------------
    test(
        'createItemOfflineFirst: when API throws, temp row stays and op has attempt_count=1',
        () async {
      const listId = 'list-005';
      await _insertList(db, listId);

      remote.throwOnCreateItem = fakeDioException(statusCode: 503);
      final result = await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Eggs', quantity: 12, unit: 'pcs'),
      );

      expect(result.name, equals('Eggs'));

      // Temp row still present.
      final items = await db.getItemsByListOnce(listId);
      expect(items.length, equals(1));
      expect(items.first.id, equals(result.id)); // still the temp ID

      // Op remains with incremented attempt_count.
      final ops = await db.getOutboxBatch(limit: 10);
      final createOps =
          ops.where((o) => o.type == 'createItem').toList();
      expect(createOps.length, equals(1));
      expect(createOps.first.attemptCount, equals(1));
      expect(createOps.first.lastError, isNotNull);
      expect(createOps.first.idempotencyKey,
          startsWith('createItem:'),
          reason: 'idempotency key should be set');
    });
  });
}
