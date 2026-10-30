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

Future<void> _insertList(AppDatabase db, String listId) {
  return db.upsertListsRows([
    ListsTableCompanion(
      id: drift.Value(listId),
      groupId: const drift.Value('group-1'),
      name: const drift.Value('Groceries'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
}

Future<void> _insertItem(
  AppDatabase db,
  String listId,
  String id,
  String canonicalItemId, {
  bool checked = false,
}) {
  return db.upsertListItemsRows([
    ListItemsTableCompanion(
      id: drift.Value(id),
      listId: drift.Value(listId),
      name: drift.Value(canonicalItemId),
      canonicalItemId: drift.Value(canonicalItemId),
      quantity: const drift.Value(1.0),
      unit: const drift.Value(''),
      checked: drift.Value(checked),
      position: const drift.Value(0),
      createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
    ),
  ]);
}

void main() {
  late AppDatabase db;
  late ListRepository repo;
  const listId = 'list-1';

  setUp(() async {
    db = _memoryDb();
    repo = ListRepository(db: db, remote: FakeListService(), autoSync: false);
    await _insertList(db, listId);
    final now = DateTime.utc(2026, 1, 1);
    await db.upsertCanonicalItems([
      for (final id in ['milk', 'bread', 'eggs'])
        CanonicalItemsTableCompanion.insert(
          id: id,
          groupId: '__global__',
          nameEn: drift.Value(id),
          isGlobal: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> setChecked(String itemId, bool value) =>
      repo.updateItemOfflineFirst(
          listId, itemId, UpdateListItemRequest(checked: value));

  test('check, uncheck, check again is one purchase', () async {
    await _insertItem(db, listId, 'i-milk', 'milk');

    await setChecked('i-milk', true);
    await setChecked('i-milk', false);
    await setChecked('i-milk', true);

    final purchases = await db.select(db.purchaseHistoryTable).get();
    expect(purchases, hasLength(1));
    final ops = (await db.select(db.outboxOps).get())
        .where((op) => op.type == 'recordPurchase');
    expect(ops, hasLength(1));
  });

  test('rows ticked on an earlier trip are not bought together', () async {
    // Checked weeks ago on this reused list; it never produced a purchase on
    // this trip.
    await _insertItem(db, listId, 'i-bread', 'bread', checked: true);
    await _insertItem(db, listId, 'i-milk', 'milk');
    await _insertItem(db, listId, 'i-eggs', 'eggs');

    await setChecked('i-milk', true);
    await setChecked('i-eggs', true);

    final pairs = await db.select(db.itemCooccurrenceTable).get();
    expect(pairs, hasLength(1));
    expect({pairs.single.itemAId, pairs.single.itemBId}, {'milk', 'eggs'});
  });

  test('a check-off from the home screen widget is a purchase', () async {
    await _insertItem(db, listId, 'i-milk', 'milk');

    await repo.applyExternalCheck(listId, 'i-milk');
    // The delivered echo of the same widget op does not count it again.
    await repo.recordExternalPurchase(listId, 'i-milk');

    final purchases = await db.select(db.purchaseHistoryTable).get();
    expect(purchases, hasLength(1));
    expect(purchases.single.canonicalItemId, 'milk');
  });
}
