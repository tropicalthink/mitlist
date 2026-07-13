import 'dart:convert';

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

ListItemsTableCompanion _itemRow(
  String listId,
  String id, {
  bool checked = false,
  int position = 0,
}) {
  return ListItemsTableCompanion(
    id: drift.Value(id),
    listId: drift.Value(listId),
    name: drift.Value('Item $id'),
    quantity: const drift.Value(1.0),
    unit: const drift.Value(''),
    checked: drift.Value(checked),
    position: drift.Value(position),
    createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
    updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
  );
}

void main() {
  group('ListRepository outbox —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
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

      await repo.drainOutboxOnce();

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

    test('createItemOfflineFirst rolls back row when outbox enqueue fails',
        () async {
      const listId = 'list-atomic-create';
      await _insertList(db, listId);
      await db.customStatement('''
        CREATE TRIGGER reject_list_create_outbox
        BEFORE INSERT ON outbox_ops
        WHEN NEW.type = 'createItem'
        BEGIN
          SELECT RAISE(ABORT, 'forced outbox failure');
        END;
      ''');

      await expectLater(
        repo.createItemOfflineFirst(
          listId,
          const CreateListItemRequest(name: 'Milk'),
        ),
        throwsA(anything),
      );

      expect(await repo.getItemsByListOnce(listId), isEmpty);
      expect(await db.outboxCount(), 0);
    });

    test(
        'local canonical enrichment patches a deferred create and survives sync',
        () async {
      const listId = 'list-canonical-create';
      await _insertList(db, listId);

      final local = await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Milk'),
        deferImmediateSync: true,
      );
      await repo.setCanonicalItemIdLocal(listId, local.id, 'milk');

      final queued = await db.getOutboxBatch();
      expect(queued, hasLength(1));
      expect(
        (jsonDecode(queued.single.payloadJson) as Map)['canonicalItemId'],
        'milk',
      );

      await repo.drainOutboxOnce();

      final synced = await repo.getItemsByListOnce(listId);
      expect(synced, hasLength(1));
      expect(synced.single.id, '${remote.serverItemIdPrefix}1');
      expect(synced.single.canonicalItemId, 'milk');
    });

    test('renaming an item clears its stale local canonical link', () async {
      const listId = 'list-canonical-rename';
      const itemId = 'item-milk';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const drift.Value(itemId),
          listId: const drift.Value(listId),
          name: const drift.Value('Milk'),
          quantity: const drift.Value(1),
          unit: const drift.Value(''),
          checked: const drift.Value(false),
          position: const drift.Value(0),
          canonicalItemId: const drift.Value('milk'),
          createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
        ),
      ]);

      await repo.updateItemOfflineFirst(
        listId,
        itemId,
        const UpdateListItemRequest(name: 'Oat drink'),
      );

      final renamed = await repo.getItemsByListOnce(listId);
      expect(renamed.single.name, 'Oat drink');
      expect(renamed.single.canonicalItemId, isNull);
    });

    test('server refresh preserves a local canonical enrichment', () async {
      const listId = 'list-canonical-refresh';
      const itemId = 'server-item-1';
      await _insertList(db, listId);
      final now = DateTime.utc(2026, 1, 5);
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const drift.Value(itemId),
          listId: const drift.Value(listId),
          name: const drift.Value('Milk'),
          quantity: const drift.Value(1),
          unit: const drift.Value(''),
          checked: const drift.Value(false),
          position: const drift.Value(0),
          canonicalItemId: const drift.Value('milk'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      ]);
      remote.itemsToReturn = [
        ListItem(
          id: itemId,
          listId: listId,
          name: 'Milk',
          quantity: 1,
          unit: '',
          checked: false,
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await repo.refreshItems(listId);

      final refreshed = await repo.getItemsByListOnce(listId);
      expect(refreshed.single.canonicalItemId, 'milk');
    });

    test('checking a canonical item queues and uploads a purchase event',
        () async {
      const listId = 'list-purchase-learning';
      const itemId = 'item-milk';
      await _insertList(db, listId);
      final now = DateTime.utc(2026, 1, 1);
      await db.upsertCanonicalItems([
        CanonicalItemsTableCompanion.insert(
          id: 'milk',
          groupId: '__global__',
          nameDe: const drift.Value('Milch'),
          nameEn: const drift.Value('Milk'),
          category: const drift.Value('dairy'),
          defaultUnit: const drift.Value('l'),
          isGlobal: const drift.Value(true),
          version: const drift.Value(0),
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const drift.Value(itemId),
          listId: const drift.Value(listId),
          name: const drift.Value('Milk'),
          quantity: const drift.Value(1),
          unit: const drift.Value('l'),
          checked: const drift.Value(false),
          position: const drift.Value(0),
          canonicalItemId: const drift.Value('milk'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      ]);

      await repo.updateItemOfflineFirst(
        listId,
        itemId,
        const UpdateListItemRequest(checked: true),
      );
      for (var i = 0; i < 20; i++) {
        final ops = await db.getOutboxBatch(limit: 10);
        if (ops.any((op) => op.type == 'recordPurchase')) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final localItems = await repo.getItemsByListOnce(listId);
      expect(localItems.single.canonicalItemId, 'milk');
      expect(
          await db.getGroupPurchaseHistory(groupId: 'group-1'), hasLength(1));

      await repo.drainOutboxOnce();

      expect(remote.groceryPurchaseCalls, hasLength(1));
      final event = remote.groceryPurchaseCalls.single.events.single;
      expect(event['canonical_item'], isA<Map>());
      expect((event['canonical_item'] as Map)['name_en'], 'Milk');
      expect(await db.outboxCount(), 0);
    });

    test('bulk check records each canonical pair once', () async {
      const listId = 'list-bulk-learning';
      await _insertList(db, listId);
      final now = DateTime.utc(2026, 1, 1);
      await db.upsertCanonicalItems([
        for (final item in const [
          ('milk', 'Milk'),
          ('cereal', 'Cereal'),
        ])
          CanonicalItemsTableCompanion.insert(
            id: item.$1,
            groupId: '__global__',
            nameDe: drift.Value(item.$2),
            nameEn: drift.Value(item.$2),
            category: const drift.Value('pantry'),
            defaultUnit: const drift.Value('pc'),
            isGlobal: const drift.Value(true),
            version: const drift.Value(0),
            createdAt: now,
            updatedAt: now,
          ),
      ]);
      await db.upsertListItemsRows([
        for (var i = 0; i < 2; i++)
          ListItemsTableCompanion(
            id: drift.Value('item-$i'),
            listId: const drift.Value(listId),
            name: drift.Value(i == 0 ? 'Milk' : 'Cereal'),
            quantity: const drift.Value(1),
            unit: const drift.Value('pc'),
            checked: const drift.Value(false),
            position: drift.Value(i),
            canonicalItemId: drift.Value(i == 0 ? 'milk' : 'cereal'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
      ]);

      await repo.setAllCheckedOfflineFirst(listId, checked: true);

      expect(
          await db.getGroupPurchaseHistory(groupId: 'group-1'), hasLength(2));
      final pairs = await db.getTopCooccurrences(
        groupId: 'group-1',
        itemId: 'milk',
      );
      expect(pairs, hasLength(1));
      expect(pairs.single.count, 1);
    });

    // -------------------------------------------------------------------------
    // Case 2: temp-ID reconciliation — dependent update op
    //
    // Fix: drainOutboxOnce now re-reads each op's payload from the DB before
    // processing it, so _syncUpdateItem sees the server ID (not the temp ID)
    // after _syncCreateItem called rewriteOutboxPayloadIds. Only one row should
    // exist after the drain and it should carry the server ID.
    // -------------------------------------------------------------------------
    test(
        'dependent updateItem op uses fresh DB payload — only server-ID row remains',
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

      // Allow the create to succeed this time.
      remote.throwOnCreateItem = null;

      await repo.drainOutboxOnce();

      // All ops deleted from outbox.
      expect(await db.outboxCount(), equals(0));

      // Fixed: _syncUpdateItem re-reads its payload from the DB and sees the
      // server ID. Exactly one row exists with the server ID; no temp row.
      final itemsAfter = await db.getItemsByListOnce(listId);
      final ids = itemsAfter.map((i) => i.id).toSet();
      expect(ids.contains('${remote.serverItemIdPrefix}1'), isTrue,
          reason: 'server row should exist');
      expect(ids.contains(tempId), isFalse,
          reason: 'temp row must not be re-inserted after fix');
      expect(itemsAfter.length, equals(1),
          reason: 'exactly one row (server ID) should remain after drain');
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
      await repo.drainOutboxOnce();

      // Outbox empty after first successful drain.
      expect(await db.outboxCount(), equals(0));

      // Update the synced item.
      final serverItemId = '${remote.serverItemIdPrefix}1';
      await repo.updateItemOfflineFirst(
        listId,
        serverItemId,
        const UpdateListItemRequest(checked: true),
      );
      await repo.drainOutboxOnce();

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
      await repo.drainOutboxOnce();

      // Local row gone.
      final items = await db.getItemsByListOnce(listId);
      expect(items.where((i) => i.id == itemId), isEmpty);

      // Delete API call recorded.
      expect(remote.deleteItemCalls.contains(itemId), isTrue);

      // Op cleaned up.
      expect(await db.outboxCount(), equals(0));
    });

    test('addItemAmountOfflineFirst rolls back row when enqueue fails',
        () async {
      const listId = 'list-atomic-amount';
      await _insertList(db, listId);
      await db.customStatement('''
        CREATE TRIGGER reject_list_amount_outbox
        BEFORE INSERT ON outbox_ops
        WHEN NEW.type = 'addItemAmount'
        BEGIN
          SELECT RAISE(ABORT, 'forced outbox failure');
        END;
      ''');

      await expectLater(
        repo.addItemAmountOfflineFirst(
          listId,
          name: 'Milk',
          amount: 2,
          unit: 'L',
        ),
        throwsA(anything),
      );

      expect(await repo.getItemsByListOnce(listId), isEmpty);
      expect(await db.outboxCount(), 0);
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

      await repo.drainOutboxOnce();

      expect(result.name, equals('Eggs'));

      // Temp row still present.
      final items = await db.getItemsByListOnce(listId);
      expect(items.length, equals(1));
      expect(items.first.id, equals(result.id)); // still the temp ID

      // Op remains with incremented attempt_count.
      final ops = await db.getOutboxBatch(limit: 10);
      final createOps = ops.where((o) => o.type == 'createItem').toList();
      expect(createOps.length, equals(1));
      expect(createOps.first.attemptCount, equals(1));
      expect(createOps.first.lastError, isNotNull);
      expect(createOps.first.idempotencyKey, startsWith('createItem:'),
          reason: 'idempotency key should be set');
    });

    // -------------------------------------------------------------------------
    // Case 6: reorderItemsOfflineFirst — enqueues, optimistic positions, syncs
    // -------------------------------------------------------------------------
    Future<void> insertItem(String listId, String id, int position) async {
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: drift.Value(id),
          listId: drift.Value(listId),
          name: drift.Value('Item $id'),
          quantity: const drift.Value(1.0),
          unit: const drift.Value(''),
          checked: const drift.Value(false),
          position: drift.Value(position),
          createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
        ),
      ]);
    }

    test(
        'reorderItemsOfflineFirst: optimistic positions, enqueues, syncs on drain',
        () async {
      const listId = 'list-006';
      await _insertList(db, listId);
      await insertItem(listId, 'id1', 0);
      await insertItem(listId, 'id2', 1);
      await insertItem(listId, 'id3', 2);

      await repo.reorderItemsOfflineFirst(listId, ['id3', 'id1', 'id2']);

      // Optimistic local positions updated immediately.
      final after = await db.getItemsByListOnce(listId);
      final byId = {for (final i in after) i.id: i.position};
      expect(byId['id3'], equals(0));
      expect(byId['id1'], equals(1));
      expect(byId['id2'], equals(2));

      // Op enqueued; nothing synced yet (autoSync: false).
      expect(await db.outboxCount(), equals(1));
      expect(remote.reorderItemsCalls, isEmpty);

      await repo.drainOutboxOnce();

      // Synced with correct order; op cleaned up.
      expect(remote.reorderItemsCalls.length, equals(1));
      expect(remote.reorderItemsCalls.first.listId, equals(listId));
      expect(remote.reorderItemsCalls.first.itemIds,
          equals(['id3', 'id1', 'id2']));
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 7: reorder offline — does not throw, positions kept, op stays
    // -------------------------------------------------------------------------
    test(
        'reorderItemsOfflineFirst: API 503 does not throw; op stays attempt_count=1',
        () async {
      const listId = 'list-007';
      await _insertList(db, listId);
      await insertItem(listId, 'a', 0);
      await insertItem(listId, 'b', 1);

      remote.throwOnReorderItems = fakeDioException(statusCode: 503);

      // Must NOT throw even though sync will fail.
      await repo.reorderItemsOfflineFirst(listId, ['b', 'a']);

      // Local positions still updated optimistically.
      final after = await db.getItemsByListOnce(listId);
      final byId = {for (final i in after) i.id: i.position};
      expect(byId['b'], equals(0));
      expect(byId['a'], equals(1));

      await repo.drainOutboxOnce();

      // 503 is transient: op stays with incremented attempt_count.
      final ops = await db.getOutboxBatch(limit: 10);
      final reorderOps = ops.where((o) => o.type == 'reorderItems').toList();
      expect(reorderOps.length, equals(1));
      expect(reorderOps.first.attemptCount, equals(1));
    });

    // -------------------------------------------------------------------------
    // Case 8: addItemAmountOfflineFirst — new item (no local match)
    //
    // The optimistic row appears immediately (no network on the critical path);
    // on drain the additive endpoint is called and the temp ID is swapped for
    // the server ID, mirroring createItem reconciliation.
    // -------------------------------------------------------------------------
    test(
        'addItemAmountOfflineFirst: new item — optimistic row, temp ID swapped',
        () async {
      const listId = 'list-008';
      await _insertList(db, listId);

      final local = await repo.addItemAmountOfflineFirst(
        listId,
        name: 'Milk',
        amount: 2,
        unit: 'L',
      );

      // Optimistic row exists instantly, before any drain.
      final before = await db.getItemsByListOnce(listId);
      expect(before.length, equals(1));
      expect(before.first.id, equals(local.id));
      expect(before.first.quantity, equals(2));
      expect(remote.addItemAmountCalls, isEmpty);

      await repo.drainOutboxOnce();

      // Additive endpoint called with the requested delta.
      expect(remote.addItemAmountCalls.length, equals(1));
      expect(remote.addItemAmountCalls.first.req.name, equals('Milk'));
      expect(remote.addItemAmountCalls.first.req.amount, equals(2));
      expect(remote.addItemAmountCalls.first.req.unit, equals('L'));

      // Temp row replaced by the server-ID row; op cleaned up.
      final after = await db.getItemsByListOnce(listId);
      expect(after.length, equals(1));
      expect(after.first.id, equals('${remote.serverItemIdPrefix}1'));
      expect(after.first.id, isNot(equals(local.id)));
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 9: addItemAmountOfflineFirst — merge into existing local item
    //
    // A matching (name + unit) row has its quantity bumped optimistically; the
    // additive op syncs without clobbering the local quantity or duplicating
    // the row.
    // -------------------------------------------------------------------------
    test(
        'addItemAmountOfflineFirst: merges into matching local row by name+unit',
        () async {
      const listId = 'list-009';
      const existingId = 'item-existing-1';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const drift.Value(existingId),
          listId: const drift.Value(listId),
          name: const drift.Value('Milk'),
          quantity: const drift.Value(1.0),
          unit: const drift.Value('L'),
          checked: const drift.Value(true),
          position: const drift.Value(3),
          createdAt: drift.Value(DateTime.utc(2026, 1, 2)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 2)),
        ),
      ]);

      final local = await repo.addItemAmountOfflineFirst(
        listId,
        name: 'Milk',
        amount: 2,
        unit: 'L',
      );

      // No new row; the existing row is incremented and un-checked.
      expect(local.id, equals(existingId));
      final after = await db.getItemsByListOnce(listId);
      expect(after.length, equals(1));
      expect(after.first.id, equals(existingId));
      expect(after.first.quantity, equals(3.0));
      expect(after.first.checked, isFalse);

      await repo.drainOutboxOnce();

      // Additive endpoint called with only the delta; local quantity preserved
      // (the merge case deliberately does not overwrite from the server).
      expect(remote.addItemAmountCalls.length, equals(1));
      expect(remote.addItemAmountCalls.first.req.amount, equals(2));
      final synced = await db.getItemsByListOnce(listId);
      expect(synced.length, equals(1));
      expect(synced.first.id, equals(existingId));
      expect(synced.first.quantity, equals(3.0));
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 10: clearItemsOfflineFirst(onlyChecked) — optimistic local delete of
    // checked rows + a single clearItems op synced on drain.
    // -------------------------------------------------------------------------
    test(
        'clearItemsOfflineFirst(onlyChecked): removes checked rows locally and syncs one clear op',
        () async {
      const listId = 'list-010';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        _itemRow(listId, 'k1', checked: true, position: 0),
        _itemRow(listId, 'k2', checked: true, position: 1),
        _itemRow(listId, 'open1', checked: false, position: 2),
      ]);

      await repo.clearItemsOfflineFirst(listId, onlyChecked: true);

      // Optimistic: checked rows gone instantly, the open row stays.
      final after = await db.getItemsByListOnce(listId);
      expect(after.map((i) => i.id), equals(['open1']));

      // One clearItems op queued; nothing synced yet (autoSync: false).
      expect(await db.outboxCount(), equals(1));
      expect(remote.clearItemsCalls, isEmpty);

      await repo.drainOutboxOnce();

      // Synced as a single clear(onlyChecked) call; op cleaned up.
      expect(remote.clearItemsCalls.length, equals(1));
      expect(remote.clearItemsCalls.first.onlyChecked, isTrue);
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 11: setAllCheckedOfflineFirst(true) — flips every unchecked row in
    // one local write and queues one updateItem per flipped row.
    // -------------------------------------------------------------------------
    test(
        'setAllCheckedOfflineFirst(true): flips unchecked rows and queues per-item updates',
        () async {
      const listId = 'list-011';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        _itemRow(listId, 'a', checked: false, position: 0),
        _itemRow(listId, 'b', checked: false, position: 1),
        _itemRow(listId, 'c', checked: true, position: 2), // already checked
      ]);

      await repo.setAllCheckedOfflineFirst(listId, checked: true);

      // Optimistic: all rows now checked.
      final after = await db.getItemsByListOnce(listId);
      expect(after.every((i) => i.checked), isTrue);

      // One updateItem op per flipped row (a, b) — c was already checked.
      expect(await db.outboxCount(), equals(2));
      expect(remote.updateItemCalls, isEmpty);

      await repo.drainOutboxOnce();

      expect(remote.updateItemCalls.length, equals(2));
      expect(
          remote.updateItemCalls.every((c) => c.req.checked == true), isTrue);
      expect(remote.updateItemCalls.map((c) => c.itemId).toSet(),
          equals({'a', 'b'}));
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 12: setAllCheckedOfflineFirst(false) — only the checked rows are
    // targeted; already-unchecked rows are left alone (no op).
    // -------------------------------------------------------------------------
    test('setAllCheckedOfflineFirst(false): unchecks only the checked rows',
        () async {
      const listId = 'list-012';
      await _insertList(db, listId);
      await db.upsertListItemsRows([
        _itemRow(listId, 'x', checked: true, position: 0),
        _itemRow(listId, 'y', checked: false, position: 1), // already unchecked
      ]);

      await repo.setAllCheckedOfflineFirst(listId, checked: false);

      final after = await db.getItemsByListOnce(listId);
      expect(after.every((i) => !i.checked), isTrue);
      expect(await db.outboxCount(), equals(1)); // only 'x' was a target

      await repo.drainOutboxOnce();

      expect(remote.updateItemCalls.length, equals(1));
      expect(remote.updateItemCalls.first.itemId, equals('x'));
      expect(remote.updateItemCalls.first.req.checked, isFalse);
      expect(await db.outboxCount(), equals(0));
    });
  });
}
