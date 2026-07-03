import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/correction_memory_service.dart';
import 'package:mitlist/storage/app_database.dart';

final _now = DateTime(2024, 1, 1);

Future<void> _seedAlias(
  AppDatabase db, {
  required String id,
  required String groupId,
  required String canonicalItemId,
  required String aliasText,
  int weight = 1,
}) async {
  await db.upsertItemAliases([
    ItemAliasesTableCompanion.insert(
      id: id,
      groupId: groupId,
      canonicalItemId: canonicalItemId,
      aliasText: aliasText,
      weight: drift.Value(weight),
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);
}

void main() {
  late AppDatabase db;
  late CorrectionMemoryService service;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    service = CorrectionMemoryService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('household correction does not overwrite a global alias row', () async {
    await _seedAlias(
      db,
      id: 'global-spaghetti',
      groupId: '__global__',
      canonicalItemId: 'egg_spaghetti',
      aliasText: 'spaghetti',
    );

    await service.recordAlias(
      groupId: 'g1',
      userId: 'u1',
      rawText: 'spaghetti',
      canonicalItemId: 'spaghetti_plain',
    );

    final rows = await db.findAliasesByText(
      groupId: 'g1',
      aliasText: 'spaghetti',
    );
    final global = rows.singleWhere((r) => r.id == 'global-spaghetti');
    expect(global.groupId, equals('__global__'));
    expect(global.canonicalItemId, equals('egg_spaghetti'));
    expect(global.weight, equals(1));

    final household = rows.singleWhere((r) => r.groupId == 'g1');
    expect(household.id, isNot(equals(global.id)));
    expect(household.canonicalItemId, equals('spaghetti_plain'));
    expect(household.weight, equals(2));

    final found = await db.findAlias(
      groupId: 'g1',
      aliasText: 'spaghetti',
    );
    expect(found?.id, equals(household.id));
  });

  test('same household alias mapping is reinforced in place', () async {
    await service.recordAlias(
      groupId: 'g1',
      userId: 'u1',
      rawText: 'milk',
      canonicalItemId: 'milk_plain',
    );
    await service.recordAlias(
      groupId: 'g1',
      userId: 'u1',
      rawText: 'milk',
      canonicalItemId: 'milk_plain',
    );

    final rows = await db.findAliasesByText(groupId: 'g1', aliasText: 'milk');
    final householdRows = rows.where((r) => r.groupId == 'g1').toList();
    expect(householdRows, hasLength(1));
    expect(householdRows.single.canonicalItemId, equals('milk_plain'));
    expect(householdRows.single.weight, equals(2));
  });

  test('recordAlias stores text with resolver normalisation', () async {
    await service.recordAlias(
      groupId: 'g1',
      userId: 'u1',
      rawText: 'voll  milch\t',
      canonicalItemId: 'whole_milk',
    );

    final rows = await db.findAliasesByText(
      groupId: 'g1',
      aliasText: 'voll milch',
    );
    expect(rows.where((r) => r.groupId == 'g1'), hasLength(1));
    expect(rows.single.aliasText, equals('voll milch'));
  });

  test('household alias row can be overwritten for a new canonical item',
      () async {
    await _seedAlias(
      db,
      id: 'household-spaghetti',
      groupId: 'g1',
      canonicalItemId: 'spaghetti_old',
      aliasText: 'spaghetti',
    );

    await service.recordAlias(
      groupId: 'g1',
      userId: 'u1',
      rawText: 'spaghetti',
      canonicalItemId: 'spaghetti_new',
    );

    final rows = await db.findAliasesByText(
      groupId: 'g1',
      aliasText: 'spaghetti',
    );
    final householdRows = rows.where((r) => r.groupId == 'g1').toList();
    expect(householdRows, hasLength(1));
    expect(householdRows.single.id, equals('household-spaghetti'));
    expect(householdRows.single.canonicalItemId, equals('spaghetti_new'));
    expect(householdRows.single.weight, equals(2));
  });
}
