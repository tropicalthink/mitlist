import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../storage/app_database.dart';
import '../canonical_display.dart';
import '../household_prior_service.dart';
import 'resolution/string_sim.dart';
import 'static_embedding_service.dart';

enum GrocerySuggestionContext {
  shoppingList,
  nonShoppingList,
  recipe,
  product,
  choreSupply,
}

extension on GrocerySuggestionContext {
  bool get usesPrior => this != GrocerySuggestionContext.nonShoppingList;
}

/// A canonical grocery item surfaced as a typed-entry autocomplete suggestion.
class GrocerySuggestion {
  final String canonicalItemId;
  final String name;
  final String category;
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
/// Retrieval is a bounded union of exact, prefix, fuzzy, and warm-semantic
/// candidates. One continuous scorer then combines lexical evidence with the
/// household's cached purchase prior; exact aliases and names are pinned first.
class GrocerySuggestionService {
  GrocerySuggestionService(
    this._db, {
    required HouseholdPriorService prior,
    StaticEmbeddingService? embedder,
  })  : _prior = prior,
        _embedder = embedder;

  final AppDatabase _db;
  final HouseholdPriorService _prior;
  final StaticEmbeddingService? _embedder;

  static const double _semanticFloor = 0.5;
  static const double _fuzzyFloor = 0.6;

  @visibleForTesting
  HouseholdPriorService get priorService => _prior;

  Future<List<GrocerySuggestion>> suggest(
    String query,
    String groupId, {
    required GrocerySuggestionContext suggestionContext,
    List<String> listContextIds = const [],
    int limit = 8,
  }) async {
    final q = normaliseText(query);
    if (q.isEmpty || limit <= 0) return const [];
    if (q.length == 1) {
      if (suggestionContext != GrocerySuggestionContext.shoppingList) {
        return const [];
      }
      return _suggestFromRepertoire(
        q,
        groupId,
        listContextIds: listContextIds,
        limit: limit,
      );
    }

    final priorContextFuture = suggestionContext.usesPrior
        ? _prior.baseContext(groupId)
        : Future<HouseholdPriorContext?>.value(null);

    Future<List<EmbedMatch>> semanticFuture = Future.value(const []);
    final embedder = _embedder;
    if (embedder != null) {
      if (embedder.isReady) {
        semanticFuture = embedder
            .nearest(q, topK: limit * 4)
            .catchError((_) => const <EmbedMatch>[]);
      } else {
        unawaited(embedder.warmUp());
      }
    }

    final results = await Future.wait<Object?>([
      _db.findAlias(groupId: groupId, aliasText: q),
      _db.searchAliasPrefix(groupId: groupId, query: q, limit: limit * 6),
      _db.searchAliasWordPrefix(
        groupId: groupId,
        query: q,
        limit: limit * 8,
      ),
      _db.getAliasFuzzyCandidates(
        groupId: groupId,
        query: q,
        maxCandidates: 400,
      ),
      semanticFuture,
      priorContextFuture,
    ]);

    final exactAlias = results[0] as ItemAliasesTableData?;
    final prefixAliases = results[1] as List<ItemAliasesTableData>;
    final wordAliases = results[2] as List<ItemAliasesTableData>;
    final fuzzyAliases = results[3] as List<ItemAliasesTableData>;
    final semanticMatches = results[4] as List<EmbedMatch>;
    final priorContext = results[5] as HouseholdPriorContext?;

    var nextIndex = 0;
    final candidates = <String, _CandidateEvidence>{};
    _CandidateEvidence candidate(String id) => candidates.putIfAbsent(
          id,
          () => _CandidateEvidence(id, nextIndex++),
        );

    void mergeAlias(ItemAliasesTableData alias) {
      final evidence = candidate(alias.canonicalItemId);
      final text = normaliseText(alias.aliasText);
      if (text.isEmpty) return;
      evidence.matchedAliases.add(text);
      if (text == q) evidence.isExact = true;
      if (text.startsWith(q)) evidence.lexPrefix = 1;
      final similarity = stringSimilarity(q, text);
      if (similarity > evidence.lexSim) evidence.lexSim = similarity;
    }

    if (exactAlias != null) mergeAlias(exactAlias);
    for (final alias in prefixAliases) {
      mergeAlias(alias);
    }
    for (final alias in wordAliases) {
      mergeAlias(alias);
    }

    final bestFuzzy = <String, ({ItemAliasesTableData alias, double score})>{};
    for (final alias in fuzzyAliases) {
      final score = stringSimilarity(q, normaliseText(alias.aliasText));
      if (score < _fuzzyFloor) continue;
      final previous = bestFuzzy[alias.canonicalItemId];
      if (previous == null || score > previous.score) {
        bestFuzzy[alias.canonicalItemId] = (alias: alias, score: score);
      }
    }
    final fuzzyBest = bestFuzzy.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final match in fuzzyBest.take(limit * 8)) {
      mergeAlias(match.alias);
    }

