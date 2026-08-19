import 'dart:async';
import 'dart:math' as math;

import '../storage/app_database.dart';

class HouseholdPriorDefaults {
  HouseholdPriorDefaults({
    this.lexPrefixWeight = 1.8,
    this.lexSimWeight = 1.6,
    this.lexSemanticWeight = 0.9,
    this.familiarityWeight = 1.5,
    this.dueWeightedWeight = 1.5,
    this.cooccurrenceWeight = 1.2,
    this.dayOfWeekWeight = 0.5,
    this.bias = -2.2,
    this.decayDays = 60,
    this.shrinkageK = 3,
    this.fallbackCadenceDays = 14,
    this.cacheTtl = const Duration(seconds: 300),
    this.restockFloor = 0.15,
  }) {
    final values = [
      lexPrefixWeight,
      lexSimWeight,
      lexSemanticWeight,
      familiarityWeight,
      dueWeightedWeight,
      cooccurrenceWeight,
      dayOfWeekWeight,
      decayDays,
      shrinkageK,
      fallbackCadenceDays,
      restockFloor,
    ];
    assert(values.every((value) => value.isFinite && value >= 0));
    assert(bias.isFinite);

    final scorer = HouseholdRankingScorer._(this);
    const zero = HouseholdPriorFeatures();
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
      prior: zero,
    ));
    assert(familiarFuzzy > unfamiliarPrefix);

    const equalPrior = HouseholdPriorFeatures(
      familiarity: 0.4,
      dueWeighted: 0.2,
      dayOfWeek: 0.1,
    );
    final prefix = scorer.score(const GroceryRankingFeatures(
      lexPrefix: 1,
      lexSim: 0.7,
      prior: equalPrior,
    ));
    final fuzzy = scorer.score(const GroceryRankingFeatures(
      lexSim: 0.7,
      prior: equalPrior,
    ));
    assert(prefix > fuzzy);
  }

  final double lexPrefixWeight;
  final double lexSimWeight;
  final double lexSemanticWeight;
  final double familiarityWeight;
  final double dueWeightedWeight;
  final double cooccurrenceWeight;
  final double dayOfWeekWeight;
  final double bias;
  final double decayDays;
  final double shrinkageK;
  final double fallbackCadenceDays;
  final Duration cacheTtl;
  final double restockFloor;
}

class HouseholdPriorFeatures {
  const HouseholdPriorFeatures({
    this.familiarity = 0,
    this.dueWeighted = 0,
    this.cooccurrence = 0,
    this.dayOfWeek = 0,
  });

  final double familiarity;
  final double dueWeighted;
  final double cooccurrence;
  final double dayOfWeek;
}

class GroceryRankingFeatures {
  const GroceryRankingFeatures({
    this.lexPrefix = 0,
    this.lexSim = 0,
    this.lexSemantic = 0,
    this.prior = const HouseholdPriorFeatures(),
  });

  final double lexPrefix;
  final double lexSim;
  final double lexSemantic;
  final HouseholdPriorFeatures prior;
}

class HouseholdRankingScorer {
  HouseholdRankingScorer(HouseholdPriorDefaults defaults)
      : _defaults = defaults;

  HouseholdRankingScorer._(this._defaults);

  final HouseholdPriorDefaults _defaults;

  double score(GroceryRankingFeatures features) {
    final z = _defaults.bias +
        _defaults.lexPrefixWeight * features.lexPrefix +
        _defaults.lexSimWeight * features.lexSim +
        _defaults.lexSemanticWeight * features.lexSemantic +
        _defaults.familiarityWeight * features.prior.familiarity +
        _defaults.dueWeightedWeight * features.prior.dueWeighted +
        _defaults.cooccurrenceWeight * features.prior.cooccurrence +
        _defaults.dayOfWeekWeight * features.prior.dayOfWeek;
    return 1 / (1 + math.exp(-z));
  }
}

class ScoredPriorItem {
  const ScoredPriorItem({
    required this.canonicalItemId,
    required this.score,
    required this.features,
    required this.estimatedIntervalDays,
    required this.daysSince,
  });

  final String canonicalItemId;
  final double score;
  final HouseholdPriorFeatures features;
  final int estimatedIntervalDays;
  final int daysSince;
}

class HouseholdPriorContext {
  const HouseholdPriorContext._({
    required this.builtAt,
    required this.recentSince,
    required this.lifetimeCounts,
    required Map<String, _PriorItemStats> itemStats,
    required Map<_ItemPair, int> pairCounts,
    required this.totalPurchases,
    required this.vocabularySize,
  })  : _itemStats = itemStats,
        _pairCounts = pairCounts;

  final DateTime builtAt;
  final DateTime recentSince;
  final Map<String, int> lifetimeCounts;
  final Map<String, _PriorItemStats> _itemStats;
  final Map<_ItemPair, int> _pairCounts;
  final int totalPurchases;
  final int vocabularySize;

