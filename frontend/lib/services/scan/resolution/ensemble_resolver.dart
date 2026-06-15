import '../../../storage/app_database.dart';
import '../canonical_resolver_service.dart' show ResolveResult;
import '../grocery_classifier_service.dart';
import '../static_embedding_service.dart';
import 'calibrated_scorer.dart';
import 'candidate_generator.dart';
import 'resolution_candidate.dart';
import 'resolution_features.dart';
import 'string_sim.dart';

/// Plan 037 — the genius resolution path.
///
/// generate (union of all sources) → feature vector per candidate → calibrated
/// P(correct) → argmax. Returns the same [ResolveResult] the old sequential
/// resolver does, but the `score` is now a *calibrated* probability, and the
/// choice considers every contender plus the household prior — so a word that
/// collides as an alias of the wrong item no longer wins on an arbitrary tie.
class EnsembleResolver {
  final AppDatabase _db;
  final CandidateGenerator _generator;
  final CalibratedScorer? _injectedScorer;

  /// Cached load of the fitted weights bundle (one load per resolver), used
  /// only when no scorer is injected.
  Future<CalibratedScorer>? _scorerFuture;

  EnsembleResolver(
    this._db, {
    GroceryClassifierService? classifier,
    StaticEmbeddingService? embedder,
    CalibratedScorer? scorer,
    CandidateGenerator? generator,
  })  : _generator = generator ??
            CandidateGenerator(_db, classifier: classifier, embedder: embedder),
        _injectedScorer = scorer;

  Future<CalibratedScorer> _ensureScorer() {
    final injected = _injectedScorer;
    if (injected != null) return Future.value(injected);
    return _scorerFuture ??= CalibratedScorer.load();
  }

  /// Resolves [rawText] for [groupId]. Pass [context] to supply the household
  /// prior explicitly (eval/tests); when omitted it is built from the DB
  /// (purchase history). [listContext] are canonical ids already on the current
  /// list, used for the co-occurrence signal when building from the DB.
  Future<ResolveResult> resolve(
    String rawText,
    String groupId, {
    ResolutionContext? context,
    List<String> listContext = const [],
  }) async {
    final query = normaliseText(rawText);
    final candidates = await _generator.generate(rawText, groupId);
    if (candidates.isEmpty) {
      return ResolveResult(displayName: _titleCase(rawText), score: 0);
    }

    final ctx = context ?? await _buildContext(groupId, listContext);
    final scorer = await _ensureScorer();

    final scored = <_Scored>[];
    for (final c in candidates) {
      final p = scorer.score(buildResolutionFeatures(c, query, ctx));
      scored.add(_Scored(c, p));
    }
    scored.sort((a, b) => b.p.compareTo(a.p));

    final best = scored.first;
    final alternatives =
        scored.skip(1).take(3).map((s) => _preferredName(s.c.item)).toList();

    return ResolveResult(
      canonicalItemId: best.c.canonicalItemId,
      displayName: _preferredName(best.c.item),
      score: best.p,
      alternatives: alternatives,
      autoThreshold: scorer.tauAuto,
      reviewThreshold: scorer.tauReview,
    );
  }

  /// Builds the household prior from purchase history (frequency + recency) and,
  /// when a [listContext] is given, the co-occurrence affinity to the list.
  Future<ResolutionContext> _buildContext(
    String groupId,
    List<String> listContext,
  ) async {
    final history = await _db.getGroupPurchaseHistory(groupId: groupId);
    final counts = <String, int>{};
    final lastAt = <String, DateTime>{};
    for (final row in history) {
      final id = row.canonicalItemId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      final prev = lastAt[id];
      if (prev == null || row.purchasedAt.isAfter(prev)) {
        lastAt[id] = row.purchasedAt;
      }
    }
    final now = DateTime.now();
    final days = {
      for (final e in lastAt.entries)
        e.key: now.difference(e.value).inDays.clamp(0, 1 << 30),
    };

    final cooc = <String, double>{};
    if (listContext.isNotEmpty) {
      var maxC = 0;
      final raw = <String, int>{};
      for (final id in listContext) {
        final rows = await _db.getTopCooccurrences(
            groupId: groupId, itemId: id, limit: 15);
        for (final r in rows) {
          final other = r.itemAId == id ? r.itemBId : r.itemAId;
          raw[other] = (raw[other] ?? 0) + r.count;
          if (raw[other]! > maxC) maxC = raw[other]!;
        }
      }
      if (maxC > 0) {
        for (final e in raw.entries) {
          cooc[e.key] = e.value / maxC;
        }
      }
    }

    return ResolutionContext(
      purchaseCounts: counts,
      daysSinceLastPurchase: days,
      cooccurrence: cooc,
    );
  }

  static String _preferredName(CanonicalItemsTableData item) {
    if (item.nameDe.isNotEmpty) return _titleCase(item.nameDe);
    if (item.nameEn.isNotEmpty) return _titleCase(item.nameEn);
    return item.id;
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Scored {
  final ResolutionCandidate c;
  final double p;
  _Scored(this.c, this.p);
}
