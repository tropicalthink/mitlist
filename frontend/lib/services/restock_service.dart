import 'package:flutter/foundation.dart' show visibleForTesting;

import '../storage/app_database.dart';
import 'canonical_display.dart';
import 'household_prior_service.dart';

enum RestockReason { due, usual, goesWith }

class RestockSuggestion {
  const RestockSuggestion({
    required this.canonicalItemId,
    required this.name,
    required this.intervalDays,
    required this.daysSince,
    this.reason = RestockReason.usual,
  });

  final String canonicalItemId;
  final String name;

  /// Posterior cadence estimate, shrunk toward the household median.
  final int intervalDays;

  final int daysSince;
  final RestockReason reason;

  int get overdueDays => daysSince - intervalDays;
}

/// Ranks the household's purchase repertoire using the shared household prior.
class RestockService {
  RestockService(this._db, {required HouseholdPriorService prior})
      : _prior = prior;

  final AppDatabase _db;
  final HouseholdPriorService _prior;

  @visibleForTesting
  HouseholdPriorService get priorService => _prior;

  Future<List<RestockSuggestion>> due({
    required String groupId,
    Set<String> currentItemNames = const {},
    Set<String> currentCanonicalIds = const {},
    List<String> listContextIds = const [],
    int limit = 8,
  }) async {
    if (limit <= 0) return const [];
    final context = await _prior.baseContext(groupId);
    final ranked = _prior.top(
      context,
      listContextIds: listContextIds,
      limit: context.repertoireIds.length,
    );
    if (ranked.isEmpty) return const [];

    final items = await _db.getCanonicalItemsByIds(
      ranked.map((entry) => entry.canonicalItemId),
    );
    final nameById = {
      for (final item in items) item.id: _displayName(item),
    };
    final normalizedCurrent =
        currentItemNames.map((name) => name.toLowerCase().trim()).toSet();
    final suggestions = <RestockSuggestion>[];
    for (final entry in ranked) {
      final name = nameById[entry.canonicalItemId] ?? entry.canonicalItemId;
      if (normalizedCurrent.contains(name.toLowerCase()) ||
          currentCanonicalIds.contains(entry.canonicalItemId)) {
        continue;
      }
      // Bought within the first quarter of its usual interval (today, for a
      // weekly item): suggesting it again would be noise.
      if (entry.daysSince * 4 < entry.estimatedIntervalDays) continue;
      suggestions.add(RestockSuggestion(
        canonicalItemId: entry.canonicalItemId,
        name: name,
        intervalDays: entry.estimatedIntervalDays,
        daysSince: entry.daysSince,
        reason: _reason(entry),
      ));
      if (suggestions.length == limit) break;
    }
    return suggestions;
  }

  RestockReason _reason(ScoredPriorItem entry) {
    // "Due" is about the item's own rhythm: it has been at least one usual
    // interval since the last purchase. (Comparing score contributions could
    // never pick it: dueWeighted is dueness × familiarity, so it is always at
    // most the familiarity term it was weighed against.)
    final features = entry.features;
    final weights = _prior.defaults;
    final usualContribution = weights.familiarityWeight * features.familiarity +
        weights.dayOfWeekWeight * features.dayOfWeek;
    final cooccurrenceContribution =
        weights.cooccurrenceWeight * features.cooccurrence;
    if (cooccurrenceContribution > usualContribution) {
      return RestockReason.goesWith;
    }
    if (entry.daysSince >= entry.estimatedIntervalDays) {
      return RestockReason.due;
    }
    return RestockReason.usual;
  }

  @visibleForTesting
  static Duration? medianInterval(List<DateTime> timestamps) {
    if (timestamps.length < 3) return null;
    final gaps = <Duration>[];
    for (var i = 1; i < timestamps.length; i++) {
      gaps.add(timestamps[i].difference(timestamps[i - 1]));
    }
    gaps.sort((a, b) => a.compareTo(b));
    return gaps[gaps.length ~/ 2];
  }

  static String _displayName(CanonicalItemsTableData item) =>
      _capitalize(canonicalDisplayName(item));

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