  Set<String> get repertoireIds => lifetimeCounts.keys.toSet();
}

class HouseholdPriorService {
  factory HouseholdPriorService(
    AppDatabase db, {
    DateTime Function()? clock,
    HouseholdPriorDefaults? defaults,
  }) {
    final resolvedDefaults = defaults ?? HouseholdPriorDefaults();
    return HouseholdPriorService._(
      db,
      clock ?? DateTime.now,
      resolvedDefaults,
    );
  }

  HouseholdPriorService._(this._db, this._clock, this.defaults)
      : scorer = HouseholdRankingScorer(defaults);

  final AppDatabase _db;
  final DateTime Function() _clock;
  final HouseholdPriorDefaults defaults;
  final HouseholdRankingScorer scorer;
  final Map<String, _PriorCacheEntry> _cache = {};

  Future<HouseholdPriorContext> baseContext(String groupId) async {
    final now = _clock();
    final cached = _cache[groupId];
    if (cached != null) {
      if (cached.loading case final loading?) return loading;
      final value = cached.value;
      final loadedAt = cached.loadedAt;
      if (value != null &&
          loadedAt != null &&
          now.difference(loadedAt) < defaults.cacheTtl) {
        return value;
      }
    }

    final entry = _PriorCacheEntry();
    final loading = _loadContext(groupId, now);
    entry.loading = loading;
    _cache[groupId] = entry;
    try {
      final value = await loading;
      if (identical(_cache[groupId], entry)) {
        entry
          ..loading = null
          ..value = value
          ..loadedAt = _clock();
      }
      return value;
    } catch (_) {
      if (identical(_cache[groupId], entry)) _cache.remove(groupId);
      rethrow;
    }
  }

  HouseholdPriorFeatures featuresFor(
    String canonicalItemId,
    HouseholdPriorContext context, {
    List<String> listContextIds = const [],
  }) {
    final stats = context._itemStats[canonicalItemId];
    if (stats == null) return const HouseholdPriorFeatures();

    var maxLift = 0.0;
    final candidateCount = context.lifetimeCounts[canonicalItemId] ?? 0;
    if (candidateCount > 0 &&
        context.totalPurchases > 0 &&
        context.vocabularySize > 0) {
      for (final otherId in listContextIds.toSet()) {
        if (otherId == canonicalItemId) continue;
        final otherCount = context.lifetimeCounts[otherId] ?? 0;
        if (otherCount <= 0) continue;
        final pairCount =
            context._pairCounts[_ItemPair.of(canonicalItemId, otherId)] ?? 0;
        if (pairCount <= 0) continue;
        final conditional =
            (pairCount + 1) / (otherCount + context.vocabularySize);
        final marginal = (candidateCount + 1) /
            (context.totalPurchases + context.vocabularySize);
        final lift = math.log(conditional / marginal);
        if (lift > maxLift) maxLift = lift;
      }
    }
    final cooccurrence = maxLift.clamp(0.0, 3.0) / 3.0;
    return HouseholdPriorFeatures(
      familiarity: stats.familiarity,
      dueWeighted: stats.dueWeighted,
      cooccurrence: cooccurrence,
      dayOfWeek: stats.dayOfWeek,
    );
  }

  double priorOnlyScore(HouseholdPriorFeatures features) =>
      scorer.score(GroceryRankingFeatures(prior: features));

