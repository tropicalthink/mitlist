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