    for (final match in semanticMatches) {
      if (match.score < _semanticFloor) continue;
      final evidence = candidate(match.itemId);
      final score = match.score.clamp(0.0, 1.0);
      if (score > evidence.lexSemantic) evidence.lexSemantic = score;
    }

    if (candidates.isEmpty) return const [];
    final items = await _db.getCanonicalItemsByIds(candidates.keys);
    final itemsById = {for (final item in items) item.id: item};
    candidates.removeWhere((id, _) => !itemsById.containsKey(id));
    for (final entry in candidates.entries) {
      final item = itemsById[entry.key]!;
      for (final name in _canonicalNames(item)) {
        final normalized = normaliseText(name);
        if (normalized == q) entry.value.isExact = true;
        if (normalized.startsWith(q)) entry.value.lexPrefix = 1;
        final similarity = stringSimilarity(q, normalized);
        if (similarity > entry.value.lexSim) {
          entry.value.lexSim = similarity;
        }
      }
    }

    return _rankCandidates(
      q,
      candidates.values,
      itemsById,
      priorContext: priorContext,
      listContextIds: listContextIds,
      limit: limit,
    );
  }

  Future<List<GrocerySuggestion>> _suggestFromRepertoire(
    String query,
    String groupId, {
    required List<String> listContextIds,
    required int limit,
  }) async {
    final context = await _prior.baseContext(groupId);
    if (context.repertoireIds.isEmpty) return const [];
    final items = await _db.getCanonicalItemsByIds(context.repertoireIds);
    final itemsById = {for (final item in items) item.id: item};
    var index = 0;
    final candidates = <_CandidateEvidence>[];
    for (final item in items) {
      final evidence = _CandidateEvidence(item.id, index++);
      for (final name in _canonicalNames(item)) {
        final normalized = normaliseText(name);
        if (!normalized.startsWith(query)) continue;
        evidence.lexPrefix = 1;
        evidence.lexSim = evidence.lexSim > stringSimilarity(query, normalized)
            ? evidence.lexSim
            : stringSimilarity(query, normalized);
        if (normalized == query) evidence.isExact = true;
      }
      if (evidence.lexPrefix > 0) candidates.add(evidence);
    }
    return _rankCandidates(
      query,
      candidates,
      itemsById,
      priorContext: context,
      listContextIds: listContextIds,
      limit: limit,
    );
  }

