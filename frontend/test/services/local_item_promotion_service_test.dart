import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/local_item_promotion_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/utils/uuid_validation.dart';

import '../support/grocery_seed_test_helper.dart';

/// LocalItemPromotionService — proves a repeatedly-checked-off word the resolver
/// never mapped ("fassi") earns its way into the household's canonical graph
/// after [kLocalPromotionThreshold] check-offs, and then actually surfaces in
/// autocomplete — while staying scoped to that one household.
void main() {
  late AppDatabase db;
  late LocalItemPromotionService svc;
  const group = 'g1';

  setUp(() {
    db = memoryDb();
    svc = LocalItemPromotionService(db);
  });

  tearDown(() async => db.close());

  Future<int> canonicalCount() async =>
      (await db.select(db.canonicalItemsTable).get()).length;
  Future<int> aliasCount() async =>
      (await db.select(db.itemAliasesTable).get()).length;

  test('sub-threshold check-offs mint nothing and just tally', () async {
    for (var i = 0; i < kLocalPromotionThreshold - 1; i++) {
      final r =
          await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
      expect(r, isNull,
          reason: 'below threshold returns null (learns nothing)');
    }
    expect(await canonicalCount(), 0);
    expect(await aliasCount(), 0);

    final sig =
        await db.getLocalItemSignal(groupId: group, normalizedName: 'fassi');
    expect(sig, isNotNull);
    expect(sig!.count, kLocalPromotionThreshold - 1);
    expect(sig.promotedCanonicalItemId, isNull);
  });

  test(
      'crossing the threshold mints exactly one household-local canonical + alias',
      () async {
    LocalPromotionResult? result;
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      result =
          await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'Fassi');
    }
    expect(result, isNotNull);
    expect(result!.justPromoted, isTrue);
    expect(result.normalizedName, 'fassi');

    expect(await canonicalCount(), 1);
    expect(await aliasCount(), 1);

    final canon = (await db.select(db.canonicalItemsTable).get()).single;
    expect(canon.groupId, group);
    expect(canon.isGlobal, isFalse,
        reason: 'never leaks into the shared brain');
    expect(canon.id, result.canonicalItemId);
    expect(apiCanonicalId(canon.id), canon.id,
        reason: 'minted id is already a valid API uuid, syncs unchanged');
    expect(canon.nameEn, 'Fassi', reason: 'human display casing preserved');

    final sig =
        await db.getLocalItemSignal(groupId: group, normalizedName: 'fassi');
    expect(sig!.promotedCanonicalItemId, result.canonicalItemId);
  });

  test('post-promotion check-offs reinforce, never re-mint', () async {
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    }
    final again =
        await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    expect(again, isNotNull);
    expect(again!.justPromoted, isFalse);
    expect(await canonicalCount(), 1, reason: 'still exactly one canonical');
    expect(await aliasCount(), 1, reason: 'still exactly one alias');

    final sig =
        await db.getLocalItemSignal(groupId: group, normalizedName: 'fassi');
    expect(sig!.count, kLocalPromotionThreshold + 1);
  });

  test('idempotent: a re-fired promotion keeps a single canonical id',
      () async {
    // Deterministic id means minting the same (group, word) twice is a no-op
    // upsert, not a duplicate.
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    }
    final firstId = (await db.select(db.canonicalItemsTable).get()).single.id;
    // A second fresh service instance minting the same word again.
    final svc2 = LocalItemPromotionService(db);
    final r =
        await svc2.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    expect(r!.canonicalItemId, firstId);
    expect(await canonicalCount(), 1);
  });

  test('normalisation collapses casing/whitespace to one signal', () async {
    await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'Fassi');
    await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi ');
    final crossed =
        await svc.recordUnresolvedCheckoff(groupId: group, rawName: '  FASSI');
    // Three spellings of the same word → one signal, promoted on the 3rd.
    final signals = await db.select(db.localItemSignalsTable).get();
    expect(signals.length, 1);
    expect(crossed, isNotNull);
    expect(await canonicalCount(), 1);
  });

  test('same word in two households mints distinct ids (no collision)',
      () async {
    String? idA, idB;
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      idA = (await svc.recordUnresolvedCheckoff(groupId: 'A', rawName: 'fassi'))
          ?.canonicalItemId;
      idB = (await svc.recordUnresolvedCheckoff(groupId: 'B', rawName: 'fassi'))
          ?.canonicalItemId;
    }
    expect(idA, isNotNull);
    expect(idB, isNotNull);
    expect(idA, isNot(idB),
        reason: 'group-scoped ids so the server ON CONFLICT never cross-links');
  });

  test('empty / whitespace-only name is ignored', () async {
    final r =
        await svc.recordUnresolvedCheckoff(groupId: group, rawName: '   ');
    expect(r, isNull);
    expect(await canonicalCount(), 0);
    expect(await db.select(db.localItemSignalsTable).get(), isEmpty);
  });

  test('once promoted the word surfaces in autocomplete for its household only',
      () async {
    LocalPromotionResult? promoted;
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      promoted =
          await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    }
    final mintedId = promoted!.canonicalItemId;
    final suggest = GrocerySuggestionService(
      db,
      prior: HouseholdPriorService(db),
    ); // no embedder, no reference DB

    final mine = await suggest.suggest(
      'fas',
      group,
      suggestionContext: GrocerySuggestionContext.shoppingList,
    );
    expect(mine.map((s) => s.canonicalItemId), contains(mintedId));
    // Display name is title-cased by the suggestion UI layer.
    expect(mine.map((s) => s.name.toLowerCase()), contains('fassi'));

    final other = await suggest.suggest(
      'fas',
      'someone-else',
      suggestionContext: GrocerySuggestionContext.shoppingList,
    );
    expect(other, isEmpty,
        reason: 'household-scoped — never leaks to other groups');
  });

  test('clearAllUserData reclaims minted rows and pending signals', () async {
    for (var i = 0; i < kLocalPromotionThreshold; i++) {
      await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'fassi');
    }
    await svc.recordUnresolvedCheckoff(groupId: group, rawName: 'onlyonce');
    await db.clearAllUserData();
    expect(await canonicalCount(), 0);
    expect(await aliasCount(), 0);
    expect(await db.select(db.localItemSignalsTable).get(), isEmpty);
  });
}
