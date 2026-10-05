import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

/// Home's "items left" sums the local item cache across lists. A list nobody
/// opened on this device only holds its preview lines there, so Home asks the
/// repository to fetch whatever it has not fetched in full this session.
AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

ListsTableCompanion _list(String id) => ListsTableCompanion(
      id: drift.Value(id),
      groupId: const drift.Value('group-1'),
      name: drift.Value('List $id'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    );

void main() {
  late AppDatabase db;
  late FakeListService remote;
  late ListRepository repo;

  setUp(() async {
    db = _memoryDb();
    remote = FakeListService();
    repo = ListRepository(db: db, remote: remote, autoSync: false);
    await db.upsertListsRows([_list('opened'), _list('never-opened')]);
  });

  tearDown(() => db.close());

  test('fetches only lists not already fetched, once per session', () async {
    await repo.refreshItems('opened');
    expect(remote.listItemsCalls, 1);

    await repo.fetchUnsyncedItems('group-1');
    // 'never-opened' only: 'opened' is already complete.
    expect(remote.listItemsCalls, 2);

    await repo.fetchUnsyncedItems('group-1');
    expect(remote.listItemsCalls, 2);
  });
}
