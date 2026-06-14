import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'grocery_classifier_math.dart';
import 'grocery_classifier_types.dart';

/// TFLite-backed grocery classifier inference (mobile/desktop only).
class GroceryClassifierInference {
  final String _modelAsset;
  final String _labelsAsset;
  final String _vocabAsset;

  Interpreter? _interpreter;
  List<String>? _labels;
  Map<String, int>? _vocabIndex;
  List<double>? _idf;
  String? _stripChars;
  bool _unavailable = false;

  GroceryClassifierInference({
    String modelAsset = 'assets/models/grocery_classifier.tflite',
    String labelsAsset = 'assets/models/grocery_classifier_labels.txt',
    String vocabAsset = 'assets/models/grocery_classifier_vocab.json',
  })  : _modelAsset = modelAsset,
        _labelsAsset = labelsAsset,
        _vocabAsset = vocabAsset;

  Future<void> _ensureLoaded() async {
    if (_unavailable || _interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);

      final labelsRaw = await rootBundle.loadString(_labelsAsset);
      _labels = labelsRaw
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final vocabRaw = await rootBundle.loadString(_vocabAsset);
      final vocabJson = jsonDecode(vocabRaw) as Map<String, dynamic>;
      final vocabList = (vocabJson['vocab'] as List).cast<String>();
      _idf =
          (vocabJson['idf'] as List).map((v) => (v as num).toDouble()).toList();
      _stripChars = vocabJson['strip_chars'] as String? ?? '';
      _vocabIndex = {
        for (var i = 0; i < vocabList.length; i++) vocabList[i]: i,
      };
    } catch (_) {
      _interpreter?.close();
      _interpreter = null;
      _unavailable = true;
    }
  }

  Future<List<ClassifierPrediction>> classify(
    String rawText, {
    int topK = 5,
  }) async {
    await _ensureLoaded();
    if (_unavailable || _interpreter == null) return const [];

    final labels = _labels!;
    final idf = _idf!;
    final vocabIndex = _vocabIndex!;
    final stripChars = _stripChars!;

    final trigrams = GroceryClassifierMath.charTrigrams(rawText);
    final tfidf = GroceryClassifierMath.buildTfidf(
      trigrams,
      vocabIndex: vocabIndex,
      idf: idf,
      stripChars: stripChars,
    );

    final input = [tfidf.toList()];
    final output = [List<double>.filled(labels.length, 0.0)];
    _interpreter!.run(input, output);

    final probs = output[0];
    final indices = List.generate(probs.length, (i) => i)
      ..sort((a, b) => probs[b].compareTo(probs[a]));

    return indices
        .take(topK)
        .map((i) => ClassifierPrediction(label: labels[i], score: probs[i]))
        .toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
