import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

/// Regression: the "added by" attribution must survive every local rewrite of
/// a row. A server refresh rebuilt items without a canonical id through a
/// helper that dropped `addedBy`, and a reorder rebuilt every row the same
/// way, so the line under an item flashed for the moment between a server
/// reply and the next refresh and was gone otherwise.
AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

const _listId = 'list-1';
const _sam = 'user-sam';

ListItem _serverItem(String id, String name, {required int position}) =>
    ListItem(
      id: id,
      listId: _listId,
      name: name,
      quantity: 1,
      unit: '',
      checked: false,
      position: position,
      addedBy: _sam,
      createdAt: DateTime.utc(2026, 1, 5),
      updatedAt: DateTime.utc(2026, 1, 5),
    );

void main() {
  late AppDatabase db;
  late FakeListService remote;
  late ListRepository repo;

  setUp(() async {
    db = _memoryDb();
    remote = FakeListService();
    repo = ListRepository(db: db, remote: remote, autoSync: false);
    await db.upsertListsRows([
      ListsTableCompanion(
        id: const drift.Value(_listId),
        groupId: const drift.Value('group-1'),
        name: const drift.Value('Groceries'),
        type: const drift.Value('shopping'),
        createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
        updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
      ),
    ]);
  });

  tearDown(() => db.close());

  test('a server refresh keeps addedBy on items without a canonical id',
      () async {
    remote.itemsToReturn = [
      _serverItem('i1', 'Milk', position: 0),
      _serverItem('i2', 'Eggs', position: 1),
    ];

    await repo.refreshItems(_listId);

    final rows = await repo.getItemsByListOnce(_listId);
    expect(rows.map((r) => r.addedBy), everyElement(_sam));
    expect(rows.map((r) => r.canonicalItemId), everyElement(isNull));
  });

  test('a second refresh does not strip addedBy from cached rows', () async {
    remote.itemsToReturn = [_serverItem('i1', 'Milk', position: 0)];
    await repo.refreshItems(_listId);
    await repo.refreshItems(_listId);

    final rows = await repo.getItemsByListOnce(_listId);
    expect(rows.single.addedBy, _sam);
  });

  test('reordering keeps addedBy on every row', () async {
    remote.itemsToReturn = [
      _serverItem('i1', 'Milk', position: 0),
      _serverItem('i2', 'Eggs', position: 1),
    ];
    await repo.refreshItems(_listId);

    await repo.reorderItemsOfflineFirst(_listId, const ['i2', 'i1']);

    final rows = await repo.getItemsByListOnce(_listId);
    final byId = {for (final r in rows) r.id: r};
    expect(byId['i2']!.position, lessThan(byId['i1']!.position));
    expect(rows.map((r) => r.addedBy), everyElement(_sam));
  });
}
