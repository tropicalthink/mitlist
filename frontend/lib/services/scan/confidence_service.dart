import 'scan_models.dart';

/// Converts a raw resolver score into a [ConfidenceLevel] and attaches it to
/// a [GroceryPrediction].
class ConfidenceService {
  static const double _autoThreshold = 0.85;
  static const double _reviewThreshold = 0.50;

  ConfidenceLevel level(
    double score, {
    double? autoThreshold,
    double? reviewThreshold,
  }) {
    final auto = autoThreshold ?? _autoThreshold;
    final review = reviewThreshold ?? _reviewThreshold;
    if (score >= auto) return ConfidenceLevel.autoAccept;
    if (score >= review) return ConfidenceLevel.review;
    return ConfidenceLevel.ask;
  }

  GroceryPrediction applyTo(
    GroceryPrediction prediction,
    double score, {
    double? autoThreshold,
    double? reviewThreshold,
  }) {
    return prediction.copyWith(
      confidenceScore: score,
      confidenceLevel: level(
        score,
        autoThreshold: autoThreshold,
        reviewThreshold: reviewThreshold,
      ),
    );
  }
}
