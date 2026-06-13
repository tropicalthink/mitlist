import '../../storage/app_database.dart';
import 'grocery_classifier_service.dart';

/// Result of a canonical resolution attempt.
class ResolveResult {
  final String? canonicalItemId;
  final String displayName;
  final double score; // 0–1
  final List<String> alternatives;

  const ResolveResult({
    this.canonicalItemId,
    required this.displayName,
    required this.score,
    this.alternatives = const [],
  });
}

/// Resolves an extracted item name to a canonical item in the grocery graph.
///
/// Lookup order:
///  1. Exact alias match (household scope first, then global seed).
///  2. Fuzzy alias match (normalised edit distance).
///  3. Optional on-device classifier fallback when fuzzy confidence < 0.85.
///  4. No match → returns the cleaned name as-is with score 0.
///
/// The [classifier] argument is optional; existing call sites that omit it
/// keep compiling and behave exactly as before.
class CanonicalResolverService {
  final AppDatabase _db;
  final GroceryClassifierService? _classifier;

  CanonicalResolverService(this._db, {GroceryClassifierService? classifier})
      : _classifier = classifier;

  Future<ResolveResult> resolve(String itemName, String groupId) async {
    final normalised = _normalise(itemName);
    if (normalised.isEmpty) {
      return ResolveResult(displayName: itemName, score: 0);
    }

    // 1. Exact alias lookup (household aliases override global).
    final exact = await _db.findAlias(groupId: groupId, aliasText: normalised);
    if (exact != null) {
      final canonical = await _db.getCanonicalItemById(exact.canonicalItemId);
      if (canonical != null) {
        final name = _preferredName(canonical);
        return ResolveResult(
          canonicalItemId: canonical.id,
          displayName: name,
          score: 1.0,
        );
      }
    }

    // 2. Fuzzy match against an indexed candidate set (same first char,
    //    similar length) rather than the full ~120k-row alias table.
    final allAliases = await _db.getAliasFuzzyCandidates(
      groupId: groupId,
      query: normalised,
    );
    if (allAliases.isEmpty) {
      final fuzzyResult =
          ResolveResult(displayName: _titleCase(itemName), score: 0);
      return _resolveWithFallback(itemName, groupId, fuzzyResult);
    }

    _AliasMatch? best;
    _AliasMatch? second;

    for (final alias in allAliases) {
      final dist = _normalisedEditDistance(normalised, alias.aliasText);
      final score = 1.0 - dist;
      if (best == null || score > best.score) {
        second = best;
        best = _AliasMatch(alias: alias, score: score);
      } else if (second == null || score > second.score) {
        second = _AliasMatch(alias: alias, score: score);
      }
    }

    if (best == null || best.score < 0.5) {
      final fuzzyResult =
          ResolveResult(displayName: _titleCase(itemName), score: 0);
      return _resolveWithFallback(itemName, groupId, fuzzyResult);
    }

    final canonical = await _db.getCanonicalItemById(best.alias.canonicalItemId);
    if (canonical == null) {
      final fuzzyResult =
          ResolveResult(displayName: _titleCase(itemName), score: 0);
      return _resolveWithFallback(itemName, groupId, fuzzyResult);
    }

    final alternatives = <String>[];
    if (second != null && second.score >= 0.5) {
      final alt = await _db.getCanonicalItemById(second.alias.canonicalItemId);
      if (alt != null) alternatives.add(_preferredName(alt));
    }

    final fuzzyResult = ResolveResult(
      canonicalItemId: canonical.id,
      displayName: _preferredName(canonical),
      score: best.score,
      alternatives: alternatives,
    );
    return _resolveWithFallback(itemName, groupId, fuzzyResult);
  }

  /// Attempts to improve [fuzzyResult] using the on-device classifier.
  ///
  /// Returns [fuzzyResult] unchanged when:
  /// - no classifier is wired, or
  /// - fuzzy confidence is already ≥ 0.85, or
  /// - the classifier returns no predictions, or
  /// - the top prediction score < 0.85, or
  /// - the predicted label cannot be resolved to a canonical item.
  Future<ResolveResult> _resolveWithFallback(
    String itemName,
    String groupId,
    ResolveResult fuzzyResult,
  ) async {
    if (_classifier == null || fuzzyResult.score >= 0.85) return fuzzyResult;

    final preds = await _classifier.classify(itemName, topK: 5);
    if (preds.isEmpty) return fuzzyResult;

    final top = preds.first;
    if (top.score < 0.85) return fuzzyResult;

    // Map the predicted label back via the alias table.
    final alias = await _db.findAlias(
      groupId: groupId,
      aliasText: _normalise(top.label),
    );
    if (alias == null) return fuzzyResult;

    final canonical = await _db.getCanonicalItemById(alias.canonicalItemId);
    if (canonical == null) return fuzzyResult;

    // Only override if the model is more confident than the fuzzy result.
    if (top.score <= fuzzyResult.score) return fuzzyResult;

    final altNames = preds
        .skip(1)
        .map((p) => p.label)
        .toList();

    return ResolveResult(
      canonicalItemId: canonical.id,
      displayName: _preferredName(canonical),
      score: top.score,
      alternatives: altNames,
    );
  }

  String _preferredName(CanonicalItemsTableData item) {
    // Prefer German name (first market) falling back to English.
    if (item.nameDe.isNotEmpty) return _titleCase(item.nameDe);
    if (item.nameEn.isNotEmpty) return _titleCase(item.nameEn);
    return item.id;
  }

  static String _normalise(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Normalised edit distance in [0, 1].
  static double _normalisedEditDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return 1;
    final maxLen = a.length > b.length ? a.length : b.length;
    return _editDistance(a, b) / maxLen;
  }

  static int _editDistance(String s, String t) {
    final m = s.length, n = t.length;
    final d = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) { d[i][0] = i; }
    for (var j = 0; j <= n; j++) { d[0][j] = j; }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return d[m][n];
  }
}

class _AliasMatch {
  final ItemAliasesTableData alias;
  final double score;
  _AliasMatch({required this.alias, required this.score});
}
