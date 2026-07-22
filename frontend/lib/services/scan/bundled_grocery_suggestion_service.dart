import 'dart:convert';

import 'package:flutter/services.dart';

import 'grocery_suggestion_service.dart';
import 'resolution/string_sim.dart';

const _autocompleteAsset = 'assets/grocery/autocomplete.json';

/// Fast cold-start autocomplete over canonical names from the bundled seed.
///
/// The full alias catalog is imported into Drift in the background. This uses a
/// compact, pre-sorted build artifact so it neither decodes the 5.3 MB seed a
/// second time nor linearly scans every name for each keystroke.
class BundledGrocerySuggestionService {
  Future<List<_BundledGroceryName>>? _namesFuture;

  Future<List<GrocerySuggestion>> suggest(
    String query, {
    int limit = 8,
  }) async {
    final q = normaliseText(query);
    if (q.length < 2) return const [];

    final names = await (_namesFuture ??= _loadNames());
    final results = <GrocerySuggestion>[];
    final seen = <String>{};
    for (var index = _lowerBound(names, q); index < names.length; index++) {
      final entry = names[index];
      if (!entry.normalizedName.startsWith(q)) break;
      if (!seen.add(entry.id)) continue;
      results.add(GrocerySuggestion(
        canonicalItemId: entry.id,
        name: entry.name,
        category: entry.category,
        unit: entry.unit,
      ));
      if (results.length == limit) break;
    }
    return results;
  }

  /// Finds OCR-tolerant canonical names without assuming the first character
  /// was recognized correctly.
  ///
  /// The database hot path deliberately uses a first-character index. That is
  /// ideal for typed input but misses handwriting confusions such as
  /// `Aliverol` → `Olivenöl`. This compact 12k-name asset is small enough for a
  /// bounded fallback scan when the indexed resolver has weak candidates.
  Future<List<BundledGroceryMatch>> nearest(
    String query, {
    int limit = 5,
    double minimumSimilarity = 0.60,
  }) async {
    final q = normaliseText(query);
    if (q.length < 3 || limit < 1) return const [];
    final names = await (_namesFuture ??= _loadNames());
    final bestById = <String, BundledGroceryMatch>{};
    final maximumLengthDelta = (q.length * 0.35).ceil().clamp(2, 8);
    for (final entry in names) {
      if ((entry.normalizedName.length - q.length).abs() > maximumLengthDelta) {
        continue;
      }
      final similarity = stringSimilarity(q, entry.normalizedName);
      if (similarity < minimumSimilarity) continue;
      final current = bestById[entry.id];
      if (current == null || similarity > current.similarity) {
        bestById[entry.id] = BundledGroceryMatch(
          canonicalItemId: entry.id,
          similarity: similarity,
        );
      }
    }
    final ranked = bestById.values.toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));
    return ranked.take(limit).toList(growable: false);
  }

  Future<List<_BundledGroceryName>> _loadNames() async {
    final raw = await rootBundle.loadString(_autocompleteAsset);
    return _decodeNames(raw);
  }

  static int _lowerBound(List<_BundledGroceryName> names, String query) {
    var low = 0;
    var high = names.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (names[mid].normalizedName.compareTo(query) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

class BundledGroceryMatch {
  const BundledGroceryMatch({
    required this.canonicalItemId,
    required this.similarity,
  });

  final String canonicalItemId;
  final double similarity;
}

class _BundledGroceryName {
  const _BundledGroceryName({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.category,
    required this.unit,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String category;
  final String unit;
}

List<_BundledGroceryName> _decodeNames(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (json['entries'] as List).map((rawEntry) {
    final entry = rawEntry as List;
    return _BundledGroceryName(
      normalizedName: entry[0] as String,
      id: entry[1] as String,
      name: entry[2] as String,
      category: entry[3] as String,
      unit: entry[4] as String,
    );
  }).toList(growable: false);
}
