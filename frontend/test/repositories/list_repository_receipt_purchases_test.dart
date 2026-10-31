import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/services/scan/receipt_purchase_matcher.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

ReceiptPurchase _bought(String id, {double quantity = 1}) =>
    ReceiptPurchase(canonicalItemId: id, name: id, quantity: quantity);

void main() {
  late AppDatabase db;
  late ListRepository repo;
  const groupId = 'group-1';
  final shopped = DateTime(2026, 10, 30, 12);

  setUp(() async {
    db = _memoryDb();
    repo = ListRepository(db: db, remote: FakeListService(), autoSync: false);
    final now = DateTime.utc(2026, 1, 1);
    await db.upsertCanonicalItems([
      for (final id in ['milk', 'bread', 'eggs', 'grape_juice'])
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

  test('records each item once, bought together, in one sync op', () async {
    final recorded = await repo.recordReceiptPurchases(
      groupId: groupId,
      purchases: [
        _bought('milk'),
        _bought('bread'),
        _bought('grape_juice', quantity: 3),
      ],
      purchasedAt: shopped,
    );
    expect(recorded, 3);

    final rows = await db.select(db.purchaseHistoryTable).get();
    expect({for (final r in rows) r.canonicalItemId: r.quantity},
        {'milk': 1, 'bread': 1, 'grape_juice': 3});
    expect(rows.every((r) => r.purchasedAt == shopped), isTrue);
    expect(rows.every((r) => r.listItemId == null), isTrue);

    // Three items bought together are three pairs, each counted once.
    final pairs = await db.getGroupCooccurrences(groupId: groupId);
    expect(pairs, hasLength(3));
    expect(pairs.every((p) => p.count == 1), isTrue);

    final ops = await db.getOutboxOpsByType('recordPurchase');
    expect(ops, hasLength(1));
    final events = (jsonDecode(ops.single.payloadJson)
        as Map<String, dynamic>)['events'] as List;
    expect([for (final e in events) (e['peers'] as List).length], [0, 1, 2]);
  });

  test('an item checked off on the same trip is not counted again', () async {
    await db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
      id: 'checked-off',
      groupId: groupId,
      canonicalItemId: const drift.Value('milk'),
      purchasedAt: shopped.subtract(const Duration(hours: 1)),
    ));

    final recorded = await repo.recordReceiptPurchases(
      groupId: groupId,
      purchases: [_bought('milk'), _bought('eggs')],
      purchasedAt: shopped,
    );

    expect(recorded, 1);
    final eggs = (await db.select(db.purchaseHistoryTable).get())
        .where((r) => r.canonicalItemId == 'eggs');
    expect(eggs, hasLength(1));
    // The milk from the list is still what the eggs were bought with.
    final events = (jsonDecode(
            (await db.getOutboxOpsByType('recordPurchase')).single.payloadJson)
        as Map<String, dynamic>)['events'] as List;
    expect((events.single['peers'] as List).single['id'], isNotNull);
  });

  test('scanning the same receipt twice records it once', () async {
    final purchases = [_bought('milk'), _bought('bread')];
    expect(
      await repo.recordReceiptPurchases(
          groupId: groupId, purchases: purchases, purchasedAt: shopped),
      2,
    );
    expect(
      await repo.recordReceiptPurchases(
          groupId: groupId, purchases: purchases, purchasedAt: shopped),
      0,
    );
    expect(await db.select(db.purchaseHistoryTable).get(), hasLength(2));
    expect(await db.getOutboxOpsByType('recordPurchase'), hasLength(1));
  });

  test('last week\'s purchase does not hide today\'s', () async {
    await db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
      id: 'last-week',
      groupId: groupId,
      canonicalItemId: const drift.Value('milk'),
      purchasedAt: shopped.subtract(const Duration(days: 7)),
    ));
    expect(
      await repo.recordReceiptPurchases(
          groupId: groupId, purchases: [_bought('milk')], purchasedAt: shopped),
      1,
    );
  });
}
