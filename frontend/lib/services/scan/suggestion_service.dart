import '../../storage/app_database.dart';

/// A single missing-item suggestion derived from co-occurrence data.
class GrocerySuggestion {
  final String canonicalItemId;
  final String displayName;
  final String reason;
  final int score;

  const GrocerySuggestion({
    required this.canonicalItemId,
    required this.displayName,
    required this.reason,
    required this.score,
  });
}

/// Looks up items that are frequently bought alongside the current scan's items
/// but are not already present in the scan result.
class SuggestionService {
  final AppDatabase _db;

  SuggestionService(this._db);

  Future<List<GrocerySuggestion>> suggest({
    required String groupId,
    required List<String> presentCanonicalIds,
    int maxSuggestions = 5,
  }) async {
    if (presentCanonicalIds.isEmpty) return [];

    final presentSet = presentCanonicalIds.toSet();

    // Accumulate weighted scores: candidateId → total co-occurrence count.
    final Map<String, int> scores = {};
    // For the reason string, remember the item that triggered this suggestion.
    final Map<String, String> triggers = {};

    for (final id in presentCanonicalIds) {
      final rows = await _db.getTopCooccurrences(
        groupId: groupId,
        itemId: id,
        limit: 15,
      );
      for (final row in rows) {
        final otherId = row.itemAId == id ? row.itemBId : row.itemAId;
        if (presentSet.contains(otherId)) continue;
        scores[otherId] = (scores[otherId] ?? 0) + row.count;
        triggers.putIfAbsent(otherId, () => id);
      }
    }

    if (scores.isEmpty) return [];

    // Sort candidates by accumulated score.
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final suggestions = <GrocerySuggestion>[];
    for (final entry in sorted.take(maxSuggestions)) {
      final canonical = await _db.getCanonicalItemById(entry.key);
      if (canonical == null) continue;
      final name = canonical.nameDe.isNotEmpty ? canonical.nameDe : canonical.nameEn;
      if (name.isEmpty) continue;

      // Build a human reason from the trigger item.
      String reason = 'often bought together';
      final triggerId = triggers[entry.key];
      if (triggerId != null) {
        final triggerCanonical = await _db.getCanonicalItemById(triggerId);
        if (triggerCanonical != null) {
          final triggerName = triggerCanonical.nameDe.isNotEmpty
              ? triggerCanonical.nameDe
              : triggerCanonical.nameEn;
          if (triggerName.isNotEmpty) {
            reason = 'often with $triggerName';
          }
        }
      }

      suggestions.add(GrocerySuggestion(
        canonicalItemId: entry.key,
        displayName: name[0].toUpperCase() + name.substring(1),
        reason: reason,
        score: entry.value,
      ));
    }
    return suggestions;
  }
}
