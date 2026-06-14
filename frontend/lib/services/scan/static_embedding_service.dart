import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A resolved nearest-neighbour match from [StaticEmbeddingService.nearest].
class EmbedMatch {
  final String itemId;
  final double score;

  const EmbedMatch({required this.itemId, required this.score});
}

/// On-device static embedding service for semantic grocery search.
///
/// All inference is pure Dart — no native ML runtime, no tflite_flutter.
/// The embedding model is a Model2Vec distilled word/phrase-level embedder
/// produced at build time and shipped as versioned JSON bundles:
///   assets/grocery/embedder_vocab.json   — vocab + int8 token vectors
///   assets/grocery/catalog_vectors.json  — int8 catalog matrix + item IDs
///
/// If either bundle is absent (e.g. first install before the ML bundle ships),
/// [nearest] returns `const []` rather than throwing, so the app runs safely
/// with only the alias-prefix fallback.
///
/// Tokeniser: lowercase → greedy longest-match phrases against vocab →
///   unmatched tokens fall back to [GroceryClassifierService.charTrigrams]
///   pieces that are in vocab → any remaining OOV pieces are dropped.
/// Mean-pool token vectors → query vector → cosine vs catalog → top-k.
class StaticEmbeddingService {
  static const _vocabAsset = 'assets/grocery/embedder_vocab.json';
  static const _catalogAsset = 'assets/grocery/catalog_vectors.json';

  // Loaded state — null until [_load] completes.
  Set<String>? _vocabSet;
  Map<String, int>? _vocabIndex;
  List<Float32List>? _vocabVectors; // indexed by vocab position
  List<String>? _itemIds;
  List<Float32List>? _catalogVectors; // one per item, L2-normalised

  // True when we have confirmed that at least one bundle is missing.
  bool _unavailable = false;

  // Guard against concurrent loads.
  Future<void>? _loadFuture;

  // ── Pure-math helpers (all @visibleForTesting) ──────────────────────────

  /// Tokenise [text] against [vocab].
  ///
  /// Algorithm:
  /// 1. Lowercase + collapse whitespace.
  /// 2. Greedy longest-match: try every phrase in [vocab] (phrases first,
  ///    i.e. tokens containing spaces, sorted descending by length).
  /// 3. For a word that is not in [vocab], fall back to the char-trigrams
  ///    produced by [GroceryClassifierService.charTrigrams] and keep any
  ///    trigram tokens that are in [vocab].
  /// 4. Drop the rest (OOV).
  @visibleForTesting
  static List<String> tokenize(
    String text, {
    required Set<String> vocab,
  }) {
    final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return const [];

    // Pre-sort phrases (tokens with spaces) by descending length for greedy match.
    final phrases = vocab.where((v) => v.contains(' ')).toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final tokens = <String>[];
    var remaining = t;

    while (remaining.isNotEmpty) {
      bool matched = false;

      // Greedy longest phrase match.
      for (final phrase in phrases) {
        if (remaining.startsWith(phrase)) {
          tokens.add(phrase);
          remaining = remaining.substring(phrase.length).trimLeft();
          matched = true;
          break;
        }
      }
      if (matched) continue;

      // Split off the next whitespace-delimited word.
      final spaceIdx = remaining.indexOf(' ');
      final String word;
      if (spaceIdx == -1) {
        word = remaining;
        remaining = '';
      } else {
        word = remaining.substring(0, spaceIdx);
        remaining = remaining.substring(spaceIdx + 1);
      }

      if (word.isEmpty) continue;

      if (vocab.contains(word)) {
        tokens.add(word);
      } else {
        // OOV: char-trigram fallback (same algorithm as Plan 026's
        // GroceryClassifierService.charTrigrams; inlined to respect
        // @visibleForTesting on that class).
        final trigramTokens = _charTrigrams(word);
        for (final tg in trigramTokens) {
          if (tg.isNotEmpty && vocab.contains(tg)) {
            tokens.add(tg);
          }
        }
      }
    }

    return tokens;
  }

  /// Character-trigram pieces of [word] (same algorithm as Plan 026's
  /// `GroceryClassifierService.charTrigrams`, inlined here so we do not
  /// violate `@visibleForTesting` on that class).
  ///
  /// Example: "milch" → ["mil", "ilc", "lch"]
  static List<String> _charTrigrams(String word, {int maxLen = 64}) {
    final t = word.toLowerCase();
    final cut = t.length > (maxLen - 4) ? t.substring(0, maxLen - 4) : t;
    if (cut.length <= 2) return cut.isEmpty ? const [] : [cut];
    final grams = <String>[];
    for (var i = 0; i <= cut.length - 3; i++) {
      grams.add(cut.substring(i, i + 3));
    }
    return grams;
  }

