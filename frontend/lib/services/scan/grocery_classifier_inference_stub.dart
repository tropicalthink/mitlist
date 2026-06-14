import 'grocery_classifier_types.dart';

/// Web/no-ffi stub — TFLite inference is unavailable on web.
class GroceryClassifierInference {
  GroceryClassifierInference({
    String modelAsset = 'assets/models/grocery_classifier.tflite',
    String labelsAsset = 'assets/models/grocery_classifier_labels.txt',
    String vocabAsset = 'assets/models/grocery_classifier_vocab.json',
  });

  Future<List<ClassifierPrediction>> classify(
    String rawText, {
    int topK = 5,
  }) async =>
      const [];

  void dispose() {}
}
