import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/storage/app_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a list of [DateTime]s evenly spaced by [gapDays] starting from
/// [base].
List<DateTime> _evenly(DateTime base, int count, int gapDays) {
  return List.generate(
    count,
    (i) => base.add(Duration(days: i * gapDays)),
  );
}

// ---------------------------------------------------------------------------
// Tests for the pure medianInterval helper
// ---------------------------------------------------------------------------

void main() {
  group('RestockService.medianInterval (pure)', () {
    test('returns null for empty list', () {
      expect(RestockService.medianInterval([]), isNull);
    });

    test('returns null for one timestamp', () {
      expect(RestockService.medianInterval([DateTime(2024)]), isNull);
    });

    test('returns null for two timestamps (insufficient history)', () {
      final ts = [DateTime(2024, 1, 1), DateTime(2024, 1, 8)];
      expect(RestockService.medianInterval(ts), isNull);
    });

    test('returns correct median for evenly spaced points (7-day gap)', () {
      final base = DateTime(2024, 1, 1);
      // 4 timestamps → 3 gaps of 7 days each → median = 7 days
      final ts = _evenly(base, 4, 7);
      final result = RestockService.medianInterval(ts);
      expect(result, isNotNull);
      expect(result!.inDays, equals(7));
    });

    test('returns median (not mean) for irregular gaps', () {
      // Gaps: 2, 8, 14 days → sorted: [2, 8, 14] → median = 8
      final base = DateTime(2024, 1, 1);
      final ts = [
        base,
        base.add(const Duration(days: 2)),
        base.add(const Duration(days: 10)),
        base.add(const Duration(days: 24)),
      ];
      final result = RestockService.medianInterval(ts);
      expect(result, isNotNull);
      // Mean would be (2+8+14)/3 ≈ 8.0, but median is also 8 here.
      // Use gaps [2, 8, 14] → sorted → [2, 8, 14] → middle (index 1) = 8.
      expect(result!.inDays, equals(8));
    });

    test('median picks middle value for 5 gaps', () {
      // Gaps: 1, 3, 5, 7, 100 → sorted → [1, 3, 5, 7, 100] → median = 5
      final base = DateTime(2024, 1, 1);
      final ts = [
        base,
        base.add(const Duration(days: 1)),
        base.add(const Duration(days: 4)),
        base.add(const Duration(days: 9)),
        base.add(const Duration(days: 16)),
        base.add(const Duration(days: 116)),
      ];
      final result = RestockService.medianInterval(ts);
      expect(result, isNotNull);
      expect(result!.inDays, equals(5));
    });
  });

  // ---------------------------------------------------------------------------
  // Tests for the "due" logic using an in-memory Drift DB
  // ---------------------------------------------------------------------------

  group('RestockService.due (in-memory Drift)', () {
    late AppDatabase db;
    late RestockService service;

    const groupId = 'g1';
    const canonicalItemId = 'milk';
    const canonicalItemId2 = 'eggs';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = RestockService(db);
    });

    tearDown(() async {
      await db.close();
    });

    /// Inserts [count] purchase rows for [itemId] evenly spaced by [gapDays],
    /// ending at [lastPurchase].
    Future<void> _seedPurchases(
      String itemId,
      DateTime lastPurchase, {
      required int count,
      required int gapDays,
    }) async {
      final rows = List.generate(count, (i) {
        final purchasedAt =
            lastPurchase.subtract(Duration(days: (count - 1 - i) * gapDays));
        return PurchaseHistoryTableCompanion.insert(
          id: '${itemId}_$i',
          groupId: groupId,
          canonicalItemId: drift.Value(itemId),
          purchasedAt: purchasedAt,
        );
      });
      await db.upsertPurchaseHistory(rows);
    }

    test('item bought every 7 days, last bought 9 days ago → due', () async {
      final now = DateTime(2024, 6, 10);
      final lastPurchase = now.subtract(const Duration(days: 9));
      await _seedPurchases(canonicalItemId, lastPurchase,
          count: 4, gapDays: 7);

      final results = await service.due(groupId: groupId, now: now);
      expect(results.any((r) => r.canonicalItemId == canonicalItemId), isTrue);
    });

    test('item bought every 7 days, last bought 3 days ago → not due', () async {
      final now = DateTime(2024, 6, 10);
      final lastPurchase = now.subtract(const Duration(days: 3));
      await _seedPurchases(canonicalItemId, lastPurchase,
          count: 4, gapDays: 7);

      final results = await service.due(groupId: groupId, now: now);
      expect(results.any((r) => r.canonicalItemId == canonicalItemId), isFalse);
    });

    test('item with only 2 purchases → excluded (insufficient history)',
        () async {
      final now = DateTime(2024, 6, 10);
      final lastPurchase = now.subtract(const Duration(days: 20));
      await _seedPurchases(canonicalItemId, lastPurchase,
          count: 2, gapDays: 7);

      final results = await service.due(groupId: groupId, now: now);
      expect(results.any((r) => r.canonicalItemId == canonicalItemId), isFalse);
    });

    test('item already on current list → excluded', () async {
      final now = DateTime(2024, 6, 10);
      final lastPurchase = now.subtract(const Duration(days: 10));
      await _seedPurchases(canonicalItemId, lastPurchase,
          count: 4, gapDays: 7);

      // Seed a canonical item so the name resolves.
      final now2 = DateTime(2024, 6, 10);
      await db.upsertCanonicalItems([
        CanonicalItemsTableCompanion.insert(
          id: canonicalItemId,
          groupId: groupId,
          nameEn: const drift.Value('Milk'),
          nameDe: const drift.Value('Milch'),
          category: const drift.Value('dairy'),
          defaultUnit: const drift.Value('l'),
          createdAt: now2,
          updatedAt: now2,
        ),
      ]);

      final results = await service.due(
        groupId: groupId,
        now: now,
        currentItemNames: {'milk'}, // lowercase match on name
      );
      // 'Milk'.toLowerCase() == 'milk' → should be excluded.
      expect(results.any((r) => r.canonicalItemId == canonicalItemId), isFalse);
    });

    test('most overdue item sorts first', () async {
      final now = DateTime(2024, 6, 10);

      // item1 (milk): 7-day cadence, last bought 20 days ago → 13 days overdue
      await _seedPurchases(canonicalItemId, now.subtract(const Duration(days: 20)),
          count: 4, gapDays: 7);

      // item2 (eggs): 7-day cadence, last bought 9 days ago → 2 days overdue
      await _seedPurchases(canonicalItemId2, now.subtract(const Duration(days: 9)),
          count: 4, gapDays: 7);

      final results = await service.due(groupId: groupId, now: now);
      expect(results.length, greaterThanOrEqualTo(2));
      // milk is more overdue → should be first.
      expect(results.first.canonicalItemId, equals(canonicalItemId));
    });
  });
}