  /// Mean-pool the vectors for [tokens].
  ///
  /// Returns a zero vector of [vectors][0].length when no token matches.
  @visibleForTesting
  static Float32List embed(
    List<String> tokens, {
    required Map<String, int> index,
    required List<Float32List> vectors,
  }) {
    if (vectors.isEmpty) return Float32List(0);
    final dim = vectors[0].length;

    final matched = <Float32List>[];
    for (final tok in tokens) {
      final idx = index[tok];
      if (idx != null && idx < vectors.length) {
        matched.add(vectors[idx]);
      }
    }

    if (matched.isEmpty) return Float32List(dim); // zero vector

    final result = Float32List(dim);
    for (final v in matched) {
      for (var i = 0; i < dim; i++) {
        result[i] += v[i];
      }
    }
    final n = matched.length;
    for (var i = 0; i < dim; i++) {
      result[i] /= n;
    }
    return result;
  }

  /// Cosine similarity in [−1, 1]. Returns 0 for zero vectors.
  @visibleForTesting
  static double cosine(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (normA * normB == 0 ? 1.0 : _sqrt(normA) * _sqrt(normB));
  }

  static double _sqrt(double x) {
    // Inline Newton-Raphson to avoid dart:math import (pure Dart, no native).
    if (x <= 0) return 0;
    var s = x;
    // Fast estimate via bit hack is not available in Dart VM; iterate.
    for (var i = 0; i < 40; i++) {
      final s2 = (s + x / s) * 0.5;
      if ((s2 - s).abs() < 1e-10) return s2;
      s = s2;
    }
    return s;
  }

  // ── Bundle loading ────────────────────────────────────────────────────────

  Future<void> _load() async {
    _loadFuture ??= _doLoad();
    await _loadFuture;
  }

  Future<void> _doLoad() async {
    try {
      final vocabJson = await rootBundle.loadString(_vocabAsset);
      final catalogJson = await rootBundle.loadString(_catalogAsset);

      final vocabData = jsonDecode(vocabJson) as Map<String, dynamic>;
      final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;

      final vocab = (vocabData['vocab'] as List).cast<String>();
      final dim = vocabData['dim'] as int;
      final vocabScale = (vocabData['scale'] as num).toDouble();
      final vocabInt8 = (vocabData['vectors_int8'] as List)
          .map((row) => (row as List).cast<int>())
          .toList();

      final itemIds = (catalogData['item_ids'] as List).cast<String>();
      final catalogScale = (catalogData['scale'] as num).toDouble();
      final catalogInt8 = (catalogData['vectors_int8'] as List)
          .map((row) => (row as List).cast<int>())
          .toList();

      // Dequantise: float = int8 * scale
      final vocabVectors = <Float32List>[];
      for (final row in vocabInt8) {
        final v = Float32List(dim);
        for (var i = 0; i < dim; i++) {
          v[i] = row[i] * vocabScale;
        }
        vocabVectors.add(v);
      }

      final catalogVectors = <Float32List>[];
      final catalogDim = catalogData['dim'] as int;
      for (final row in catalogInt8) {
        final v = Float32List(catalogDim);
        for (var i = 0; i < catalogDim; i++) {
          v[i] = row[i] * catalogScale;
        }
        catalogVectors.add(v);
      }

      _vocabSet = vocab.toSet();
      _vocabIndex = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};
      _vocabVectors = vocabVectors;
      _itemIds = itemIds;
      _catalogVectors = catalogVectors;
    } catch (_) {
      // Bundle absent or malformed — degrade gracefully.
      _unavailable = true;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the top-[topK] nearest catalog items to [query].
  ///
  /// Returns `const []` if the bundle is unavailable (fail-soft).
  Future<List<EmbedMatch>> nearest(String query, {int topK = 5}) async {
    if (_unavailable) return const [];
    await _load();
    if (_unavailable) return const [];

    final vocab = _vocabSet!;
    final index = _vocabIndex!;
    final vectors = _vocabVectors!;
    final itemIds = _itemIds!;
    final catalog = _catalogVectors!;

    final tokens = tokenize(query, vocab: vocab);
    if (tokens.isEmpty) return const [];

    final qVec = embed(tokens, index: index, vectors: vectors);

    // cosine vs each catalog row (catalog is L2-normalised, so dot = cosine)
    final scores = <_Scored>[];
    for (var i = 0; i < catalog.length; i++) {
      final s = cosine(qVec, catalog[i]);
      scores.add(_Scored(itemIds[i], s));
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores
        .take(topK)
        .map((s) => EmbedMatch(itemId: s.itemId, score: s.score))
        .toList();
  }

  /// Whether the bundle has been loaded and is ready.
  bool get isReady =>
      !_unavailable &&
      _vocabIndex != null &&
      _catalogVectors != null;

  /// Directly inject pre-built state — for tests only.
  ///
  /// Allows unit tests to bypass asset loading and supply hand-crafted
  /// fixture data, verifying the pure-Dart logic without any I/O.
  @visibleForTesting
  void seedForTest({
    required List<String> vocab,
    required List<Float32List> vocabVectors,
    required List<String> itemIds,
    required List<Float32List> catalogVectors,
  }) {
    _vocabSet = vocab.toSet();
    _vocabIndex = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};
    _vocabVectors = vocabVectors;
    _itemIds = itemIds;
    _catalogVectors = catalogVectors;
    _unavailable = false;
    // Pre-empt the lazy load so nearest() skips _load().
    _loadFuture = Future.value();
  }
}

class _Scored {
  final String itemId;
  final double score;
  const _Scored(this.itemId, this.score);
}
