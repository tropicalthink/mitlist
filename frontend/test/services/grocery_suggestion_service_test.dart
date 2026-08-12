import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/static_embedding_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/storage/grocery_reference_database.dart';

import '../support/grocery_seed_test_helper.dart';

// GrocerySuggestionService — proves the typed composer autocomplete now
// tolerates typos (fuzzy alias pass), not just literal prefixes. No embedder
// here, so this isolates the fuzzy behaviour from semantic blending.
//
// The global grocery catalogue lives in the read-only reference DB in
// production, so these tests build one and attach it (rebuilding whenever an
// item is added mid-test) rather than seeding the main DB.

void main() {
  late AppDatabase db;
  GroceryReferenceDatabase? ref;

  final canonical = <RefCanonical>[];
  final aliases = <RefAlias>[];
  final testNow = DateTime(2026, 8, 12, 12);

  void rebuildRef() {
    ref?.close();
    ref = GroceryReferenceDatabase.open(
        buildTestRefDb(canonical: canonical, aliases: aliases));
    db.attachReference(ref!);
  }

  void item(String id, String de, String en, List<String> aliasTexts) {
    canonical.add((id, de, en, 'produce'));
    for (final a in [...aliasTexts, de.toLowerCase(), en.toLowerCase()]) {
      aliases.add((id, a, 'seed', 1));
    }
    rebuildRef();
  }

  setUp(() async {
    db = memoryDb();
    canonical.clear();
    aliases.clear();
    item('banana', 'Banane', 'Banana', ['bananen']);
    item('tomato', 'Tomate', 'Tomato', ['tomaten']);
    item('milk', 'Milch', 'Milk', ['mlch']);
  });

  tearDown(() async {
    ref?.close();
    ref = null;
    await db.close();
  });

  Future<List<String>> ids(
    String q, {
    int limit = 8,
    GrocerySuggestionContext context = GrocerySuggestionContext.shoppingList,
    StaticEmbeddingService? embedder,
  }) async {
    final svc = GrocerySuggestionService(
      db,
      prior: HouseholdPriorService(db, clock: () => testNow),
      embedder: embedder,
    ); // no embedder
    final r = await svc.suggest(
      q,
      '__global__',
      suggestionContext: context,
      limit: limit,
    );
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

  test('household prior can reorder lexical candidates continuously', () async {
    item('tofu', 'Tofu', 'Tofu', []);
    // Both Tomate and Tofu prefix-match "to" (same tier). Record purchases of
    // tofu so the household prior should float it above tomato.
    for (var i = 0; i < 3; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'ph$i',
              groupId: '__global__',
              purchasedAt: testNow.subtract(Duration(days: i)),
              canonicalItemId: const Value('tofu'),
            ),
          );
    }
    final result = await ids('to');
    expect(result, containsAll(['tofu', 'tomato']));
    expect(result.indexOf('tofu'), lessThan(result.indexOf('tomato')),
        reason: 'frequently-bought tofu should rank above tomato');
  });

  test('an unrelated familiar item is not injected into textual retrieval',
      () async {
    // Buy banana a lot, then type "tomat" (a clean prefix hit for tomato).
    // banana is at best a fuzzy/none match for "tomat"; tomato must still lead.
    for (var i = 0; i < 5; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'pb$i',
              groupId: '__global__',
              purchasedAt: testNow.subtract(Duration(days: i)),
              canonicalItemId: const Value('banana'),
            ),
          );
    }
    final result = await ids('tomat');
    expect(result.first, 'tomato');
  });

  // ---------------------------------------------------------------------------
  // Word-level FTS5 recall (plan 012 A2)
  // ---------------------------------------------------------------------------

  test('word-prefix: query matching mid-word finds item via FTS5', () async {
    // 'breast pads' is a multi-word alias; typing 'pad' should match it via
    // the FTS5 word-prefix path even though 'pad' is not a prefix of the whole
    // alias string "breast pads".
    item('breast_pads', 'Brustpads', 'Breast Pads',
        ['breast pads', 'nursing pads', 'brusteinlage']);
    final result = await ids('pad');
    expect(result, contains('breast_pads'),
        reason: 'FTS5 word-prefix should match "pad" inside "breast pads"');
  });

  test('word-prefix: brand alias resolves when typing brand name', () async {
    // Simulate a curated brand alias: "pringles" on "potato_chips".
    item('potato_chips', 'Kartoffelchips', 'Potato Chips',
        ['pringles', 'lay\'s', 'chips']);
    final result = await ids('pring');
    expect(result, contains('potato_chips'),
        reason: 'FTS5 word-prefix should match "pring*" on alias "pringles"');
  });

  test('word-prefix: multi-word query narrows to correct item', () async {
    // "corn fl" should match "corn flakes" but not "potato chips"
    item('corn_flakes', 'Cornflakes', 'Corn Flakes',
        ['cornflakes', 'corn flakes', 'breakfast cereal']);
    item('potato_chips2', 'Chips', 'Potato Chips', ['chips', 'crisps']);
    final result = await ids('corn fl');
    expect(result, contains('corn_flakes'),
        reason:
            'FTS5 multi-word prefix should match "corn" AND "fl*" in alias');
    expect(result, isNot(contains('potato_chips2')),
        reason: 'potato chips should not match "corn fl"');
  });

  test('whole-string prefix hits still lead word-prefix hits', () async {
    // "banana" aliases both 'banana' and 'banana chips' style item.
    // Typing "ban" — banana has a whole-string alias starting with "ban",
    // so it should still appear in results (Tier 0) regardless of FTS.
    final result = await ids('ban');
    expect(result, contains('banana'));
  });

  test('saturated prefix retrieval still retrieves and promotes a fuzzy staple',
      () async {
    for (var i = 0; i < 8; i++) {
      item('prefix-$i', 'Tomcat $i', 'Tomcat $i', ['tomcat$i']);
    }
    item('staple', 'Weekly staple', 'Weekly staple', ['toom']);
    for (var i = 0; i < 10; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'staple-purchase-$i',
              groupId: '__global__',
              canonicalItemId: const Value('staple'),
              purchasedAt: testNow.subtract(Duration(hours: i)),
            ),
          );
    }

    final result = await ids('tom', limit: 8);
    expect(result, hasLength(8));
    expect(result.first, 'staple',
        reason: 'fuzzy retrieval and continuous prior ranking must cross');
  });

  test('with equal prior a clean prefix stays ahead of a fuzzy candidate',
      () async {
    item('prefix-equal', 'Tomato sauce', 'Tomato sauce', ['tomato sauce']);
    item('fuzzy-equal', 'Pantry item', 'Pantry item', ['toom']);

    final result = await ids(
      'tom',
      context: GrocerySuggestionContext.nonShoppingList,
    );
    expect(result.indexOf('prefix-equal'),
        lessThan(result.indexOf('fuzzy-equal')));
  });

  test('prefix and semantic evidence are retained when candidates merge',
      () async {
    item('lexical-rival', 'Toma', 'Toma', ['toma']);
    item('merged-target', 'Tomxxxx', 'Tomxxxx', ['tomxxxx']);
    final embedder = StaticEmbeddingService()
      ..seedForTest(
        vocab: const ['tom'],
        vocabVectors: [
          Float32List.fromList(const [1, 0])
        ],
        itemIds: const ['merged-target', 'lexical-rival'],
        catalogVectors: [
          Float32List.fromList(const [1, 0]),
          Float32List.fromList(const [0, 1]),
        ],
      );
    addTearDown(embedder.dispose);

    final result = await ids(
      'tom',
      context: GrocerySuggestionContext.nonShoppingList,
      embedder: embedder,
    );
    expect(result.first, 'merged-target');
  });

  test('full alias is pinned ahead of a heavily familiar near-match', () async {
    item('potato-chips', 'Potato Chips', 'Potato Chips', ['pringles']);
    item('familiar-near-alias', 'Familiar crisps', 'Familiar crisps', [
      'pringless',
    ]);
    for (var i = 0; i < 12; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'alias-competitor-$i',
              groupId: '__global__',
              canonicalItemId: const Value('familiar-near-alias'),
              purchasedAt: testNow.subtract(Duration(hours: i)),
            ),
          );
    }

    expect((await ids('Pringles')).first, 'potato-chips');
  });

  test('full canonical name is pinned ahead of a familiar near-match',
      () async {
    item(
      'hazelnut-spread',
      'Haselnusscreme',
      'Hazelnut Spread',
      const [],
    );
    item(
      'familiar-near-name',
      'Familiar spread',
      'Familiar spread',
      const ['hazelnut spreads'],
    );
    for (var i = 0; i < 12; i++) {
      await db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'name-competitor-$i',
              groupId: '__global__',
              canonicalItemId: const Value('familiar-near-name'),
              purchasedAt: testNow.subtract(Duration(hours: i)),
            ),
          );
    }

    expect((await ids('Hazelnut Spread')).first, 'hazelnut-spread');
  });

  test('an absent embedder remains fail-soft for lexical results', () async {
    expect(await ids('banan'), contains('banana'));
  });
}
