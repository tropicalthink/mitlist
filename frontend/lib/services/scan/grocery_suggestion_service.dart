import '../../storage/app_database.dart';
import 'static_embedding_service.dart';

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
  final StaticEmbeddingService? _embedder;

  /// Minimum cosine for a semantic (embedder) match to be surfaced. Real
  /// in-catalog queries score ~0.7–1.0; this floor drops weakly-related items
  /// while keeping genuine synonym/spelling matches. Tune in one place.
  static const double _semanticFloor = 0.5;

  /// Creates a suggestion service.
  ///
  /// The optional [embedder] argument enables semantic blending when alias-prefix
  /// matching yields few results. Existing call sites that omit it keep compiling
  /// and behave exactly as before.
  GrocerySuggestionService(this._db, {StaticEmbeddingService? embedder})
      : _embedder = embedder;

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

    // Keep the first matching alias per canonical item; its language decides
    // which name we label the suggestion with (so "milch" → Milch, "milk" →
    // Milk for the same canonical item).
    // Collapse alias hits to distinct canonical items, preserving order.
    final orderedIds = <String>[];
    final seen = <String>{};
    for (final a in aliases) {
      if (seen.add(a.canonicalItemId)) orderedIds.add(a.canonicalItemId);
    }

    final out = <GrocerySuggestion>[];
    if (orderedIds.isNotEmpty) {
      final items = await _db.getCanonicalItemsByIds(orderedIds);
      final byId = {for (final it in items) it.id: it};

      for (final id in orderedIds) {
        final it = byId[id];
        if (it == null) continue;
        out.add(GrocerySuggestion(
          canonicalItemId: it.id,
          name: _displayName(it, q),
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
    }

    // Semantic blending: whenever alias-prefix is sparse (including ZERO literal
    // hits) and an embedder is wired, pad with nearest-neighbour matches. This
    // is what lets a synonym or differently-spelled term resolve when no alias
    // starts with the query — the common case the alias prefix alone misses.
    // Matches below [_semanticFloor] cosine are dropped so weak/unrelated items
    // never surface (pure-nonsense queries already yield no tokens → no matches).
    if (_embedder != null && out.length < limit) {
      final seenIds = {for (final s in out) s.canonicalItemId};
      final embedMatches = await _embedder.nearest(q, topK: limit * 2);
      final missingIds = embedMatches
          .where((m) => m.score >= _semanticFloor)
          .map((m) => m.itemId)
          .where((id) => !seenIds.contains(id))
          .toList();
      if (missingIds.isNotEmpty) {
        final extraItems = await _db.getCanonicalItemsByIds(missingIds);
        final byId = {for (final it in extraItems) it.id: it};
        for (final id in missingIds) {
          if (out.length >= limit) break;
          final it = byId[id];
          if (it == null) continue;
          out.add(GrocerySuggestion(
            canonicalItemId: it.id,
            name: _displayName(it, q),
            category: it.category,
            unit: it.defaultUnit,
          ));
        }
      }
    }

    return out.take(limit).toList();
  }

  /// Labels a suggestion in the language the user typed. We can't trust the
  /// matched alias's stored `lang` — the seed cross-links each item's English
  /// and German spellings under both languages — so we infer intent directly
  /// from the query: whichever of the two canonical names the typed text is
  /// closer to wins. English is the default on a tie or when a name is missing.
  static String _displayName(CanonicalItemsTableData it, String query) {
    final en = it.nameEn;
    final de = it.nameDe;
    if (en.isEmpty) return _cap(de.isEmpty ? it.id : de);
    if (de.isEmpty) return _cap(en);

    final base = _closerToQuery(query, en, de) ? en : de;
    return _cap(base);
  }

  /// True when [query] is closer to [en] than to [de]. A prefix relation
  /// counts as the best possible match; otherwise we fall back to edit
  /// distance. Ties resolve to English (the `<=`).
  static bool _closerToQuery(String query, String en, String de) {
    final scoreEn = _matchScore(query, en.toLowerCase());
    final scoreDe = _matchScore(query, de.toLowerCase());
    return scoreEn <= scoreDe;
  }

  static int _matchScore(String query, String name) {
    if (name.startsWith(query) || query.startsWith(name)) return 0;
    return _levenshtein(query, name);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((m, e) => e < m ? e : m);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
