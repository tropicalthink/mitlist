import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';

void main() {
  test('shipped store layout ids resolve global aisle rows', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final now = DateTime.utc(2026, 1, 1);
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
    await db.upsertStoreAisles([
      StoreAislesTableCompanion.insert(
        id: 'aisle-milk-rewe',
        groupId: '__global__',
        storeId: const Value('de_rewe'),
        canonicalItemId: 'milk',
        aisle: const Value('dairy'),
        sortOrder: const Value(5),
        confidence: const Value(1),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final aisles = await db.getStoreAisles(
      groupId: '__global__',
      storeId: 'de_rewe',
    );

    expect(aisles, hasLength(1));
    expect(aisles.single.canonicalItemId, 'milk');
    expect(aisles.single.aisle, 'dairy');
    expect(aisles.single.sortOrder, 5);
  });
}
