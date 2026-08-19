import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/storage/app_database.dart';

class _CountingDb extends AppDatabase {
  _CountingDb() : super(NativeDatabase.memory());

  int historyReads = 0;
  int countReads = 0;
  int pairReads = 0;
  Completer<void>? historyGate;
  bool failNextHistory = false;

  @override
  Future<List<PurchaseHistoryTableData>> getGroupPurchaseHistoryForPrior({
    required String groupId,
    required DateTime since,
    int recentLimit = 5000,
    int cadencePerItemLimit = 10,
  }) async {
    historyReads++;
    await historyGate?.future;
    if (failNextHistory) {
      failNextHistory = false;
      throw StateError('synthetic read failure');
    }
    return super.getGroupPurchaseHistoryForPrior(
      groupId: groupId,
      since: since,
      recentLimit: recentLimit,
      cadencePerItemLimit: cadencePerItemLimit,
    );
  }

  @override
  Future<Map<String, int>> getGroupPurchaseCountsForPrior({
    required String groupId,
  }) {
    countReads++;
    return super.getGroupPurchaseCountsForPrior(groupId: groupId);
  }

  @override
  Future<List<ItemCooccurrenceTableData>> getGroupCooccurrences({
    required String groupId,
    int limit = 2000,
  }) {
    pairReads++;
    return super.getGroupCooccurrences(groupId: groupId, limit: limit);
  }
}

