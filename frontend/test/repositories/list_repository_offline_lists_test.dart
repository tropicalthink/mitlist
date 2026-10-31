import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
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

const _groupId = 'group-1';

DioException _offline(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );

/// [FakeListService] plus the list-level endpoints, recording every call.
class _ListsFake extends FakeListService {
  final List<CreateListRequest> createListCalls = [];
  final List<({String id, UpdateListRequest req})> updateListCalls = [];
  final List<String> deleteListCalls = [];
  final List<String> archiveListCalls = [];
  final List<({String id, DateTime? remindAt})> reminderCalls = [];

  /// The server's lists, returned by [listLists] and [getList].
  final List<ItemList> serverLists = [];

  /// When set, list-level writes fail as if the device were offline.
  bool offline = false;
  int _listCounter = 0;

  @override
  Future<ItemList> createList(CreateListRequest req,
      {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists');
    createListCalls.add(req);
    _listCounter++;
    final list = ItemList(
      id: 'server-list-$_listCounter',
      groupId: req.groupId,
      name: req.name,
      type: req.type,
      itemCount: 0,
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
    );
    serverLists.add(list);
    return list;
  }

  @override
  Future<List<ItemList>> listLists(String groupId,
      {int limit = 50, int offset = 0}) async {
    if (offline) throw _offline('/lists');
    return serverLists.where((l) => l.groupId == groupId).toList();
  }

  @override
  Future<ItemList> updateList(String id, UpdateListRequest req,
      {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists/$id');
    updateListCalls.add((id: id, req: req));
    return serverLists.firstWhere((l) => l.id == id);
  }

  @override
  Future<void> deleteList(String id, {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists/$id');
    deleteListCalls.add(id);
    serverLists.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> archiveList(String id, {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists/$id/archive');
    archiveListCalls.add(id);
  }

  @override
  Future<ItemList> setListReminder(String id, DateTime? remindAt,
      {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists/$id/reminder');
    reminderCalls.add((id: id, remindAt: remindAt));
    return serverLists.firstWhere((l) => l.id == id);
  }

  @override
  Future<ListItem> createItem(String listId, CreateListItemRequest req,
      {String? idempotencyKey}) async {
    if (offline) throw _offline('/lists/$listId/items');
    return super.createItem(listId, req, idempotencyKey: idempotencyKey);
  }
}

Future<void> _insertServerList(
  AppDatabase db,
  _ListsFake remote,
  String id,
  String name,
) async {
  final list = ItemList(
    id: id,
    groupId: _groupId,
    name: name,
    type: 'shopping',
    itemCount: 0,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  remote.serverLists.add(list);
  await db.upsertListsRows([
    ListsTableCompanion(
      id: drift.Value(id),
      groupId: const drift.Value(_groupId),
      name: drift.Value(name),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(list.createdAt),
      updatedAt: drift.Value(list.updatedAt),
    ),
  ]);
}

void main() {
  late AppDatabase db;
  late _ListsFake remote;
  late ListRepository repo;

  setUp(() {
    db = _memoryDb();
    remote = _ListsFake();
    repo = ListRepository(db: db, remote: remote, autoSync: false);
  });

  tearDown(() async {
    repo.dispose();
    await db.close();
  });

  Future<List<String>> listIds() async =>
      (await repo.getListsByGroupOnce(_groupId)).map((l) => l.id).toList();

  test(
      'a list created offline syncs before its items, which land on the '
      'server list', () async {
    remote.offline = true;
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Weekend'),
    );
    expect(ListRepository.isLocalListId(local.id), isTrue);
    expect(await listIds(), [local.id]);

    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Milk'),
    );
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Bread'),
    );
    final milk = (await repo.getItemsByListOnce(local.id))
        .firstWhere((i) => i.name == 'Milk');
    await repo.updateItemOfflineFirst(
      local.id,
      milk.id,
      const UpdateListItemRequest(checked: true),
    );

    // Offline: nothing reaches the server and nothing is lost.
    await repo.drainOutboxOnce();
    expect(remote.createListCalls, isEmpty);
    expect(remote.createItemCalls, isEmpty);
    expect(await db.outboxCount(), 4);

    final changes = <ListIdChange>[];
    final sub = repo.listIdChanges.listen(changes.add);
    addTearDown(sub.cancel);

    remote.offline = false;
    // The offline attempt left the create backing off; the item ops behind
    // it must wait for it instead of going out against the temporary id.
    await repo.drainOutboxOnce();
    expect(remote.createItemCalls, isEmpty);

    await db.resetFailedOutboxOps(maxAttempts: 0);
    await repo.drainOutboxOnce();

    expect(remote.createListCalls.single.name, 'Weekend');
    expect(
        remote.createItemCalls.map((c) => c.listId).toSet(), {'server-list-1'});
    expect(remote.createItemCalls.map((c) => c.req.name), ['Milk', 'Bread']);
    expect(remote.updateItemCalls.single.listId, 'server-list-1');
    expect(remote.updateItemCalls.single.itemId, startsWith('server-item-'));
    expect(await db.outboxCount(), 0);

    // Everything local moved to the server id.
    expect(await listIds(), ['server-list-1']);
    final items = await db.getItemsByListOnce('server-list-1');
    expect(items, hasLength(2));
    expect(items.every((i) => i.id.startsWith('server-item-')), isTrue);
    expect(await db.getItemsByListOnce(local.id), isEmpty);
    final list = await repo.getListOnce('server-list-1');
    expect(list?.itemCount, 2);

    // Screens holding the temporary id follow the switch.
    await Future<void>.delayed(Duration.zero);
    expect(changes.single, (from: local.id, to: 'server-list-1'));
    expect(repo.resolveListId(local.id), 'server-list-1');
    expect((await repo.getItemsByListOnce(local.id)).length, 2);
  });

  test('an item added under the temporary id after the switch is retargeted',
      () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Groceries'),
    );
    await repo.drainOutboxOnce();
    expect(repo.resolveListId(local.id), 'server-list-1');

    // A screen still holding the temporary id.
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Eggs'),
    );
    await repo.drainOutboxOnce();

    expect(remote.createItemCalls.single.listId, 'server-list-1');
    expect((await db.getItemsByListOnce('server-list-1')).single.name, 'Eggs');
  });

  test('a refresh keeps lists (and items) whose create has not synced',
      () async {
    await _insertServerList(db, remote, 'list-a', 'Server list');
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Not synced'),
    );
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Apples'),
    );

    // The server set is complete (fewer than the page limit), so anything
    // missing from it would normally be pruned.
    await repo.refreshLists(_groupId);

    expect((await listIds()).toSet(), {'list-a', local.id});
    expect((await repo.getItemsByListOnce(local.id)).single.name, 'Apples');
  });

  test('a refresh while offline fails and leaves the cache alone', () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Offline'),
    );
    remote.offline = true;
    await expectLater(repo.refreshLists(_groupId), throwsA(isA<Exception>()));
    expect(await listIds(), [local.id]);
  });

  test('renaming a list before it synced renames its queued create', () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Old'),
    );
    await repo.updateListOfflineFirst(
      local.id,
      const UpdateListRequest(name: 'New', type: 'todo'),
    );

    expect((await repo.getListOnce(local.id))?.name, 'New');
    expect(await db.outboxCount(), 1);

    await repo.drainOutboxOnce();
    expect(remote.createListCalls.single.name, 'New');
    expect(remote.createListCalls.single.type, 'todo');
    expect(remote.updateListCalls, isEmpty);
    expect((await repo.getListOnce('server-list-1'))?.name, 'New');
  });

  test('deleting a list before it synced never contacts the server', () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Oops'),
    );
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Milk'),
    );
    await repo.setListReminderOfflineFirst(local.id, DateTime(2030));

    await repo.deleteListOfflineFirst(local.id);

    expect(await listIds(), isEmpty);
    expect(await db.getItemsByListOnce(local.id), isEmpty);
    expect(await db.outboxCount(), 0);
    await repo.drainOutboxOnce();
    expect(remote.createListCalls, isEmpty);
    expect(remote.createItemCalls, isEmpty);
    expect(remote.deleteListCalls, isEmpty);
  });

  test('archiving a list before it synced archives it right after its create',
      () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Party'),
    );
    await repo.archiveListOfflineFirst(local.id);
    expect(await listIds(), isEmpty);

    await repo.drainOutboxOnce();

    expect(remote.createListCalls, hasLength(1));
    expect(remote.archiveListCalls, ['server-list-1']);
    // Not shown again just because the create synced.
    expect(await listIds(), isEmpty);
    expect(await db.outboxCount(), 0);
  });

  test('deleting and renaming a synced list survive a refresh until they sync',
      () async {
    await _insertServerList(db, remote, 'list-a', 'Groceries');
    await _insertServerList(db, remote, 'list-b', 'Hardware');

    await repo.updateListOfflineFirst(
      'list-a',
      const UpdateListRequest(name: 'Food'),
    );
    await repo.deleteListOfflineFirst('list-b');

    // The server has neither change yet.
    await repo.refreshLists(_groupId);
    final lists = await repo.getListsByGroupOnce(_groupId);
    expect(lists.map((l) => (l.id, l.name)), [('list-a', 'Food')]);

    await repo.drainOutboxOnce();
    expect(remote.updateListCalls.single.id, 'list-a');
    expect(remote.updateListCalls.single.req.name, 'Food');
    expect(remote.deleteListCalls, ['list-b']);
    expect(await db.outboxCount(), 0);
  });

  test('consecutive renames sync as one edit', () async {
    await _insertServerList(db, remote, 'list-a', 'One');
    await repo.updateListOfflineFirst(
        'list-a', const UpdateListRequest(name: 'Two'));
    await repo.updateListOfflineFirst(
        'list-a', const UpdateListRequest(name: 'Three'));

    await repo.drainOutboxOnce();
    expect(remote.updateListCalls.single.req.name, 'Three');
  });

  test('a reminder set offline is readable back and syncs to the server id',
      () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Reminded'),
    );
    final at = DateTime(2030, 5, 1, 9);
    await repo.setListReminderOfflineFirst(local.id, DateTime(2030));
    await repo.setListReminderOfflineFirst(local.id, at);

    expect((await repo.queuedListReminder(local.id))?.remindAt, at);

    await repo.drainOutboxOnce();
    expect(remote.reminderCalls.single.id, 'server-list-1');
    expect(remote.reminderCalls.single.remindAt?.toLocal(), at);
    expect(await repo.queuedListReminder('server-list-1'), isNull);
  });

  test('discarding a dead-lettered create removes the list and its ops',
      () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Rejected'),
    );
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Milk'),
    );

    await db.deleteLocalEntity('list', local.id);

    expect(await listIds(), isEmpty);
    expect(await db.getItemsByListOnce(local.id), isEmpty);
    expect(await db.outboxCount(), 0);
  });

  test('item ops behind a dead-lettered create wait instead of failing',
      () async {
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'Stuck'),
    );
    await repo.createItemOfflineFirst(
      local.id,
      const CreateListItemRequest(name: 'Milk'),
    );
    final create = (await db.getOutboxOpsByType('createList')).single;
    await db.markOutboxPermanentFailure(create.id, error: 'rejected');

    await repo.drainOutboxOnce();

    expect(remote.createItemCalls, isEmpty);
    final itemOp = (await db.getOutboxOpsByType('createItem')).single;
    expect(itemOp.attemptCount, 0, reason: 'parking costs no attempt');
    expect(jsonDecode(itemOp.payloadJson)['listId'], local.id);
  });

  test('a queued clear is not undone by a refresh that predates it', () async {
    await _insertServerList(db, remote, 'list-a', 'Groceries');
    final now = DateTime.utc(2026, 1, 1);
    remote.itemsToReturn = [
      ListItem(
        id: 'i1',
        listId: 'list-a',
        name: 'Milk',
        quantity: 1,
        unit: '',
        checked: true,
        position: 0,
        createdAt: now,
        updatedAt: now,
      ),
      ListItem(
        id: 'i2',
        listId: 'list-a',
        name: 'Bread',
        quantity: 1,
        unit: '',
        checked: false,
        position: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await repo.refreshItems('list-a');
    await repo.clearItemsOfflineFirst('list-a', onlyChecked: true);

    await repo.refreshItems('list-a');

    final names =
        (await repo.getItemsByListOnce('list-a')).map((i) => i.name).toList();
    expect(names, ['Bread']);
  });

  test('checking off items across lists queues one edit per item', () async {
    await _insertServerList(db, remote, 'list-a', 'A');
    final local = await repo.createListOfflineFirst(
      const CreateListRequest(groupId: _groupId, name: 'B'),
    );
    final a = await repo.createItemOfflineFirst(
        'list-a', const CreateListItemRequest(name: 'Milk'));
    final b = await repo.createItemOfflineFirst(
        local.id, const CreateListItemRequest(name: 'Eggs'));

    await repo.completeItemsOfflineFirst({
      'list-a': [a.id],
      local.id: [b.id],
    });

    expect((await repo.getItemsByListOnce('list-a')).single.checked, isTrue);
    expect((await repo.getItemsByListOnce(local.id)).single.checked, isTrue);

    await repo.drainOutboxOnce();
    expect(remote.updateItemCalls.map((c) => c.listId).toSet(),
        {'list-a', 'server-list-1'});
  });

  test('products added offline are listed from the outbox until they sync',
      () async {
    remote.offline = true;
    await repo.createProductOfflineFirst(
      const CreateProductRequest(groupId: _groupId, name: 'Oat milk'),
    );
    expect((await repo.queuedProducts(_groupId)).single.name, 'Oat milk');
    expect(await repo.queuedProducts('other-group'), isEmpty);
  });
}
