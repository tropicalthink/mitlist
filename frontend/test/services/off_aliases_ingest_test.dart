import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';

// OFF brand aliases (plan 012 A3) live in item_aliases with source='off'. They
// must survive a seed reingest (clearGlobalSeed) and be removable on their own
// for a versioned re-ingest. This proves both invariants at the DB layer
// (the loader's rootBundle parsing is exercised separately on device).

AppDatabase _db() => AppDatabase(
      DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true),
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2020);
  const g = '__global__';

  Future<void> alias(String id, String canonical, String text, String source) =>
      db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: id,
          groupId: g,
          canonicalItemId: canonical,
          aliasText: text,
          source: Value(source),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        )
      ]);

  setUp(() async {
    db = _db();
    // one global canonical item so clearGlobalSeed has something to clear
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: 'potato_chips',
        groupId: g,
        nameEn: const Value('Potato Chips'),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      )
    ]);
    await alias('a1', 'potato_chips', 'chips', 'seed');
    await alias('a2', 'potato_chips', 'pringles', 'off');
  });

  tearDown(() => db.close());

  test('clearGlobalSeed drops seed aliases but keeps OFF aliases', () async {
    await db.clearGlobalSeed(g);
    final remaining = await db.select(db.itemAliasesTable).get();
    final texts = remaining.map((r) => r.aliasText).toSet();
    expect(texts, contains('pringles'),
        reason: 'OFF brand alias must survive a reseed');
    expect(texts, isNot(contains('chips')),
        reason: 'seed alias is cleared by reseed');
  });

  test('clearGlobalAliasesBySource removes only that source', () async {
    await db.clearGlobalAliasesBySource(g, 'off');
    final remaining = await db.select(db.itemAliasesTable).get();
    final texts = remaining.map((r) => r.aliasText).toSet();
    expect(texts, contains('chips'), reason: 'seed alias untouched');
    expect(texts, isNot(contains('pringles')),
        reason: 'OFF aliases removed for re-ingest');
  });

  test('OFF alias is findable by its text', () async {
    final found = await db.findAlias(groupId: g, aliasText: 'pringles');
    expect(found, isNotNull);
    expect(found!.canonicalItemId, 'potato_chips');
  });
}
