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

  /// Minimum edit-distance similarity for a fuzzy alias match. 0.6 tolerates a
  /// typo or two in a full word ("banann" → Banane) without surfacing
  /// unrelated items. Tune in one place.
  static const double _fuzzyFloor = 0.6;

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

    final ranked = <_RankedSuggestion>[];
    final seenIds = <String>{};

    // Adds the given canonical ids (in order) at the given relevance [tier],
    // skipping any already collected. Records insertion order for stable sort.
    Future<void> addByIds(List<String> ids, int tier) async {
      final fresh = ids.where((id) => !seenIds.contains(id)).toList();
      if (fresh.isEmpty) return;
      final items = await _db.getCanonicalItemsByIds(fresh);
      final byId = {for (final it in items) it.id: it};
      for (final id in fresh) {
        final it = byId[id];
        if (it == null) continue;
        if (!seenIds.add(it.id)) continue;
        ranked.add(_RankedSuggestion(
          GrocerySuggestion(
            canonicalItemId: it.id,
            name: _displayName(it, q),
            category: it.category,
            unit: it.defaultUnit,
          ),
          tier,
          ranked.length,
        ));
      }
    }

    // Tier 0 — literal alias/name prefix (partial typing).
    await addByIds(orderedIds, 0);

    // Tier 1 — fuzzy alias: catch typos the prefix misses ("banann" → Banane,
    // "tomaden" → Tomaten). SAME indexed first-char + length-window prefilter as
    // the scanner's resolver, ranked by edit-distance similarity.
    if (ranked.length < limit) {
      final fuzzy = await _db.getAliasFuzzyCandidates(groupId: groupId, query: q);
      final bestSim = <String, double>{};
      for (final a in fuzzy) {
        if (seenIds.contains(a.canonicalItemId)) continue;
        final sim = _similarity(q, a.aliasText);
        if (sim < _fuzzyFloor) continue;
        final cur = bestSim[a.canonicalItemId];
        if (cur == null || sim > cur) bestSim[a.canonicalItemId] = sim;
      }
      final fuzzyIds = bestSim.keys.toList()
        ..sort((x, y) => bestSim[y]!.compareTo(bestSim[x]!));
      await addByIds(fuzzyIds, 1);
    }

    // Tier 2 — semantic: when alias prefix/fuzzy are sparse and an embedder is
    // wired, pad with nearest-neighbour matches (synonyms, differently-spelled
    // terms). Below [_semanticFloor] cosine is dropped so weak items never show.
    if (_embedder != null && ranked.length < limit) {
      final embedMatches = await _embedder.nearest(q, topK: limit * 2);
      final missingIds = embedMatches
          .where((m) => m.score >= _semanticFloor)
          .map((m) => m.itemId)
          .where((id) => !seenIds.contains(id))
          .toList();
      await addByIds(missingIds, 2);
    }

    if (ranked.isEmpty) return const [];

    // Prior-aware ranking: WITHIN each relevance tier, bubble up what THIS
    // household actually buys (purchase-history frequency), then exact
    // name-prefix, then original recall order. Tiers never cross — a fuzzy or
    // semantic match never outranks a clean prefix hit, however frequent. This
    // is the on-device household prior (same signal the scanner ensemble uses),
    // so your staples float to the top as you type.
    final freq = <String, int>{};
    final history = await _db.getGroupPurchaseHistory(groupId: groupId);
    for (final r in history) {
      final id = r.canonicalItemId;
      if (id != null) freq[id] = (freq[id] ?? 0) + 1;
    }
    ranked.sort((a, b) {
      if (a.tier != b.tier) return a.tier.compareTo(b.tier);
      final fa = freq[a.suggestion.canonicalItemId] ?? 0;
      final fb = freq[b.suggestion.canonicalItemId] ?? 0;
      if (fa != fb) return fb.compareTo(fa); // more-bought leads
      final pa = a.suggestion.name.toLowerCase().startsWith(q) ? 0 : 1;
      final pb = b.suggestion.name.toLowerCase().startsWith(q) ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.idx.compareTo(b.idx); // stable: preserve recall order
    });
    return ranked.take(limit).map((r) => r.suggestion).toList();
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

  /// Edit-distance similarity in [0, 1]: 1 - distance / max(len).
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - _levenshtein(a, b) / maxLen;
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

/// A suggestion plus its relevance [tier] (0 prefix, 1 fuzzy, 2 semantic) and
/// insertion order, used to rank by the household prior within tiers.
class _RankedSuggestion {
  final GrocerySuggestion suggestion;
  final int tier;
  final int idx;
  _RankedSuggestion(this.suggestion, this.tier, this.idx);
}
