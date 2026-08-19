import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/repositories/grocery_repository.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/utils/uuid_validation.dart';

AppDatabase _db() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  test('apiCanonicalId maps local slugs to stable UUIDs', () {
    final milk = apiCanonicalId('milk');

    expect(isApiUuid(milk), isTrue);
    expect(apiCanonicalId('milk'), equals(milk));
    expect(apiCanonicalId('oat_milk'), isNot(equals(milk)));
  });

  test('apiCanonicalId passes API UUIDs through unchanged', () {
    const id = '550e8400-e29b-41d4-a716-446655440000';

    expect(apiCanonicalId(id), equals(id));
  });

  test('canonical category lookup omits unknown and empty categories',
      () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime(2026, 1, 1);
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: 'milk',
        groupId: '__global__',
        nameDe: const Value('Milch'),
        nameEn: const Value('milk'),
        category: const Value('dairy'),
        createdAt: now,
        updatedAt: now,
      ),
      CanonicalItemsTableCompanion.insert(
        id: 'mystery',
        groupId: 'group-1',
        nameEn: const Value('mystery'),
        category: const Value(''),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final repo = GroceryRepository(db: db, dio: Dio());
    final categories =
        await repo.getCanonicalCategories(['milk', 'mystery', 'missing']);

    expect(categories, {'milk': 'dairy'});
  });

  test('applyDelta maps server canonical UUIDs back to local slugs', () async {
    final db = _db();
    addTearDown(db.close);

    final now = DateTime(2024, 1, 1);
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: 'milk',
        groupId: '__global__',
        nameDe: const Value('Milch'),
        nameEn: const Value('milk'),
        category: const Value('dairy'),
        defaultUnit: const Value('l'),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
      CanonicalItemsTableCompanion.insert(
        id: 'oat_milk',
        groupId: '__global__',
        nameDe: const Value('Hafermilch'),
        nameEn: const Value('oat milk'),
        category: const Value('dairy'),
        defaultUnit: const Value('l'),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final repo = GroceryRepository(db: db, dio: Dio());
    await repo.applyDeltaForTesting('group-1', {
      'max_version': 1,
      'canonical_items': [
        {
          'id': apiCanonicalId('milk'),
          'group_id': 'group-1',
          'name_de': 'Milch',
          'name_en': 'milk',
          'category': 'dairy',
          'default_unit': 'l',
          'is_global': false,
          'version': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      ],
      'item_aliases': [
        {
          'id': 'alias-1',
          'group_id': 'group-1',
          'canonical_item_id': apiCanonicalId('milk'),
          'alias_text': 'vollmilch',
          'lang': 'de',
          'source': 'correction',
          'weight': 1,
          'version': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      ],
      'purchase_history': [
        {
          'id': 'purchase-1',
          'canonical_item_id': apiCanonicalId('milk'),
          'quantity': 2,
          'unit': 'l',
          'version': 1,
          'purchased_at': now.toIso8601String(),
        },
      ],
      'item_cooccurrence': [
        {
          'item_a_id': apiCanonicalId('milk'),
          'item_b_id': apiCanonicalId('oat_milk'),
          'count': 3,
          'version': 1,
          'last_seen_at': now.toIso8601String(),
        },
      ],
    });

    final alias = await db.findAlias(
      groupId: 'group-1',
      aliasText: 'vollmilch',
    );

    expect(alias, isNotNull);
    expect(alias!.canonicalItemId, equals('milk'));
    final purchases = await db.getGroupPurchaseHistory(groupId: 'group-1');
    expect(purchases.single.canonicalItemId, 'milk');
    final cooccurrences = await db.getTopCooccurrences(
      groupId: 'group-1',
      itemId: 'milk',
    );
    expect(cooccurrences.single.itemAId, 'milk');
    expect(cooccurrences.single.itemBId, 'oat_milk');
    expect(cooccurrences.single.count, 3);
  });
}
