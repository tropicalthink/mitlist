// ignore_for_file: prefer_single_quotes
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/static_embedding_service.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/grocery_seed_test_helper.dart';

class _CountingDb extends AppDatabase {
  _CountingDb() : super(NativeDatabase.memory());

  int exactCalls = 0;
  int prefixCalls = 0;
  int wordPrefixCalls = 0;
  int fuzzyCalls = 0;
  int priorHistoryCalls = 0;

  @override
  Future<ItemAliasesTableData?> findAlias({
    required String groupId,
    required String aliasText,
  }) {
    exactCalls++;
    return super.findAlias(groupId: groupId, aliasText: aliasText);
  }

  @override
  Future<List<ItemAliasesTableData>> searchAliasPrefix({
    required String groupId,
    required String query,
    int limit = 40,
  }) {
    prefixCalls++;
    return super.searchAliasPrefix(
      groupId: groupId,
      query: query,
      limit: limit,
    );
  }

  @override
  Future<List<ItemAliasesTableData>> searchAliasWordPrefix({
    required String groupId,
    required String query,
    int limit = 80,
  }) {
    wordPrefixCalls++;
    return super.searchAliasWordPrefix(
      groupId: groupId,
      query: query,
      limit: limit,
    );
  }

  @override
  Future<List<ItemAliasesTableData>> getAliasFuzzyCandidates({
    required String groupId,
    required String query,
    int maxCandidates = 400,
  }) {
    fuzzyCalls++;
    return super.getAliasFuzzyCandidates(
      groupId: groupId,
      query: query,
      maxCandidates: maxCandidates,
    );
  }

  @override
  Future<List<PurchaseHistoryTableData>> getGroupPurchaseHistoryForPrior({
    required String groupId,
    required DateTime since,
    int recentLimit = 5000,
    int cadencePerItemLimit = 10,
  }) {
    priorHistoryCalls++;
    return super.getGroupPurchaseHistoryForPrior(
      groupId: groupId,
      since: since,
      recentLimit: recentLimit,
      cadencePerItemLimit: cadencePerItemLimit,
    );
  }
}

class _CountingEmbedder extends StaticEmbeddingService {
  int nearestCalls = 0;

  @override
  bool get isReady => true;

  @override
  Future<List<EmbedMatch>> nearest(String query, {int topK = 5}) async {
    nearestCalls++;
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('typed-autocomplete over the full seed', () {
    late AppDatabase db;

    setUp(() async {
      db = memoryDb();
      // Seed the real catalogue straight into the main DB under the global
      // scope. Production now serves those rows from the read-only reference DB,
      // but the main-DB queries keep the `__global__` disjunct so this in-DB
      // seeding still exercises the same prefix/FTS paths without a ref DB.
      await ingestRealSeed(db);
    });

    tearDown(() => db.close());

    test('"mil" returns suggestions', () async {
      final svc = GrocerySuggestionService(
        db,
        prior: HouseholdPriorService(db),
      );
      final suggestions = await svc.suggest(
        'mil',
        'group-1',
        suggestionContext: GrocerySuggestionContext.shoppingList,
      );
      expect(suggestions, isNotEmpty);
    });

    test('prefix search seeks the composite index, not a full scan', () async {
      // A full-table scan per keystroke over the ~280k-row alias seed is what
      // made suggestions feel laggy/absent. The prefix search must be driven by
      // the (group_id, alias_text) composite index; guard against regressing to
      // a group_id-only seek (which leaves a full alias_text scan) or a SCAN.
      final plan = await db
          .customSelect(
              "EXPLAIN QUERY PLAN SELECT * FROM item_aliases_table WHERE "
              "(group_id = 'g' OR group_id = '__global__') AND deleted_at IS NULL "
              "AND alias_text >= 'mil' AND alias_text < 'mim' "
              "ORDER BY weight DESC LIMIT 40")
          .get();
      final detail =
          plan.map((r) => r.data['detail'] as String? ?? '').join(' | ');
      expect(detail, contains('idx_item_aliases_group_alias'),
          reason: 'prefix search must use the composite index; plan: $detail');
      expect(detail, isNot(contains('SCAN item_aliases_table')),
          reason: 'prefix search must not full-scan; plan: $detail');
    });
  });

  test('one character uses only repertoire retrieval and reuses prior cache',
      () async {
    final db = _CountingDb();
    addTearDown(db.close);
    final embedder = _CountingEmbedder();
    addTearDown(embedder.dispose);
    final now = DateTime.utc(2026, 8, 12);
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: 'milk',
        groupId: 'group-1',
        nameEn: const drift.Value('Milk'),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
      id: 'purchase-1',
      groupId: 'group-1',
      canonicalItemId: const drift.Value('milk'),
      purchasedAt: now,
    ));
    final prior = HouseholdPriorService(db, clock: () => now);
    final service = GrocerySuggestionService(
      db,
      prior: prior,
      embedder: embedder,
    );

    final first = await service.suggest(
      'm',
      'group-1',
      suggestionContext: GrocerySuggestionContext.shoppingList,
    );
    final second = await service.suggest(
      'm',
      'group-1',
      suggestionContext: GrocerySuggestionContext.shoppingList,
    );

    expect(first.map((item) => item.canonicalItemId), ['milk']);
    expect(second.map((item) => item.canonicalItemId), ['milk']);
    expect(db.exactCalls, 0);
    expect(db.prefixCalls, 0);
    expect(db.wordPrefixCalls, 0);
    expect(db.fuzzyCalls, 0);
    expect(embedder.nearestCalls, 0);
    expect(db.priorHistoryCalls, 1);
  });
}
