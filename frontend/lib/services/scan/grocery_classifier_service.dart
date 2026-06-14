import 'package:flutter/foundation.dart';

import 'grocery_classifier_inference_native.dart'
    if (dart.library.html) 'grocery_classifier_inference_stub.dart'
    as inference;
import 'grocery_classifier_math.dart';
import 'grocery_classifier_types.dart';

export 'grocery_classifier_types.dart';

/// On-device grocery classifier backed by a Flex-free TFLite model.
///
/// The model accepts a float32 TF-IDF vector (computed client-side from
/// [buildTfidf]) and outputs a softmax probability vector over canonical
/// grocery labels.  Asset loading is lazy and guarded: if the model assets
/// are missing (e.g. first install before the ML bundle ships), [classify]
/// returns `const []` rather than throwing.
///
/// On web, inference is unavailable and [classify] always returns `const []`.
///
/// Typical usage:
/// ```dart
/// final svc = GroceryClassifierService();
/// final preds = await svc.classify('Vollmilch 3.5%');
/// ```
class GroceryClassifierService {
  final inference.GroceryClassifierInference _impl;

  GroceryClassifierService({
    String modelAsset = 'assets/models/grocery_classifier.tflite',
    String labelsAsset = 'assets/models/grocery_classifier_labels.txt',
    String vocabAsset = 'assets/models/grocery_classifier_vocab.json',
  }) : _impl = inference.GroceryClassifierInference(
          modelAsset: modelAsset,
          labelsAsset: labelsAsset,
          vocabAsset: vocabAsset,
        );

  /// Converts [text] to a character-trigram string, matching the Python
  /// `char_trigrams` function in `train.py`.
  @visibleForTesting
  static String charTrigrams(String text, {int maxLen = 64}) =>
      GroceryClassifierMath.charTrigrams(text, maxLen: maxLen);

  /// Builds a TF-IDF vector from a trigram string, matching the Keras
  /// `TextVectorization(output_mode="tf_idf")` layer.
  @visibleForTesting
  static Float32List buildTfidf(
    String trigramString, {
    required Map<String, int> vocabIndex,
    required List<double> idf,
    required String stripChars,
  }) =>
      GroceryClassifierMath.buildTfidf(
        trigramString,
        vocabIndex: vocabIndex,
        idf: idf,
        stripChars: stripChars,
      );

  /// Classifies [rawText] and returns up to [topK] predictions sorted by
  /// descending confidence.  Returns `const []` if the model is unavailable.
  Future<List<ClassifierPrediction>> classify(String rawText,
      {int topK = 5}) =>
      _impl.classify(rawText, topK: topK);

  /// Release interpreter resources.
  void dispose() => _impl.dispose();
}
