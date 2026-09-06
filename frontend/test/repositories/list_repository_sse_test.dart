import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/services/sse_service.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

const _groupId = 'group-1';
const _listId = 'list-001';

Future<void> _insertList(AppDatabase db) async {
  await db.upsertListsRows([
    ListsTableCompanion(
      id: const drift.Value(_listId),
      groupId: const drift.Value(_groupId),
      name: const drift.Value('My List'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
}

ListItem _serverItem(String id, String name, {int position = 0}) => ListItem(
      id: id,
      listId: _listId,
      name: name,
      quantity: 1,
      unit: '',
      checked: false,
      position: position,
      createdAt: DateTime.utc(2026, 1, 5),
      updatedAt: DateTime.utc(2026, 1, 5),
    );

ListItemsTableCompanion _localRow(String id, String name) =>
    ListItemsTableCompanion(
      id: drift.Value(id),
      listId: const drift.Value(_listId),
      name: drift.Value(name),
      quantity: const drift.Value(1.0),
      unit: const drift.Value(''),
      checked: const drift.Value(false),
      position: const drift.Value(0),
      createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
    );

/// The exact shape the backend's `publishDomainEvent` emits for item events:
/// ids only, no item body.
SseEvent _itemEvent(String type, String itemId) => SseEvent(
      type: type,
      groupId: _groupId,
      payload: {'list_id': _listId, 'item_id': itemId},
    );

void main() {
  group('ListRepository SSE —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;
    late StreamController<SseEvent> events;

    setUp(() async {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
      events = StreamController<SseEvent>.broadcast();
      await _insertList(db);
      repo.listenSseForTest(events.stream, _groupId);
    });

    tearDown(() async {
      repo.detachSse();
      await events.close();
      await db.close();
    });

    test('an ids-only item_updated event refetches the list and applies it',
        () async {
      await db.upsertListItemsRows([_localRow('item-a', 'Old name')]);
      remote.itemsToReturn = [
        _serverItem('item-a', 'Renamed by partner'),
        _serverItem('item-b', 'Added by partner', position: 1),
      ];

      events.add(_itemEvent('list:item_updated', 'item-a'));
      await Future<void>.delayed(Duration.zero);
      await repo.flushPendingSseRefreshes();

      final rows = await db.getItemsByListOnce(_listId);
      expect(remote.listItemsCalls, 1);
      expect(
        {for (final r in rows) r.id: r.name},
        {'item-a': 'Renamed by partner', 'item-b': 'Added by partner'},
      );
    });

    test('item_deleted removes the row immediately and reconciles', () async {
      await db.upsertListItemsRows([
        _localRow('item-a', 'Keep'),
        _localRow('item-b', 'Gone'),
      ]);
      remote.itemsToReturn = [_serverItem('item-a', 'Keep')];

      events.add(_itemEvent('list:item_deleted', 'item-b'));
      await Future<void>.delayed(Duration.zero);
      await repo.flushPendingSseRefreshes();

      final rows = await db.getItemsByListOnce(_listId);
      expect(rows.map((r) => r.id), ['item-a']);
    });

    test('a burst of events for one list is coalesced into a single refetch',
        () async {
      remote.itemsToReturn = [_serverItem('item-a', 'A')];

      for (var i = 0; i < 5; i++) {
        events.add(_itemEvent('list:item_created', 'item-$i'));
      }
      await Future<void>.delayed(Duration.zero);
      await repo.flushPendingSseRefreshes();

      expect(remote.listItemsCalls, 1);
    });

    test('events for another group or non-list types are ignored', () async {
      remote.itemsToReturn = [_serverItem('item-a', 'A')];

      events.add(const SseEvent(
        type: 'list:item_updated',
        groupId: 'other-group',
        payload: {'list_id': _listId, 'item_id': 'item-a'},
      ));
      events.add(const SseEvent(
        type: 'chore:completed',
        groupId: _groupId,
        payload: {'list_id': _listId},
      ));
      await Future<void>.delayed(Duration.zero);
      await repo.flushPendingSseRefreshes();

      expect(remote.listItemsCalls, 0);
    });

    test('a refetch keeps the optimistic state of a row with a pending edit',
        () async {
      await db.upsertListItemsRows([_localRow('item-a', 'Old name')]);
      await repo.updateItemOfflineFirst(
        _listId,
        'item-a',
        const UpdateListItemRequest(name: 'My unsynced edit'),
      );
      // The server has not seen the edit yet; the echo of someone else's
      // change must not flash the stale name back in.
      remote.itemsToReturn = [_serverItem('item-a', 'Old name')];

      events.add(_itemEvent('list:item_updated', 'item-a'));
      await Future<void>.delayed(Duration.zero);
      await repo.flushPendingSseRefreshes();

      final rows = await db.getItemsByListOnce(_listId);
      expect(rows.single.name, 'My unsynced edit');
    });
  });

  group('ListRepository drain —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;

    setUp(() async {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
      await _insertList(db);
      await db.upsertListItemsRows([
        _localRow('item-a', 'A'),
        _localRow('item-b', 'B'),
      ]);
    });

    tearDown(() => db.close());

    test('an op queued during an in-flight pass is sent when that pass ends',
        () async {
      await repo.updateItemOfflineFirst(
        _listId,
        'item-a',
        const UpdateListItemRequest(checked: true),
      );
      final gate = Completer<void>();
      remote.updateItemGate = gate;
      final firstDrain = repo.drainOutboxOnce();
      // Let the first pass reach the parked network call.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(remote.updateItemCalls, hasLength(1));

      // A second edit lands while the first is still uploading. With autoSync
      // this is exactly what updateItemOfflineFirst does after enqueueing.
      await repo.updateItemOfflineFirst(
        _listId,
        'item-b',
        const UpdateListItemRequest(checked: true),
      );
      final secondDrain = repo.drainOutboxOnce();

      remote.updateItemGate = null;
      gate.complete();
      await Future.wait([firstDrain, secondDrain]);

      expect(remote.updateItemCalls.map((c) => c.itemId), ['item-a', 'item-b']);
      expect(await db.outboxCount(), 0);
    });
  });
}
