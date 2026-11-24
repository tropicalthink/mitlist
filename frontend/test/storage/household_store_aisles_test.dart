import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/grocery_seed_test_helper.dart';

StoreAislesTableCompanion _row(
  String id, {
  String? storeId = 'rewe',
  String aisle = 'Dairy',
  int sortOrder = 10,
  DateTime? at,
}) {
  final when = at ?? DateTime(2026, 10, 1);
  return StoreAislesTableCompanion.insert(
    id: id,
    groupId: 'g1',
    canonicalItemId: 'milk',
    storeId: Value(storeId),
    aisle: Value(aisle),
    sortOrder: Value(sortOrder),
    createdAt: when,
    updatedAt: when,
  );
}

void main() {
  test('a re-upload and its server copy converge on one row', () async {
    final db = memoryDb();
    addTearDown(db.close);

    await db.upsertHouseholdStoreAisles([_row('local-1')]);
    await db.upsertHouseholdStoreAisles(
        [_row('local-2', aisle: 'Kühlregal', sortOrder: 4)]);
    // The server echoes the drag back under its own id.
    await db.upsertHouseholdStoreAisles(
        [_row('server-9', aisle: 'Kühlregal', sortOrder: 4)]);

    final rows = await db.getStoreAisles(groupId: 'g1', storeId: 'rewe');
    expect(rows, hasLength(1));
    expect(rows.single.id, 'server-9');
    final hit = await db.getStoreAisle(
        groupId: 'g1', storeId: 'rewe', canonicalItemId: 'milk');
    expect(hit?.aisle, 'Kühlregal');
  });

  test('stores, and the no-store order, stay separate', () async {
    final db = memoryDb();
    addTearDown(db.close);

    await db.upsertHouseholdStoreAisles([
      _row('a'),
      _row('b', storeId: 'lidl', aisle: 'Chilled'),
      _row('c', storeId: null, aisle: 'Anywhere'),
    ]);
    await db.upsertHouseholdStoreAisles(
        [_row('d', storeId: null, aisle: 'Fridge')]);

    final all = await db.getStoreAisles(groupId: 'g1');
    expect(all.map((r) => r.aisle),
        unorderedEquals(['Dairy', 'Chilled', 'Fridge']));
  });
}
