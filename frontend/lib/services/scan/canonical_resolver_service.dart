import '../../storage/app_database.dart';
import '../canonical_display.dart';
import 'grocery_classifier_service.dart';
import 'resolution/ensemble_resolver.dart';
import 'static_embedding_service.dart';

/// Result of a canonical resolution attempt.
class ResolveResult {
  final String? canonicalItemId;
  final String displayName;
  final double score; // 0–1
  final List<String> alternatives;
  final double? autoThreshold;
  final double? reviewThreshold;

  const ResolveResult({
    this.canonicalItemId,
    required this.displayName,
    required this.score,
    this.alternatives = const [],
    this.autoThreshold,
    this.reviewThreshold,
  });
}

/// Resolves an extracted item name to a canonical item in the grocery graph.
///
/// Lookup order:
///  1. Exact alias match (household scope first, then global seed).
///  2. Fuzzy alias match (normalised edit distance).
///  3. Optional on-device classifier fallback when fuzzy confidence < 0.85.
///  4. Optional semantic embedder fallback when classifier also misses.
///  5. No match → returns the cleaned name as-is with score 0.
///
/// The [classifier] and [embedder] arguments are optional; existing call sites
/// that omit them keep compiling and behave exactly as before.
///
/// When [useEnsemble] is true (plan 037), `resolve` delegates to the
/// [EnsembleResolver] — candidate-union + calibrated scoring + household prior,
/// which returns a *calibrated* score and stops confidently auto-accepting the
/// wrong item on alias collisions. The flag defaults **off** so behaviour is
/// unchanged until the eval proves the new path on real data.
class CanonicalResolverService {
  final AppDatabase _db;
  final GroceryClassifierService? _classifier;
  final StaticEmbeddingService? _embedder;
  final bool _useEnsemble;
  EnsembleResolver? _ensemble;

  CanonicalResolverService(
    this._db, {
    GroceryClassifierService? classifier,
    StaticEmbeddingService? embedder,
    bool useEnsemble = false,
  })  : _classifier = classifier,
        _embedder = embedder,
        _useEnsemble = useEnsemble;

  Future<ResolveResult> resolve(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
  }) async {
    if (_useEnsemble) {
      _ensemble ??= EnsembleResolver(
        _db,
        classifier: _classifier,
        embedder: _embedder,
      );
      return _ensemble!.resolve(
        itemName,
        groupId,
        listContext: listContext,
      );
    }

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

    final canonical =
        await _db.getCanonicalItemById(best.alias.canonicalItemId);
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

  /// Attempts to improve [fuzzyResult] using the on-device classifier, then
  /// the semantic embedder, in that order.
  ///
  /// Returns [fuzzyResult] unchanged when:
  /// - fuzzy confidence is already ≥ 0.85, or
  /// - neither classifier nor embedder is wired, or
  /// - the classifier/embedder both produce no useful result.
  Future<ResolveResult> _resolveWithFallback(
    String itemName,
    String groupId,
    ResolveResult fuzzyResult,
  ) async {
    if (fuzzyResult.score >= 0.85) return fuzzyResult;

    // Step A: classifier fallback (Plan 026 behaviour, unchanged).
    if (_classifier != null) {
      final preds = await _classifier.classify(itemName, topK: 5);
      if (preds.isNotEmpty) {
        final top = preds.first;
        if (top.score >= 0.85) {
          final alias = await _db.findAlias(
            groupId: groupId,
            aliasText: _normalise(top.label),
          );
          if (alias != null) {
            final canonical =
                await _db.getCanonicalItemById(alias.canonicalItemId);
            if (canonical != null && top.score > fuzzyResult.score) {
              return ResolveResult(
                canonicalItemId: canonical.id,
                displayName: _preferredName(canonical),
                score: top.score,
                alternatives: preds.skip(1).map((p) => p.label).toList(),
              );
            }
          }
        }
      }
    }

    // Step B: semantic embedder fallback (Plan 028, new).
    // Only attempted when the embedder is wired and fuzzy+classifier both
    // produced low confidence (< 0.85).
    if (_embedder != null) {
      final matches = await _embedder.nearest(itemName, topK: 1);
      if (matches.isNotEmpty) {
        final top = matches.first;
        // Only override when semantic score is meaningfully better.
        if (top.score > fuzzyResult.score) {
          final canonical = await _db.getCanonicalItemById(top.itemId);
          if (canonical != null) {
            return ResolveResult(
              canonicalItemId: canonical.id,
              displayName: _preferredName(canonical),
              score: top.score,
            );
          }
        }
      }
    }

    return fuzzyResult;
  }

  String _preferredName(CanonicalItemsTableData item) =>
      _titleCase(canonicalDisplayName(item));

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
    for (var i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      d[0][j] = j;
    }
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