  List<GrocerySuggestion> _rankCandidates(
    String query,
    Iterable<_CandidateEvidence> candidates,
    Map<String, CanonicalItemsTableData> itemsById, {
    required HouseholdPriorContext? priorContext,
    required List<String> listContextIds,
    required int limit,
  }) {
    final exact = <_ScoredSuggestion>[];
    final blended = <_ScoredSuggestion>[];
    for (final evidence in candidates) {
      final item = itemsById[evidence.canonicalItemId];
      if (item == null) continue;
      final priorFeatures = priorContext == null
          ? const HouseholdPriorFeatures()
          : _prior.featuresFor(
              item.id,
              priorContext,
              listContextIds: listContextIds,
            );
      final score = _prior.scorer.score(GroceryRankingFeatures(
        lexPrefix: evidence.lexPrefix,
        lexSim: evidence.lexSim,
        lexSemantic: evidence.lexSemantic,
        prior: priorFeatures,
      ));
      final ranked = _ScoredSuggestion(
        suggestion: GrocerySuggestion(
          canonicalItemId: item.id,
          name: _displayName(item, query),
          category: item.category,
          unit: item.defaultUnit,
        ),
        evidence: evidence,
        score: score,
        priorScore: _prior.priorOnlyScore(priorFeatures),
      );
      (evidence.isExact ? exact : blended).add(ranked);
    }

    int stableTie(_ScoredSuggestion a, _ScoredSuggestion b) {
      final indexOrder = a.evidence.firstSeen.compareTo(b.evidence.firstSeen);
      return indexOrder != 0
          ? indexOrder
          : a.suggestion.canonicalItemId
              .compareTo(b.suggestion.canonicalItemId);
    }

    exact.sort((a, b) {
      final priorOrder = b.priorScore.compareTo(a.priorScore);
      return priorOrder != 0 ? priorOrder : stableTie(a, b);
    });
    blended.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0 ? scoreOrder : stableTie(a, b);
    });
    return [...exact, ...blended]
        .take(limit)
        .map((entry) => entry.suggestion)
        .toList(growable: false);
  }

  static Iterable<String> _canonicalNames(CanonicalItemsTableData item) sync* {
    for (final name in [item.nameEn, item.nameDe, item.nameFr, item.nameEs]) {
      if (name.isNotEmpty) yield name;
    }
  }

  static String _displayName(CanonicalItemsTableData item, String query) {
    final candidates = <String, String>{
      'en': item.nameEn,
      'de': item.nameDe,
      'fr': item.nameFr,
      'es': item.nameEs,
    }..removeWhere((_, name) => name.isEmpty);
    if (candidates.isEmpty) return _cap(item.id);

    String? bestLang;
    var bestScore = 1 << 30;
    for (final entry in candidates.entries) {
      final name = normaliseText(entry.value);
      final score = name.startsWith(query) || query.startsWith(name)
          ? 0
          : editDistance(query, name);
      final better = score < bestScore ||
          (score == bestScore &&
              (bestLang == null ||
                  _localeRank(entry.key) < _localeRank(bestLang)));
      if (better) {
        bestScore = score;
        bestLang = entry.key;
      }
    }
    return _cap(candidates[bestLang]!);
  }

  static int _localeRank(String lang) {
    if (lang == groceryDisplayLang) return 0;
    if (lang == 'en') return 1;
    return 2;
  }

  static String _cap(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  static String labelForSelection(String typed, String canonicalName) {
    final value = typed.trim();
    if (value.isEmpty) return canonicalName;
    final normalizedTyped = value.toLowerCase();
    final normalizedCanonical = canonicalName.toLowerCase();
    if (normalizedTyped == normalizedCanonical) return canonicalName;
    if (normalizedCanonical.startsWith(normalizedTyped)) return canonicalName;
    final distance = editDistance(normalizedTyped, normalizedCanonical);
    final maxLength = normalizedTyped.length > normalizedCanonical.length
        ? normalizedTyped.length
        : normalizedCanonical.length;
    if (distance <= (maxLength <= 5 ? 1 : 2)) return canonicalName;
    return _cap(value);
  }
}

class _CandidateEvidence {
  _CandidateEvidence(this.canonicalItemId, this.firstSeen);

  final String canonicalItemId;
  final int firstSeen;
  final Set<String> matchedAliases = {};
  double lexPrefix = 0;
  double lexSim = 0;
  double lexSemantic = 0;
  bool isExact = false;
}

class _ScoredSuggestion {
  const _ScoredSuggestion({
    required this.suggestion,
    required this.evidence,
    required this.score,
    required this.priorScore,
  });

  final GrocerySuggestion suggestion;
  final _CandidateEvidence evidence;
  final double score;
  final double priorScore;
}