  List<ScoredPriorItem> top(
    HouseholdPriorContext context, {
    List<String> listContextIds = const [],
    int limit = 8,
    double? floor,
  }) {
    final threshold = floor ?? defaults.restockFloor;
    final scored = <ScoredPriorItem>[];
    for (final entry in context._itemStats.entries) {
      final features = featuresFor(
        entry.key,
        context,
        listContextIds: listContextIds,
      );
      final score = priorOnlyScore(features);
      if (score < threshold) continue;
      scored.add(ScoredPriorItem(
        canonicalItemId: entry.key,
        score: score,
        features: features,
        estimatedIntervalDays:
            math.max(1, entry.value.estimatedIntervalDays.round()),
        daysSince: entry.value.daysSince,
      ));
    }
    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0
          ? scoreOrder
          : a.canonicalItemId.compareTo(b.canonicalItemId);
    });
    return scored.take(limit).toList(growable: false);
  }

  Future<HouseholdPriorContext> _loadContext(
    String groupId,
    DateTime now,
  ) async {
    final recentSince = now.subtract(
      Duration(days: (defaults.decayDays * 4).round()),
    );
    final results = await Future.wait<Object>([
      _db.getGroupPurchaseHistoryForPrior(
        groupId: groupId,
        since: recentSince,
      ),
      _db.getGroupPurchaseCountsForPrior(groupId: groupId),
      _db.getGroupCooccurrences(groupId: groupId),
    ]);
    final history = results[0] as List<PurchaseHistoryTableData>;
    final lifetimeCounts = results[1] as Map<String, int>;
    final cooccurrences = results[2] as List<ItemCooccurrenceTableData>;

    final cadenceByItem = <String, List<DateTime>>{};
    final recentByItem = <String, List<DateTime>>{};
    for (final row in history) {
      final id = row.canonicalItemId;
      if (id == null) continue;
      cadenceByItem.putIfAbsent(id, () => []).add(row.purchasedAt);
      if (!row.purchasedAt.isBefore(recentSince)) {
        recentByItem.putIfAbsent(id, () => []).add(row.purchasedAt);
      }
    }

    final observedMedianByItem = <String, double>{};
    final gapsByItem = <String, List<double>>{};
    for (final entry in cadenceByItem.entries) {
      final sorted = [...entry.value]..sort();
      if (sorted.length > 10) {
        sorted.removeRange(0, sorted.length - 10);
      }
      entry.value
        ..clear()
        ..addAll(sorted);
      final gaps = <double>[];
      for (var i = 1; i < sorted.length; i++) {
        final days = sorted[i].difference(sorted[i - 1]).inMicroseconds /
            Duration.microsecondsPerDay;
        if (days > 0) gaps.add(days);
      }
      gapsByItem[entry.key] = gaps;
      if (gaps.isNotEmpty) observedMedianByItem[entry.key] = _median(gaps);
    }
    final householdMedian = observedMedianByItem.isEmpty
        ? defaults.fallbackCadenceDays
        : _median(observedMedianByItem.values.toList());

    final itemStats = <String, _PriorItemStats>{};
    for (final entry in cadenceByItem.entries) {
      final id = entry.key;
      final timestamps = [...entry.value]..sort();
      if (timestamps.isEmpty) continue;
      final recent = recentByItem[id] ?? const <DateTime>[];
      var decayedCount = 0.0;
      var purchasesTodayWeekday = 0;
      for (final purchasedAt in recent) {
        final ageDays = math.max(
          0.0,
          now.difference(purchasedAt).inMicroseconds /
              Duration.microsecondsPerDay,
        );
        decayedCount += math.exp(-ageDays / defaults.decayDays);
        if (purchasedAt.toLocal().weekday == now.toLocal().weekday) {
          purchasesTodayWeekday++;
        }
      }
      final familiarity = decayedCount / (decayedCount + 1);
      final gaps = gapsByItem[id] ?? const <double>[];
      final observed = observedMedianByItem[id] ?? householdMedian;
      final estimatedInterval =
          (gaps.length * observed + defaults.shrinkageK * householdMedian) /
              (gaps.length + defaults.shrinkageK);
      final daysSince = math.max(0, now.difference(timestamps.last).inDays);
      final ratio = daysSince / math.max(estimatedInterval, 1);
      final dueness = ratio / (1 + ratio);
      final p = (purchasesTodayWeekday + 1) / (recent.length + 7);
      final dayOfWeek = ((p / (1 / 7) - 1).clamp(0.0, 2.0)) / 2.0;
      itemStats[id] = _PriorItemStats(
        familiarity: familiarity,
        dueWeighted: dueness * familiarity,
        dayOfWeek: dayOfWeek,
        estimatedIntervalDays: estimatedInterval,
        daysSince: daysSince,
      );
    }

    final pairCounts = <_ItemPair, int>{};
    for (final row in cooccurrences) {
      pairCounts[_ItemPair.of(row.itemAId, row.itemBId)] = row.count;
    }
    return HouseholdPriorContext._(
      builtAt: now,
      recentSince: recentSince,
      lifetimeCounts: Map.unmodifiable(lifetimeCounts),
      itemStats: Map.unmodifiable(itemStats),
      pairCounts: Map.unmodifiable(pairCounts),
      totalPurchases: lifetimeCounts.values.fold(0, (a, b) => a + b),
      vocabularySize: lifetimeCounts.length,
    );
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _PriorItemStats {
  const _PriorItemStats({
    required this.familiarity,
    required this.dueWeighted,
    required this.dayOfWeek,
    required this.estimatedIntervalDays,
    required this.daysSince,
  });

  final double familiarity;
  final double dueWeighted;
  final double dayOfWeek;
  final double estimatedIntervalDays;
  final int daysSince;
}

class _ItemPair {
  const _ItemPair(this.a, this.b);

  factory _ItemPair.of(String a, String b) =>
      a.compareTo(b) <= 0 ? _ItemPair(a, b) : _ItemPair(b, a);

  final String a;
  final String b;

  @override
  bool operator ==(Object other) =>
      other is _ItemPair && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

class _PriorCacheEntry {
  Future<HouseholdPriorContext>? loading;
  HouseholdPriorContext? value;
  DateTime? loadedAt;
}
