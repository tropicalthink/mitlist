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
    });

    final alias = await db.findAlias(
      groupId: 'group-1',
      aliasText: 'vollmilch',
    );

    expect(alias, isNotNull);
    expect(alias!.canonicalItemId, equals('milk'));
  });
}
