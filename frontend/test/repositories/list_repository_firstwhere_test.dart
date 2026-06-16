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

Future<void> _insertItem(AppDatabase db, String listId, String itemId) async {
  await db.upsertListItemsRows([
    ListItemsTableCompanion(
      id: drift.Value(itemId),
      listId: drift.Value(listId),
      name: const drift.Value('Bread'),
      quantity: const drift.Value(1.0),
      unit: const drift.Value('loaf'),
      checked: const drift.Value(false),
      position: const drift.Value(0),
      createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
    ),
  ]);
}

void main() {
  group('ListRepository.updateItemOfflineFirst firstWhere guard —', () {
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
    });

    tearDown(() => db.close());

    test('patches and returns the item when it exists in the local cache',
        () async {
      const listId = 'list-fw-001';
      const itemId = 'item-fw-001';
      await _insertList(db, listId);
      await _insertItem(db, listId, itemId);

      final result = await repo.updateItemOfflineFirst(
        listId,
        itemId,
        const UpdateListItemRequest(checked: true, name: 'Sourdough'),
      );

      expect(result.id, equals(itemId));
      expect(result.checked, isTrue);
      expect(result.name, equals('Sourdough'));

      // Optimistic patch persisted to the local cache.
      final items = await db.getItemsByListOnce(listId);
      expect(items.single.checked, isTrue);
      expect(items.single.name, equals('Sourdough'));
    });

    test(
        'throws a catchable StateError (no uncaught crash) when the item is '
        'absent from the local cache', () async {
      const listId = 'list-fw-002';
      await _insertList(db, listId);
      // Deliberately do not insert the item.

      // The guard converts the missing row into a clear, catchable StateError
      // rather than the implicit StateError firstWhere would throw. Callers
      // wrap this call in try/catch and surface a localized SnackBar.
      expect(
        () => repo.updateItemOfflineFirst(
          listId,
          'missing-item',
          const UpdateListItemRequest(checked: true),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
