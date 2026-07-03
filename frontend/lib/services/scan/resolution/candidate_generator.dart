import '../../../storage/app_database.dart';
import '../grocery_classifier_service.dart';
import '../static_embedding_service.dart';
import 'resolution_candidate.dart';
import 'string_sim.dart';

/// Plan 037 — generates the UNION of candidates from every resolver source,
/// de-duped by canonical item, each remembering which sources proposed it and
/// their raw scores. This replaces the old sequential first-hit logic: nothing
/// is discarded here, so the scorer sees every contender (and source agreement
/// becomes a signal).
class CandidateGenerator {
  final AppDatabase _db;
  final GroceryClassifierService? _classifier;
  final StaticEmbeddingService? _embedder;

  /// Minimum fuzzy similarity to admit a candidate (below this it's noise).
  final double fuzzyFloor;

  /// Top-k pulled from the classifier and embedder.
  final int modelTopK;

  CandidateGenerator(
    this._db, {
    GroceryClassifierService? classifier,
    StaticEmbeddingService? embedder,
    this.fuzzyFloor = 0.4,
    this.modelTopK = 5,
  })  : _classifier = classifier,
        _embedder = embedder;

  Future<List<ResolutionCandidate>> generate(
    String rawText,
    String groupId,
  ) async {
    final normalised = normaliseText(rawText);
    if (normalised.isEmpty) return const [];

    // Per-candidate accumulators keyed by canonical item id.
    final acc = <String, _Accum>{};
    _Accum at(String id) => acc.putIfAbsent(id, () => _Accum());

    // 1. Exact alias hits — ALL of them (collisions are the point).
    final exact =
        await _db.findAliasesByText(groupId: groupId, aliasText: normalised);
    for (final a in exact) {
      final c = at(a.canonicalItemId);
      c.aliasStringSim = 1.0;
      c.isExactAlias = true;
      if (a.groupId == groupId && groupId != '__global__') {
        c.isHouseholdAlias = true;
        c.sources.add('household_alias');
      } else {
        c.sources.add('global_alias');
      }
    }

    // 2. Fuzzy neighbours (indexed prefilter, then edit-distance score).
    final fuzzy =
        await _db.getAliasFuzzyCandidates(groupId: groupId, query: normalised);
    for (final a in fuzzy) {
      final sim = stringSimilarity(normalised, a.aliasText);
      if (sim < fuzzyFloor) continue;
      final c = at(a.canonicalItemId);
      if (sim > c.aliasStringSim) c.aliasStringSim = sim;
      c.sources.add('fuzzy');
    }

    // 3. Classifier (label is a canonical name → map back to an id via alias).
    if (_classifier != null) {
      final preds = await _classifier.classify(rawText, topK: modelTopK);
      final aliases = await _db.findAliasesByTexts(
        groupId: groupId,
        aliasTexts: preds.map((p) => normaliseText(p.label)).toSet(),
      );
      for (final p in preds) {
        final alias = aliases[normaliseText(p.label)];
        if (alias == null) continue;
        final c = at(alias.canonicalItemId);
        if (p.score > c.classifierProb) c.classifierProb = p.score;
        c.sources.add('classifier');
      }
    }

    // 4. Semantic embedder (returns canonical ids directly).
    if (_embedder != null) {
      final matches = await _embedder.nearest(rawText, topK: modelTopK);
      for (final m in matches) {
        final c = at(m.itemId);
        if (m.score > c.embedderCosine) c.embedderCosine = m.score;
        c.sources.add('embedder');
      }
    }

    // Materialise: fetch canonical rows, drop any that no longer exist.
    final items = await _db.getCanonicalItemsByIds(acc.keys);
    final itemsById = {for (final item in items) item.id: item};
    final out = <ResolutionCandidate>[];
    for (final entry in acc.entries) {
      final item = itemsById[entry.key];
      if (item == null) continue;
      final a = entry.value;
      out.add(ResolutionCandidate(
        item: item,
        aliasStringSim: a.aliasStringSim,
        classifierProb: a.classifierProb,
        embedderCosine: a.embedderCosine,
        sources: a.sources,
        isExactAlias: a.isExactAlias,
        isHouseholdAlias: a.isHouseholdAlias,
      ));
    }
    return out;
  }
}

class _Accum {
  double aliasStringSim = 0;
  double classifierProb = 0;
  double embedderCosine = 0;
  final Set<String> sources = {};
  bool isExactAlias = false;
  bool isHouseholdAlias = false;
}
