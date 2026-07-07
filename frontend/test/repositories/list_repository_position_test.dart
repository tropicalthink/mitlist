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
  group('ListRepository._restorePendingLocalItems position —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
    });

    tearDown(() => db.close());

    test(
        'restored pending item appends after server items and has no duplicate positions',
        () async {
      const listId = 'list-pos-001';
      await _insertList(db, listId);

      // Create a pending offline item via the public offline-first path.
      // autoSync: false means it stays in the outbox — no real network call.
      await repo.createItemOfflineFirst(
        listId,
        const CreateListItemRequest(name: 'Pending Milk', quantity: 2.0),
      );

      // Confirm the outbox has exactly one pending createItem op before refresh.
      final outboxBefore = await db.getOutboxBatchByTypes(
        ['createItem'],
        limit: 10,
        minBackoff: Duration.zero,
      );
      expect(outboxBefore, hasLength(1),
          reason: 'precondition: one pending op in outbox');

      // Arrange: the next server response returns two items that do NOT include
      // the pending temp item (simulates "still pending, server not synced yet").
      final now = DateTime.utc(2026, 1, 2);
      remote.itemsToReturn = [
        ListItem(
          id: 'server-item-1',
          listId: listId,
          name: 'Eggs',
          quantity: 12.0,
          unit: '',
          checked: false,
          position: 0,
          createdAt: now,
          updatedAt: now,
        ),
        ListItem(
          id: 'server-item-2',
          listId: listId,
          name: 'Bread',
          quantity: 1.0,
          unit: 'loaf',
          checked: false,
          position: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Drive a refresh — this wipes local items, re-inserts server items,
      // then calls _restorePendingLocalItems.
      await repo.refreshItems(listId);

      // Assert final state of the local DB.
      final rows = await db.getItemsByListOnce(listId);
      expect(rows, hasLength(3),
          reason: 'two server items + one restored pending item');

      final byId = {for (final r in rows) r.id: r};

      // Server items keep their original positions.
      expect(byId['server-item-1']?.position, equals(0),
          reason: 'server-item-1 stays at position 0');
      expect(byId['server-item-2']?.position, equals(1),
          reason: 'server-item-2 stays at position 1');

      // The pending item must be appended after the server items (position 2 =
      // maxPos + 1), never at position 0.
      final pendingRow = rows.firstWhere(
        (r) => r.id != 'server-item-1' && r.id != 'server-item-2',
      );
      expect(pendingRow.position, equals(2),
          reason:
              'restored pending item must have position maxPos+1 = 2, not 0');
      expect(pendingRow.name, equals('Pending Milk'));

      // No two items share the same position.
      final positions = rows.map((r) => r.position).toList();
      final uniquePositions = positions.toSet();
      expect(uniquePositions.length, equals(positions.length),
          reason: 'no duplicate positions after restore');
    });
  });
}
