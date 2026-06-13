import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// A single prediction from the on-device grocery classifier.
class ClassifierPrediction {
  final String label;
  final double score;

  const ClassifierPrediction({required this.label, required this.score});
}

/// On-device grocery classifier backed by a Flex-free TFLite model.
///
/// The model accepts a float32 TF-IDF vector (computed client-side from
/// [buildTfidf]) and outputs a softmax probability vector over canonical
/// grocery labels.  Asset loading is lazy and guarded: if the model assets
/// are missing (e.g. first install before the ML bundle ships), [classify]
/// returns `const []` rather than throwing.
///
/// Typical usage:
/// ```dart
/// final svc = GroceryClassifierService();
/// final preds = await svc.classify('Vollmilch 3.5%');
/// ```
class GroceryClassifierService {
  final String _modelAsset;
  final String _labelsAsset;
  final String _vocabAsset;

  Interpreter? _interpreter;
  List<String>? _labels;
  Map<String, int>? _vocabIndex;
  List<double>? _idf;
  String? _stripChars;
  bool _unavailable = false;

  GroceryClassifierService({
    String modelAsset = 'assets/models/grocery_classifier.tflite',
    String labelsAsset = 'assets/models/grocery_classifier_labels.txt',
    String vocabAsset = 'assets/models/grocery_classifier_vocab.json',
  })  : _modelAsset = modelAsset,
        _labelsAsset = labelsAsset,
        _vocabAsset = vocabAsset;

  // ---------------------------------------------------------------------------
  // Pure math — @visibleForTesting so tests exercise them without asset I/O.
  // ---------------------------------------------------------------------------

  /// Converts [text] to a character-trigram string, matching the Python
  /// `char_trigrams` function in `train.py`.
  ///
  /// `text.lower()[:maxLen-4]` → join consecutive triples with spaces.
  @visibleForTesting
  static String charTrigrams(String text, {int maxLen = 64}) {
    final t = text.toLowerCase();
    final cut = t.length > (maxLen - 4) ? t.substring(0, maxLen - 4) : t;
    if (cut.length <= 2) return cut;
    final grams = <String>[];
    for (var i = 0; i <= cut.length - 3; i++) {
      grams.add(cut.substring(i, i + 3));
    }
    return grams.join(' ');
  }

  /// Builds a TF-IDF vector from a trigram string, matching the Keras
  /// `TextVectorization(output_mode="tf_idf")` layer.
  ///
  /// Tokenisation rules (Keras defaults):
  /// - Split on whitespace (drop empties).
  /// - Strip any character present in [stripChars] from each token.
  /// - Unknown tokens → index 1 (OOV bucket).
  /// - Index 0 = padding (`""`) — never emitted.
  /// - output[i] = count(token i) * idf[i].
  @visibleForTesting
  static Float32List buildTfidf(
    String trigramString, {
    required Map<String, int> vocabIndex,
    required List<double> idf,
    required String stripChars,
  }) {
    final stripSet = stripChars.codeUnits.toSet();
    final tokens = trigramString
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) {
          // Remove chars present in stripChars.
          final buf = StringBuffer();
          for (final cu in t.codeUnits) {
            if (!stripSet.contains(cu)) buf.writeCharCode(cu);
          }
          return buf.toString();
        })
        .where((t) => t.isNotEmpty)
        .toList();

    final counts = List<double>.filled(idf.length, 0.0);
    for (final token in tokens) {
      final idx = vocabIndex[token] ?? 1; // default OOV = index 1
      if (idx < counts.length) counts[idx]++;
    }

    final out = Float32List(idf.length);
    for (var i = 0; i < idf.length; i++) {
      out[i] = counts[i] * idf[i];
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Asset loading.
  // ---------------------------------------------------------------------------

  Future<void> _ensureLoaded() async {
    if (_unavailable || _interpreter != null) return;

    try {
      // Interpreter from bundled TFLite model.
      _interpreter = await Interpreter.fromAsset(_modelAsset);

      // Labels — one per line.
      final labelsRaw = await rootBundle.loadString(_labelsAsset);
      _labels = labelsRaw
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Vocab + IDF JSON.
      final vocabRaw = await rootBundle.loadString(_vocabAsset);
      final vocabJson = jsonDecode(vocabRaw) as Map<String, dynamic>;
      final vocabList = (vocabJson['vocab'] as List).cast<String>();
      _idf = (vocabJson['idf'] as List).map((v) => (v as num).toDouble()).toList();
      _stripChars = vocabJson['strip_chars'] as String? ?? '';
      _vocabIndex = {
        for (var i = 0; i < vocabList.length; i++) vocabList[i]: i,
      };
    } catch (_) {
      // Model assets not shipped yet — degrade gracefully.
      _interpreter?.close();
      _interpreter = null;
      _unavailable = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Inference.
  // ---------------------------------------------------------------------------

  /// Classifies [rawText] and returns up to [topK] predictions sorted by
  /// descending confidence.  Returns `const []` if the model is unavailable.
  Future<List<ClassifierPrediction>> classify(String rawText,
      {int topK = 5}) async {
    await _ensureLoaded();
    if (_unavailable || _interpreter == null) return const [];

    final labels = _labels!;
    final idf = _idf!;
    final vocabIndex = _vocabIndex!;
    final stripChars = _stripChars!;

    final trigrams = charTrigrams(rawText);
    final tfidf = buildTfidf(
      trigrams,
      vocabIndex: vocabIndex,
      idf: idf,
      stripChars: stripChars,
    );

    // Interpreter expects shape [1, vocabSize].
    final input = [tfidf.toList()];
    final output = [List<double>.filled(labels.length, 0.0)];
    _interpreter!.run(input, output);

    final probs = output[0];
    // Argsort descending, take topK.
    final indices = List.generate(probs.length, (i) => i)
      ..sort((a, b) => probs[b].compareTo(probs[a]));

    return indices
        .take(topK)
        .map((i) => ClassifierPrediction(label: labels[i], score: probs[i]))
        .toList();
  }

  /// Release interpreter resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
