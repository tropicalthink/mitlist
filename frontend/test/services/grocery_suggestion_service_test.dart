import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';

// GrocerySuggestionService — proves the typed composer autocomplete now
// tolerates typos (fuzzy alias pass), not just literal prefixes. No embedder
// here, so this isolates the fuzzy behaviour from semantic blending.

AppDatabase _db() => AppDatabase(
      DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true),
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2020);
  var seq = 0;

  Future<void> item(String id, String de, String en, List<String> aliases) async {
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: id,
        groupId: '__global__',
        nameDe: Value(de),
        nameEn: Value(en),
        category: const Value('produce'),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      )
    ]);
    for (final a in [...aliases, de.toLowerCase(), en.toLowerCase()]) {
      await db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: 'al${seq++}',
          groupId: '__global__',
          canonicalItemId: id,
          aliasText: a,
          source: const Value('seed'),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        )
      ]);
    }
  }

  setUp(() async {
    db = _db();
    await item('banana', 'Banane', 'Banana', ['bananen']);
    await item('tomato', 'Tomate', 'Tomato', ['tomaten']);
    await item('milk', 'Milch', 'Milk', ['mlch']);
  });

  tearDown(() => db.close());

  Future<List<String>> ids(String q) async {
    final svc = GrocerySuggestionService(db); // no embedder
    final r = await svc.suggest(q, '__global__');
    return r.map((s) => s.canonicalItemId).toList();
  }

  test('literal prefix still works', () async {
    expect(await ids('banan'), contains('banana'));
  });

  test('typo mid-word now resolves (was empty under prefix-only)', () async {
    // "banann" — no alias starts with it; prefix-only returned nothing.
    expect(await ids('banann'), contains('banana'));
  });

  test('typo resolves for another item', () async {
    expect(await ids('tomaden'), contains('tomato'));
  });

  test('genuine nonsense still returns nothing (no false positives)', () async {
    expect(await ids('qwzxpf'), isEmpty);
  });

  test('prefix hits lead fuzzy hits in ordering', () async {
    // "toma" prefixes Tomate/Tomaten; banana is unrelated → tomato first.
    final result = await ids('toma');
    expect(result.first, 'tomato');
  });

  test('household prior bubbles frequently-bought items up within a tier',
      () async {
    await item('tofu', 'Tofu', 'Tofu', []);
    // Both Tomate and Tofu prefix-match "to" (same tier). Record purchases of
    // tofu so the household prior should float it above tomato.
    for (var i = 0; i < 3; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'ph$i',
              groupId: '__global__',
              purchasedAt: DateTime(2024, 1, i + 1),
              canonicalItemId: const Value('tofu'),
            ),
          );
    }
    final result = await ids('to');
    expect(result, containsAll(['tofu', 'tomato']));
    expect(result.indexOf('tofu'), lessThan(result.indexOf('tomato')),
        reason: 'frequently-bought tofu should rank above tomato');
  });

  test('prior does NOT let a fuzzy/lower-tier item jump a clean prefix hit',
      () async {
    // Buy banana a lot, then type "tomat" (a clean prefix hit for tomato).
    // banana is at best a fuzzy/none match for "tomat"; tomato must still lead.
    for (var i = 0; i < 5; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'pb$i',
              groupId: '__global__',
              purchasedAt: DateTime(2024, 2, i + 1),
              canonicalItemId: const Value('banana'),
            ),
          );
    }
    final result = await ids('tomat');
    expect(result.first, 'tomato');
  });
}
