import 'dart:typed_data';

/// Confidence level drives how the review screen treats a prediction.
enum ConfidenceLevel {
  /// > 0.85 — auto-accepted, shown in green, no user action required.
  autoAccept,

  /// 0.50–0.85 — shown in yellow, user should confirm or correct.
  review,

  /// < 0.50 or completely unknown — shown in red, user must resolve.
  ask,
}

/// Whether the source line had a visual mark on it.
enum MarkStatus { normal, crossedOut, checked }

/// Pixel bounding box within the original image.
class OcrBBox {
  final double left, top, width, height;
  const OcrBBox(this.left, this.top, this.width, this.height);
}

/// One OCR-recognised line from the recognition engine.
class OcrLine {
  final String text;

  /// Pixel bounding box within the original image. Null if engine did not
  /// provide position data (e.g. CrofAI text fallback).
  final OcrBBox? bbox;

  const OcrLine({required this.text, this.bbox});
}

/// Structured extraction output for one raw line.
class ParsedItem {
  final String rawText;
  final String itemName;
  final double quantity;
  final String unit;
  final int? priceCents;
  final MarkStatus markStatus;

  const ParsedItem({
    required this.rawText,
    required this.itemName,
    this.quantity = 1,
    this.unit = '',
    this.priceCents,
    this.markStatus = MarkStatus.normal,
  });
}

/// One resolved grocery item — the output the review screen operates on.
class GroceryPrediction {
  final String id;
  final String rawText;
  final String displayName;
  final String? canonicalItemId;
  final double quantity;
  final String unit;
  final int? priceCents;
  final ConfidenceLevel confidenceLevel;
  final double confidenceScore;
  final MarkStatus markStatus;
  final List<String> alternatives;
  final String? aisle;
  final int aisleSortOrder;

  const GroceryPrediction({
    required this.id,
    required this.rawText,
    required this.displayName,
    this.canonicalItemId,
    this.quantity = 1,
    this.unit = '',
    this.priceCents,
    this.confidenceLevel = ConfidenceLevel.ask,
    this.confidenceScore = 0,
    this.markStatus = MarkStatus.normal,
    this.alternatives = const [],
    this.aisle,
    this.aisleSortOrder = 99,
  });

  GroceryPrediction copyWith({
    String? displayName,
    String? canonicalItemId,
    double? quantity,
    String? unit,
    ConfidenceLevel? confidenceLevel,
    double? confidenceScore,
    String? aisle,
    int? aisleSortOrder,
    List<String>? alternatives,
  }) {
    return GroceryPrediction(
      id: id,
      rawText: rawText,
      displayName: displayName ?? this.displayName,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      priceCents: priceCents,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      markStatus: markStatus,
      alternatives: alternatives ?? this.alternatives,
      aisle: aisle ?? this.aisle,
      aisleSortOrder: aisleSortOrder ?? this.aisleSortOrder,
    );
  }
}

/// The full output of `ScanPipelineService.run`.
class GroceryScanResult {
  final Uint8List? imageBytes;
  final List<GroceryPrediction> items;
  final List<GroceryPrediction> ignored;
  final String engine;
  final bool needsReview;

  const GroceryScanResult({
    this.imageBytes,
    required this.items,
    this.ignored = const [],
    this.engine = 'mlkit',
    this.needsReview = false,
  });
}
