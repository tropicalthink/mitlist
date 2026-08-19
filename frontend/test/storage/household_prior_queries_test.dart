import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/grocery_seed_test_helper.dart';

void main() {
  late AppDatabase db;
  final anchor = DateTime.utc(2026, 8, 12);

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<void> purchase(
    String id,
    String groupId,
    String? itemId,
    DateTime purchasedAt,
  ) =>
      db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: id,
              groupId: groupId,
              canonicalItemId: drift.Value(itemId),
              purchasedAt: purchasedAt,
            ),
          );

  test('history unions recent rows with a bounded older cadence tail',
      () async {
    final since = anchor.subtract(const Duration(days: 240));
    for (var i = 0; i < 4; i++) {
      await purchase(
        'recent-$i',
        'g1',
        'milk',
        anchor.subtract(Duration(days: i)),
      );
    }
    for (var i = 0; i < 4; i++) {
      await purchase(
        'old-$i',
        'g1',
        'quarterly',
        since.subtract(Duration(days: 30 * (i + 1))),
      );
    }
    await purchase('other-group', 'g2', 'milk', anchor);
    await purchase('null-canonical', 'g1', null, anchor);

    final rows = await db.getGroupPurchaseHistoryForPrior(
      groupId: 'g1',
      since: since,
      recentLimit: 3,
      cadencePerItemLimit: 2,
    );

    expect(rows.map((row) => row.id).toSet(), {
      'recent-0',
      'recent-1',
      'recent-2',
      // recent-0/recent-1 occur in both branches but are deduplicated.
      'old-0',
      'old-1',
    });
    expect(rows.map((row) => row.id), isNot(contains('other-group')));
    expect(rows.map((row) => row.id), isNot(contains('null-canonical')));
    expect(
        rows.map((row) => row.purchasedAt).toList(),
        orderedEquals([...rows.map((row) => row.purchasedAt)]
          ..sort((a, b) => b.compareTo(a))));
  });

  test('lifetime counts are grouped and household isolated', () async {
    await purchase('a1', 'g1', 'a', anchor);
    await purchase('a2', 'g1', 'a', anchor);
    await purchase('b1', 'g1', 'b', anchor);
    await purchase('null', 'g1', null, anchor);
    await purchase('foreign', 'g2', 'a', anchor);

    expect(
      await db.getGroupPurchaseCountsForPrior(groupId: 'g1'),
      {'a': 2, 'b': 1},
    );
  });

  test('cooccurrences use deterministic strongest-first ordering and cap',
      () async {
    Future<void> pair(
      String a,
      String b,
      int count,
      DateTime lastSeen, {
      String groupId = 'g1',
    }) =>
        db.into(db.itemCooccurrenceTable).insert(
              ItemCooccurrenceTableCompanion.insert(
                groupId: groupId,
                itemAId: a,
                itemBId: b,
                count: drift.Value(count),
                lastSeenAt: lastSeen,
              ),
            );

    await pair('z', 'x', 4, anchor);
    await pair('a', 'b', 4, anchor);
    await pair('c', 'd', 4, anchor.subtract(const Duration(days: 1)));
    await pair('top', 'pair', 5, anchor.subtract(const Duration(days: 5)));
    await pair('foreign', 'pair', 99, anchor, groupId: 'g2');

    final rows = await db.getGroupCooccurrences(groupId: 'g1', limit: 3);
    expect(
      rows.map((row) => '${row.itemAId}:${row.itemBId}').toList(),
      ['top:pair', 'a:b', 'z:x'],
    );
  });

  test('cached list type lookup returns the matching type or null', () async {
    await db.into(db.listsTable).insert(
          ListsTableCompanion.insert(
            id: 'shopping-list',
            groupId: 'g1',
            name: 'Groceries',
            type: 'shopping',
            createdAt: anchor,
            updatedAt: anchor,
          ),
        );

    expect(await db.getListType('shopping-list'), 'shopping');
    expect(await db.getListType('missing'), isNull);
  });
}
