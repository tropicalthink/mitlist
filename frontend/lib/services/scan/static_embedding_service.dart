import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

final Logger _log = Logger();

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
///
/// The catalog scan is O(catalog × dim) float math. To keep it off the UI
/// thread, production runs it on a **persistent worker isolate** that owns the
/// parsed catalog and answers `query → top-k` over a port (so the ~9 MB bundle
/// is copied to the worker once, not per keystroke). Unit tests inject state
/// via [seedForTest] and run the identical scan in-process — no isolate.
class StaticEmbeddingService {
  static const _vocabAsset = 'assets/grocery/embedder_vocab.json';
  static const _catalogAsset = 'assets/grocery/catalog_vectors.json';

  // In-process state — populated only by [seedForTest] for unit tests.
  Set<String>? _vocabSet;
  Map<String, int>? _vocabIndex;
  List<Float32List>? _vocabVectors; // indexed by vocab position
  List<String>? _itemIds;
  List<Float32List>? _catalogVectors; // one per item, L2-normalised

  // True once we have confirmed that at least one bundle is missing/malformed.
  bool _unavailable = false;
  // True once usable: seeded in-process, or the worker has loaded the bundles.
  bool _ready = false;
  // True when [seedForTest] injected state; routes [nearest] in-process so unit
  // tests need no isolate.
  bool _inProcess = false;

  // Persistent worker isolate (production path).
  Isolate? _isolate;
  SendPort? _workerSend;
  Future<bool>? _workerReady;

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

  /// Pure top-[topK] cosine scan, shared by the in-process (test) path and the
  /// worker isolate so both rank identically.
  static List<EmbedMatch> _scan(
    String query,
    int topK, {
    required Set<String> vocab,
    required Map<String, int> index,
    required List<Float32List> vectors,
    required List<String> itemIds,
    required List<Float32List> catalog,
  }) {
    final tokens = tokenize(query, vocab: vocab);
    if (tokens.isEmpty) return const [];

    final qVec = embed(tokens, index: index, vectors: vectors);

    // cosine vs each catalog row (catalog is L2-normalised, so dot = cosine)
    final scores = <_Scored>[];
    for (var i = 0; i < catalog.length; i++) {
      scores.add(_Scored(itemIds[i], cosine(qVec, catalog[i])));
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return [
      for (final s in scores.take(topK))
        EmbedMatch(itemId: s.itemId, score: s.score),
    ];
  }

  // ── Worker lifecycle ────────────────────────────────────────────────────────

  /// Eagerly spawns the worker and loads the bundles in the background without
  /// blocking the caller. Safe to call repeatedly — the spawn+load runs at most
  /// once. Callers on a latency-sensitive path (typing/autocomplete) should warm
  /// up via this and gate semantic use on [isReady] rather than awaiting
  /// [nearest] cold.
  Future<void> warmUp() async {
    if (_unavailable || _inProcess) return;
    await _ensureWorker();
  }

  Future<bool> _ensureWorker() => _workerReady ??= _spawnAndLoad();

  Future<bool> _spawnAndLoad() async {
    try {
      // The worker loads + decodes + dequantises the ~9 MB bundle itself (via a
      // background binary messenger), so the multi-megabyte string decode never
      // runs on — or freezes — the UI isolate. Needs the root isolate token,
      // which is absent in plain unit tests (handled as "unavailable").
      final token = RootIsolateToken.instance;
      if (token == null) {
        _unavailable = true;
        return false;
      }

      final handshake = ReceivePort();
      _isolate = await Isolate.spawn(
        _embeddingIsolateMain,
        [handshake.sendPort, token],
      );
      _workerSend = await handshake.first as SendPort;
      handshake.close();

      final reply = ReceivePort();
      _workerSend!.send(['load', reply.sendPort]);
      final ok = await reply.first == true;
      reply.close();
      if (!ok) {
        _log.w(
          'static embedding assets unavailable, embedder disabled: '
          '$_vocabAsset, $_catalogAsset',
        );
        _unavailable = true;
        _teardownWorker();
        return false;
      }
      _ready = true;
      return true;
    } catch (e) {
      _log.w(
        'static embedding worker failed, embedder disabled: '
        '$_vocabAsset, $_catalogAsset: $e',
      );
      _unavailable = true;
      _teardownWorker();
      return false;
    }
  }

  void _teardownWorker() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerSend = null;
  }

  /// Releases the worker isolate. Safe to call multiple times.
  void dispose() => _teardownWorker();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the top-[topK] nearest catalog items to [query].
  ///
  /// Returns `const []` if the bundle is unavailable (fail-soft).
  Future<List<EmbedMatch>> nearest(String query, {int topK = 5}) async {
    if (_unavailable) return const [];

    // Test path: seeded in-process, scan synchronously (no isolate).
    if (_inProcess) {
      return _scan(
        query,
        topK,
        vocab: _vocabSet!,
        index: _vocabIndex!,
        vectors: _vocabVectors!,
        itemIds: _itemIds!,
        catalog: _catalogVectors!,
      );
    }

    // Production path: run the catalog scan on the worker isolate so a keystroke
    // never blocks the UI thread on cosine math.
    final ready = await _ensureWorker();
    if (!ready) return const [];

    final response = ReceivePort();
    _workerSend!.send(['query', response.sendPort, query, topK]);
    // Never let a stuck worker stall the caller (autocomplete is latency
    // sensitive): fall back to no semantic matches on timeout.
    final result = await response.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => const [<String>[], <double>[]],
    ) as List;
    response.close();

