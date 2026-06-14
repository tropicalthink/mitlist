/// A single prediction from the on-device grocery classifier.
class ClassifierPrediction {
  final String label;
  final double score;

  const ClassifierPrediction({required this.label, required this.score});
}
