import '../../storage/app_database.dart';

/// A canonical grocery item surfaced as a typed-entry autocomplete suggestion.
class GrocerySuggestion {
  final String canonicalItemId;
  final String name; // display name (German preferred, first market)
  final String category; // coarse aisle label
  final String unit;

  const GrocerySuggestion({
    required this.canonicalItemId,
    required this.name,
    required this.category,
    required this.unit,
  });
}

/// Local, offline autocomplete over the canonical grocery graph.
///
/// Matches the typed prefix against the alias table (which carries handwriting
/// shorthand, OCR confusions and typos from the seed), so "mlch" resolves to
/// Milch without a network call. Results are de-duplicated to one row per
/// canonical item and ranked so that canonical-name matches lead alias matches.
class GrocerySuggestionService {
  final AppDatabase _db;

  GrocerySuggestionService(this._db);

  Future<List<GrocerySuggestion>> suggest(
    String query,
    String groupId, {
    int limit = 8,
  }) async {
    final q = query.toLowerCase().trim();
    if (q.length < 2) return const [];

    // Over-fetch alias matches, then collapse to distinct canonical items.
    final aliases = await _db.searchAliasPrefix(
      groupId: groupId,
      query: q,
      limit: limit * 6,
    );
    if (aliases.isEmpty) return const [];

    final orderedIds = <String>[];
    final seen = <String>{};
    for (final a in aliases) {
      if (seen.add(a.canonicalItemId)) orderedIds.add(a.canonicalItemId);
    }

    final items = await _db.getCanonicalItemsByIds(orderedIds);
    final byId = {for (final it in items) it.id: it};

    final out = <GrocerySuggestion>[];
    for (final id in orderedIds) {
      final it = byId[id];
      if (it == null) continue;
      out.add(GrocerySuggestion(
        canonicalItemId: it.id,
        name: _displayName(it),
        category: it.category,
        unit: it.defaultUnit,
      ));
    }

    // Promote items whose own name starts with the query above pure alias hits.
    out.sort((a, b) {
      final an = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bn = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      return an.compareTo(bn);
    });

    return out.take(limit).toList();
  }

  static String _displayName(CanonicalItemsTableData it) {
    final base = it.nameDe.isNotEmpty ? it.nameDe : it.nameEn;
    if (base.isEmpty) return it.id;
    return base[0].toUpperCase() + base.substring(1);
  }
}