    final ids = result[0] as List;
    final scores = result[1] as List;
    return [
      for (var i = 0; i < ids.length; i++)
        EmbedMatch(
          itemId: ids[i] as String,
          score: (scores[i] as num).toDouble(),
        ),
    ];
  }

  /// Whether the embedder is loaded and ready to score queries.
  bool get isReady => !_unavailable && _ready;

  /// Directly inject pre-built state — for tests only.
  ///
  /// Allows unit tests to bypass asset loading and supply hand-crafted
  /// fixture data, verifying the pure-Dart logic without any I/O. Routes
  /// [nearest] through the in-process scan so no isolate is spawned.
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
    _ready = true;
    _inProcess = true;
  }
}

class _Scored {
  final String itemId;
  final double score;
  const _Scored(this.itemId, this.score);
}

/// Entry point for the persistent embedding worker isolate. Loads + parses the
/// bundle itself (off the UI isolate) and owns the resident catalog, answering
/// `query → top-k` requests so the cosine scan never runs on the UI isolate.
///
/// Spawn arg: `[handshakePort, rootIsolateToken]`. Messages (each carries a
/// one-shot reply port):
///   ['load',  replyPort]            → replyPort.send(bool ok)
///   ['query', replyPort, query, topK] → replyPort.send([ids, scores])
void _embeddingIsolateMain(List<dynamic> args) {
  final handshake = args[0] as SendPort;
  final token = args[1] as RootIsolateToken;
  // Lets rootBundle (a platform channel) work from this background isolate.
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final rx = ReceivePort();
  handshake.send(rx.sendPort);

  _ParsedBundles? state;
  rx.listen((message) async {
    final msg = message as List;
    final kind = msg[0] as String;
    final reply = msg[1] as SendPort;

    if (kind == 'load') {
      try {
        final vocabJson =
            await rootBundle.loadString(StaticEmbeddingService._vocabAsset);
        final catalogJson =
            await rootBundle.loadString(StaticEmbeddingService._catalogAsset);
        state = _parseEmbedderBundles([vocabJson, catalogJson]);
      } catch (e) {
        _log.w(
          'static embedding assets failed to load: '
          '${StaticEmbeddingService._vocabAsset}, '
          '${StaticEmbeddingService._catalogAsset}: $e',
        );
        state = null;
      }
      reply.send(state != null);
      return;
    }

    if (kind == 'query') {
      try {
        final s = state;
        final matches = s == null
            ? const <EmbedMatch>[]
            : StaticEmbeddingService._scan(
                msg[2] as String,
                msg[3] as int,
                vocab: s.vocabSet,
                index: s.vocabIndex,
                vectors: s.vocabVectors,
                itemIds: s.itemIds,
                catalog: s.catalogVectors,
              );
        reply.send([
          [for (final m in matches) m.itemId],
          [for (final m in matches) m.score],
        ]);
      } catch (e) {
        _log.w('static embedding query failed, returning no matches: $e');
        // Always reply so the caller's `await` resolves instead of hanging.
        reply.send(const [<String>[], <double>[]]);
      }
    }
  });
}

/// Parsed embedder state, produced off the main isolate by
/// [_parseEmbedderBundles] and kept resident in the worker isolate.
class _ParsedBundles {
  final Set<String> vocabSet;
  final Map<String, int> vocabIndex;
  final List<Float32List> vocabVectors;
  final List<String> itemIds;
  final List<Float32List> catalogVectors;
  const _ParsedBundles({
    required this.vocabSet,
    required this.vocabIndex,
    required this.vocabVectors,
    required this.itemIds,
    required this.catalogVectors,
  });
}

/// Decodes + dequantises the vocab/catalog JSON bundles. Pure and isolate-safe;
/// returns null if either bundle is malformed. [jsons] is `[vocabJson,
/// catalogJson]`.
_ParsedBundles? _parseEmbedderBundles(List<String> jsons) {
  try {
    final vocabData = jsonDecode(jsons[0]) as Map<String, dynamic>;
    final catalogData = jsonDecode(jsons[1]) as Map<String, dynamic>;

    final vocab = (vocabData['vocab'] as List).cast<String>();
    final dim = vocabData['dim'] as int;
    final vocabScale = (vocabData['scale'] as num).toDouble();
    final vocabInt8 = vocabData['vectors_int8'] as List;

    final itemIds = (catalogData['item_ids'] as List).cast<String>();
    final catalogScale = (catalogData['scale'] as num).toDouble();
    final catalogInt8 = catalogData['vectors_int8'] as List;
    final catalogDim = catalogData['dim'] as int;

    // Dequantise: float = int8 * scale
    final vocabVectors = <Float32List>[];
    for (final row in vocabInt8) {
      final r = row as List;
      final v = Float32List(dim);
      for (var i = 0; i < dim; i++) {
        v[i] = (r[i] as num) * vocabScale;
      }
      vocabVectors.add(v);
    }

    final catalogVectors = <Float32List>[];
    for (final row in catalogInt8) {
      final r = row as List;
      final v = Float32List(catalogDim);
      for (var i = 0; i < catalogDim; i++) {
        v[i] = (r[i] as num) * catalogScale;
      }
      catalogVectors.add(v);
    }

    return _ParsedBundles(
      vocabSet: vocab.toSet(),
      vocabIndex: {for (var i = 0; i < vocab.length; i++) vocab[i]: i},
      vocabVectors: vocabVectors,
      itemIds: itemIds,
      catalogVectors: catalogVectors,
    );
  } catch (e) {
    _log.w(
      'static embedding assets malformed: '
      '${StaticEmbeddingService._vocabAsset}, '
      '${StaticEmbeddingService._catalogAsset}: $e',
    );
    return null;
  }
}
