import 'package:flutter/foundation.dart' show visibleForTesting;

import '../storage/app_database.dart';
import 'canonical_display.dart';

/// A single item predicted to need restocking based on past purchase cadence.
class RestockSuggestion {
  const RestockSuggestion({
    required this.canonicalItemId,
    required this.name,
    required this.intervalDays,
    required this.daysSince,
  });

  final String canonicalItemId;

  /// Display name resolved from the canonical-items table.
  final String name;

  /// Median purchase interval in days (computed from ≥ 3 purchase timestamps).
  final int intervalDays;

  /// Days elapsed since the last purchase.
  final int daysSince;

  /// How many days overdue this item is (negative means not yet due).
  int get overdueDays => daysSince - intervalDays;
}

/// On-device, zero-network service that predicts which grocery items are due
/// for restocking based on the household's own purchase-history cadence.
///
/// Algorithm (phase 1):
/// 1. Load all purchase-history rows for the group in one query.
/// 2. Group rows by [canonicalItemId].
/// 3. For each item with ≥ 3 timestamped purchases, compute the **median gap**
///    between consecutive purchase events.
/// 4. An item is "due" when `now − lastPurchase ≥ medianInterval`.
/// 5. Results are sorted by how overdue they are (most overdue first).
class RestockService {
  RestockService(this._db);

  final AppDatabase _db;

  /// Returns items predicted to need restocking for [groupId].
  ///
  /// [now] defaults to [DateTime.now()] and is injectable for testing.
  /// [currentItemNames] is the set of item names already on the open list
  /// (lowercased); matching items are excluded from results.
  Future<List<RestockSuggestion>> due({
    required String groupId,
    DateTime? now,
    Set<String> currentItemNames = const {},
    int limit = 8,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    // 1. Fetch all purchase history for the group (one query, no N+1).
    final rows = await _db.getGroupPurchaseHistory(groupId: groupId);

    // 2. Group timestamps by canonicalItemId.
    final Map<String, List<DateTime>> byItem = {};
    for (final row in rows) {
      final id = row.canonicalItemId;
      if (id == null) continue;
      byItem.putIfAbsent(id, () => []).add(row.purchasedAt);
    }

    // 3. Compute median interval for each item and filter to "due" ones.
    final candidates = <RestockSuggestion>[];
    for (final entry in byItem.entries) {
      final id = entry.key;
      final timestamps = entry.value;

      // Ensure chronological order (DB returns newest-first).
      final sorted = [...timestamps]..sort((a, b) => a.compareTo(b));

      final interval = medianInterval(sorted);
      if (interval == null) continue; // < 3 purchases → skip

      final lastPurchase = sorted.last;
      final daysSince = effectiveNow.difference(lastPurchase).inDays;
      final intervalDays = interval.inDays;

      if (intervalDays <= 0) continue;
      if (daysSince < intervalDays) continue; // not yet due

      candidates.add(RestockSuggestion(
        canonicalItemId: id,
        name: id, // resolved below
        intervalDays: intervalDays,
        daysSince: daysSince,
      ));
    }

    if (candidates.isEmpty) return const [];

    // 4. Resolve display names from canonical-items table.
    final ids = candidates.map((c) => c.canonicalItemId).toList();
    final items = await _db.getCanonicalItemsByIds(ids);
    final nameById = {
      for (final it in items) it.id: _displayName(it),
    };

    // 5. Filter out items already on the current open list.
    final resolved = candidates
        .where((c) {
          final name = nameById[c.canonicalItemId] ?? c.canonicalItemId;
          return !currentItemNames.contains(name.toLowerCase());
        })
        .map((c) => RestockSuggestion(
              canonicalItemId: c.canonicalItemId,
              name: nameById[c.canonicalItemId] ?? c.canonicalItemId,
              intervalDays: c.intervalDays,
              daysSince: c.daysSince,
            ))
        .toList();

    // 6. Sort most overdue first, then cap.
    resolved.sort((a, b) => b.overdueDays.compareTo(a.overdueDays));
    return resolved.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Pure, testable helpers
  // ---------------------------------------------------------------------------

  /// Computes the median duration between consecutive purchases.
  ///
  /// Returns `null` when [timestamps] has fewer than 3 entries (not enough
  /// history to establish a reliable cadence).
  ///
  /// [timestamps] must be sorted in ascending (oldest-first) order.
  @visibleForTesting
  static Duration? medianInterval(List<DateTime> timestamps) {
    if (timestamps.length < 3) return null;

    final gaps = <Duration>[];
    for (var i = 1; i < timestamps.length; i++) {
      gaps.add(timestamps[i].difference(timestamps[i - 1]));
    }
    // Sort gaps to find the median.
    gaps.sort((a, b) => a.compareTo(b));
    return gaps[gaps.length ~/ 2];
  }

  static String _displayName(CanonicalItemsTableData it) =>
      _cap(canonicalDisplayName(it));

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
