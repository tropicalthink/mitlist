import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/resolution/ensemble_resolver.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/grocery_seed_test_helper.dart';

void main() {
  test('resolution reads the shared household prior', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final now = DateTime(2026, 3, 10);
    final rows = [
      for (var i = 0; i < 4; i++)
        PurchaseHistoryTableCompanion.insert(
          id: 'milk-$i',
          groupId: 'g1',
          canonicalItemId: const drift.Value('milk'),
          purchasedAt: now.subtract(Duration(days: 2 + 7 * i)),
        ),
      PurchaseHistoryTableCompanion.insert(
        id: 'bread-0',
        groupId: 'g1',
        canonicalItemId: const drift.Value('bread'),
        purchasedAt: now.subtract(const Duration(days: 30)),
      ),
    ];
    await db.upsertPurchaseHistory(rows);
    await db.upsertCooccurrence([
      ItemCooccurrenceTableCompanion.insert(
        groupId: 'g1',
        itemAId: 'bread',
        itemBId: 'milk',
        count: const drift.Value(3),
        lastSeenAt: now,
      ),
    ]);

    final resolver = EnsembleResolver(
      db,
      prior: HouseholdPriorService(db, clock: () => now),
    );
    final context = await resolver.buildContext('g1', const ['bread']);

    expect(context.purchaseCounts, {'milk': 4, 'bread': 1});
    expect(context.daysSinceLastPurchase['milk'], 2);
    expect(context.cooccurrence['milk'], greaterThan(0));
    expect(context.cooccurrence.containsKey('bread'), isFalse);
  });
}
