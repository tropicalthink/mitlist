import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/storage/app_database.dart';

/// Swapping the optimistic temp id for the server id must not drop the
/// "added by" attribution the optimistic row already carried. Older servers
/// (and the batch import path) answer without `added_by`, and the row used to
/// be rebuilt from the response alone, so the name vanished the moment an
/// item synced.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ListItem serverItem({String? addedBy}) => ListItem(
        id: 'server-1',
        listId: 'list-1',
        name: 'Milk',
        quantity: 1,
        unit: '',
        checked: false,
        position: 0,
        addedBy: addedBy,
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      );

  Future<void> seedTempRow() => db.upsertListItemsRows([
        ListItemsTableCompanion(
          id: const Value('temp-1'),
          listId: const Value('list-1'),
          name: const Value('Milk'),
          quantity: const Value(1),
          unit: const Value(''),
          checked: const Value(false),
          position: const Value(0),
          addedBy: const Value('user-a'),
          createdAt: Value(DateTime(2026, 9, 21)),
          updatedAt: Value(DateTime(2026, 9, 21)),
        ),
      ]);

  test('keeps the local addedBy when the server omits it', () async {
    await seedTempRow();

    await db.replaceTempItemId(tempId: 'temp-1', server: serverItem());

    final rows = await db.getItemsByListOnce('list-1');
    expect(rows.map((r) => r.id), ['server-1']);
    expect(rows.single.addedBy, 'user-a');
  });

  test('prefers the server addedBy when it is present', () async {
    await seedTempRow();

    await db.replaceTempItemId(
        tempId: 'temp-1', server: serverItem(addedBy: 'user-b'));

    final rows = await db.getItemsByListOnce('list-1');
    expect(rows.single.addedBy, 'user-b');
  });
}
