import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/services/scan/local_item_promotion_service.dart';
import 'package:mitlist/utils/uuid_validation.dart';

import '../support/fakes.dart';

/// Proves the _doPurchaseSignal hook: an item whose name never resolves to a
/// canonical (canonicalItemId == null) learns nothing until the household has
/// checked it off [kLocalPromotionThreshold] times, at which point it is
/// promoted — the list item is backfilled and the normal purchase-history +
/// recordPurchase sync fires.
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

Future<void> _insertItem(AppDatabase db, String listId, String id, String name) {
  return db.upsertListItemsRows([
    ListItemsTableCompanion(
      id: drift.Value(id),
      listId: drift.Value(listId),
      name: drift.Value(name),
      quantity: const drift.Value(1.0),
      unit: const drift.Value(''),
      checked: const drift.Value(false),
      position: const drift.Value(0),
      createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
    ),
  ]);
}

void main() {
  late AppDatabase db;
  late ListRepository repo;

  setUp(() {
    db = _memoryDb();
    repo = ListRepository(db: db, remote: FakeListService(), autoSync: false);
  });

  tearDown(() => db.close());

  test('unresolved item promotes on the threshold check-off, wiring the loop',
      () async {
    const listId = 'list-promote';
    const itemId = 'item-1';
    await _insertList(db, listId);
    // Name that never resolves; canonicalItemId is null.
    await _insertItem(db, listId, itemId, 'Fassi');

    Future<void> setChecked(bool v) => repo.updateItemOfflineFirst(
        listId, itemId, UpdateListItemRequest(checked: v));

    Future<int> recordPurchaseOps() async {
      final ops = await db.select(db.outboxOps).get();
      return ops.where((o) => o.type == 'recordPurchase').length;
    }

    Future<ListItemsTableData> item() async =>
        (await db.getItemsByListOnce(listId))
            .firstWhere((r) => r.id == itemId);

    // Two real check-offs (check → uncheck → check → uncheck). A signal only
    // fires on the false→true transition, so this is 2 unresolved check-offs —
    // below the threshold of 3. Nothing is learned.
    await setChecked(true);
    await setChecked(false);
    await setChecked(true);
    await setChecked(false);

    expect((await item()).canonicalItemId, isNull);
    expect(await db.select(db.purchaseHistoryTable).get(), isEmpty);
    expect(await recordPurchaseOps(), 0);

    // Third check-off crosses the threshold → promote + record.
    await setChecked(true);

    final promoted = await item();
    expect(promoted.canonicalItemId, isNotNull,
        reason: 'the list item is backfilled with the minted canonical');
    expect(apiCanonicalId(promoted.canonicalItemId!), promoted.canonicalItemId,
        reason: 'minted id is a valid API uuid — syncs as-is');
    expect((await db.select(db.purchaseHistoryTable).get()).length, 1,
        reason: 'the purchase signal now records');
    expect(await recordPurchaseOps(), 1,
        reason: 'and enqueues a cross-device recordPurchase op');

    // A minted, household-scoped canonical now exists for the word.
    final canon = (await db.select(db.canonicalItemsTable).get()).single;
    expect(canon.groupId, 'group-1');
    expect(canon.isGlobal, isFalse);
    expect(canon.id, promoted.canonicalItemId);
  });
}
