import 'scan_models.dart';

/// Converts a raw resolver score into a [ConfidenceLevel] and attaches it to
/// a [GroceryPrediction].
class ConfidenceService {
  static const double _autoThreshold = 0.85;
  static const double _reviewThreshold = 0.50;

  ConfidenceLevel level(double score) {
    if (score >= _autoThreshold) return ConfidenceLevel.autoAccept;
    if (score >= _reviewThreshold) return ConfidenceLevel.review;
    return ConfidenceLevel.ask;
  }

  GroceryPrediction applyTo(GroceryPrediction prediction, double score) {
    return prediction.copyWith(
      confidenceScore: score,
      confidenceLevel: level(score),
    );
  }
}