void main() {
  late _CountingDb db;
  late DateTime now;
  var nextId = 0;

  setUp(() {
    db = _CountingDb();
    now = DateTime(2026, 8, 12, 12);
    nextId = 0;
  });
  tearDown(() => db.close());

  Future<void> purchase(
    String itemId,
    DateTime at, {
    String groupId = 'g1',
  }) =>
      db.into(db.purchaseHistoryTable).insert(
            PurchaseHistoryTableCompanion.insert(
              id: 'purchase-${nextId++}',
              groupId: groupId,
              canonicalItemId: drift.Value(itemId),
              purchasedAt: at,
            ),
          );

  HouseholdPriorService service() =>
      HouseholdPriorService(db, clock: () => now);

  test('familiarity decays and future timestamps clamp to zero age', () async {
    await purchase('now', now);
    await purchase('sixty-days', now.subtract(const Duration(days: 60)));
    await purchase('future', now.add(const Duration(days: 2)));

    final context = await service().baseContext('g1');
    expect(
      service().featuresFor('missing', context).familiarity,
      0,
    );
    // A service instance does not own the context, so feature lookup remains
    // pure and can be performed by another identically configured instance.
    final scorer = service();
    expect(scorer.featuresFor('now', context).familiarity, closeTo(0.5, 1e-9));
    expect(
      scorer.featuresFor('sixty-days', context).familiarity,
      closeTo(1 / (1 + 2.718281828459045), 1e-9),
    );
    expect(
      scorer.featuresFor('future', context).familiarity,
      closeTo(0.5, 1e-9),
    );
  });

  test('cadence shrinkage covers one, two, and ten purchases', () async {
    await purchase('one', now, groupId: 'g-one');
    await purchase(
      'two',
      now.subtract(const Duration(days: 28)),
      groupId: 'g-two',
    );
    await purchase('two', now, groupId: 'g-two');
    for (var i = 0; i < 2; i++) {
      await purchase(
        'weekly',
        now.subtract(Duration(days: 7 * (1 - i))),
        groupId: 'g-two',
      );
    }
    for (var i = 0; i < 10; i++) {
      await purchase(
        'ten',
        now.subtract(Duration(days: 28 * (9 - i))),
        groupId: 'g-ten',
      );
    }
    await purchase(
      'weekly',
      now.subtract(const Duration(days: 7)),
      groupId: 'g-ten',
    );
    await purchase('weekly', now, groupId: 'g-ten');

    final prior = service();
    final one = prior
        .top(await prior.baseContext('g-one'), limit: 10, floor: 0)
        .singleWhere((entry) => entry.canonicalItemId == 'one');
    final two = prior
        .top(await prior.baseContext('g-two'), limit: 10, floor: 0)
        .singleWhere((entry) => entry.canonicalItemId == 'two');
    final ten = prior
        .top(await prior.baseContext('g-ten'), limit: 10, floor: 0)
        .singleWhere((entry) => entry.canonicalItemId == 'ten');

    expect(one.estimatedIntervalDays, 14);
    expect(two.estimatedIntervalDays, 20);
    expect(ten.estimatedIntervalDays, 25);
  });

  test('duplicate gaps are ignored and quarterly cadence survives the window',
      () async {
    final old = now.subtract(const Duration(days: 500));
    await purchase('quarterly', old);
    await purchase('quarterly', old); // zero gap must not affect the median.
    await purchase('quarterly', old.add(const Duration(days: 90)));
    await purchase('quarterly', old.add(const Duration(days: 180)));

    final prior = service();
    final context = await prior.baseContext('g1');
    final item = prior
        .top(context, limit: 10, floor: 0)
        .singleWhere((entry) => entry.canonicalItemId == 'quarterly');
    expect(item.estimatedIntervalDays, 90);
    expect(item.features.familiarity, 0);
  });

  test('an abandoned old one-off item falls below the restock floor', () async {
    await purchase('abandoned', now.subtract(const Duration(days: 400)));
    final prior = service();
    final context = await prior.baseContext('g1');
    expect(
      prior.top(context).map((entry) => entry.canonicalItemId),
      isNot(contains('abandoned')),
    );
  });

  test('weekday affinity uses only that item recent purchases', () async {
    await purchase('milk', now.subtract(const Duration(days: 7)));
    for (var i = 0; i < 20; i++) {
      await purchase('noise', now.subtract(Duration(days: i + 1)));
    }
    final prior = service();
    final context = await prior.baseContext('g1');
    expect(
      prior.featuresFor('milk', context).dayOfWeek,
      closeTo(0.375, 1e-9),
    );
  });

  test('cooccurrence uses lifetime marginals, canonical pairs, and zero guards',
      () async {
    for (var i = 0; i < 4; i++) await purchase('candidate', now);
    for (var i = 0; i < 2; i++) await purchase('context', now);
    await db.into(db.itemCooccurrenceTable).insert(
          ItemCooccurrenceTableCompanion.insert(
            groupId: 'g1',
            itemAId: 'context',
            itemBId: 'candidate',
            count: const drift.Value(2),
            lastSeenAt: now,
          ),
        );

    final prior = service();
    final context = await prior.baseContext('g1');
    final feature = prior.featuresFor(
      'candidate',
      context,
      listContextIds: const ['context', 'context'],
    );
    expect(feature.cooccurrence, greaterThan(0));
    expect(
      prior.featuresFor('candidate', context).cooccurrence,
      0,
    );
    expect(
      prior.featuresFor(
        'candidate',
        context,
        listContextIds: const ['missing-marginal'],
      ).cooccurrence,
      0,
    );
  });

  test(
      'scorer permits prior crossing but preserves lexical order at equal prior',
      () {
    final scorer = HouseholdRankingScorer(HouseholdPriorDefaults());
    final familiarFuzzy = scorer.score(const GroceryRankingFeatures(
      lexSim: 0.70,
      prior: HouseholdPriorFeatures(
        familiarity: 0.95,
        dueWeighted: 0.70,
        cooccurrence: 0.80,
        dayOfWeek: 0.50,
      ),
    ));
    final unfamiliarPrefix = scorer.score(const GroceryRankingFeatures(
      lexPrefix: 1,
      lexSim: 0.75,
    ));
    expect(familiarFuzzy, greaterThan(unfamiliarPrefix));

    const equalPrior = HouseholdPriorFeatures(familiarity: 0.4);
    expect(
      scorer.score(const GroceryRankingFeatures(
        lexPrefix: 1,
        lexSim: 0.7,
        prior: equalPrior,
      )),
      greaterThan(scorer.score(const GroceryRankingFeatures(
        lexSim: 0.7,
        prior: equalPrior,
      ))),
    );
  });

  test(
      'cache reuses identity, shares inflight work, expires, and isolates groups',
      () async {
    final prior = service();
    db.historyGate = Completer<void>();
    final firstFuture = prior.baseContext('g1');
    final concurrentFuture = prior.baseContext('g1');
    await Future<void>.delayed(Duration.zero);
    expect(db.historyReads, 1);
    db.historyGate!.complete();
    final first = await firstFuture;
    final concurrent = await concurrentFuture;
    expect(identical(first, concurrent), isTrue);
    expect(identical(first, await prior.baseContext('g1')), isTrue);

    final otherGroup = await prior.baseContext('g2');
    expect(identical(first, otherGroup), isFalse);
    expect(db.historyReads, 2);

    now = now.add(const Duration(seconds: 301));
    final refreshed = await prior.baseContext('g1');
    expect(identical(first, refreshed), isFalse);
    expect(db.historyReads, 3);
  });

  test('failed loads are evicted and can be retried', () async {
    final prior = service();
    db.failNextHistory = true;
    await expectLater(prior.baseContext('g1'), throwsStateError);
    await expectLater(prior.baseContext('g1'), completes);
    expect(db.historyReads, 2);
  });
}
