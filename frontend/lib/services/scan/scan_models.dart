import 'dart:typed_data';

import 'canonical_resolver_service.dart';

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
enum MarkStatus {
  normal,
  crossedOut,
  checked,

  /// Probably not a list entry: print around the list, a date, a smudge.
  notList,
}

/// Pixel bounding box within the original image.
class OcrBBox {
  final double left, top, width, height;
  const OcrBBox(this.left, this.top, this.width, this.height);
}

/// Another transcription supported by the same recognizer logits.
///
/// Alternatives are produced locally by CTC beam decoding. They are evidence
/// for the grocery resolver, not extra detected lines and not cloud guesses.
class OcrAlternative {
  final String text;

  /// Probability relative to the strongest beam (1.0 is the strongest).
  final double relativeScore;

  const OcrAlternative({required this.text, required this.relativeScore});
}

/// One OCR-recognised line from the recognition engine.
class OcrLine {
  final String text;

  /// Pixel bounding box within the original image. Null if engine did not
  /// provide position data.
  final OcrBBox? bbox;

  /// Recognition-engine confidence when the engine exposes one. Null means
  /// unavailable, not zero confidence.
  final double? confidence;

  /// Visual state detected from the source pixels. This is separate from the
  /// recognized text because strikethrough strokes are not transcript tokens.
  final MarkStatus markStatus;

  /// Other transcriptions from the same pixels, strongest first.
  final List<OcrAlternative> alternatives;

  const OcrLine({
    required this.text,
    this.bbox,
    this.confidence,
    this.markStatus = MarkStatus.normal,
    this.alternatives = const [],
  });
}

/// Structured extraction output for one raw line.
class ParsedItem {
  final String rawText;
  final String itemName;
  final OcrBBox? bbox;
  final double quantity;
  final String unit;
  final int? priceCents;
  final MarkStatus markStatus;
  final List<OcrAlternative> alternatives;

  /// The recognizer's own confidence in the line text, when it reported one.
  final double? ocrConfidence;

  const ParsedItem({
    required this.rawText,
    required this.itemName,
    this.bbox,
    this.quantity = 1,
    this.unit = '',
    this.priceCents,
    this.markStatus = MarkStatus.normal,
    this.alternatives = const [],
    this.ocrConfidence,
  });
}

/// One resolved grocery item — the output the review screen operates on.
class GroceryPrediction {
  final String id;
  final String rawText;

  /// The OCR line with bullets, quantity, unit and price stripped. Null for
  /// predictions that did not come from OCR (suggestions, tests).
  final String? itemName;
  final String displayName;
  final OcrBBox? bbox;
  final String? canonicalItemId;
  final double quantity;
  final String unit;
  final int? priceCents;
  final ConfidenceLevel confidenceLevel;
  final double confidenceScore;
  final MarkStatus markStatus;
  final List<ResolveAlternative> alternatives;
  final String? aisle;
  final int aisleSortOrder;
  final bool userConfirmed;

  const GroceryPrediction({
    required this.id,
    required this.rawText,
    this.itemName,
    required this.displayName,
    this.bbox,
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
    this.userConfirmed = false,
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
    List<ResolveAlternative>? alternatives,
    bool? userConfirmed,
  }) {
    return GroceryPrediction(
      id: id,
      rawText: rawText,
      itemName: itemName,
      displayName: displayName ?? this.displayName,
      bbox: bbox,
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
      userConfirmed: userConfirmed ?? this.userConfirmed,
    );
  }

  /// What was written on the list, without bullets or quantities.
  String get cleanName {
    final name = itemName?.trim();
    return name == null || name.isEmpty ? rawText.trim() : name;
  }

  /// An unconfirmed low-confidence match: the resolver's guess is only a hint,
  /// so the review shows, and the list receives, what was actually written.
  bool get leadsWithWrittenText =>
      !userConfirmed &&
      confidenceLevel == ConfidenceLevel.ask &&
      cleanName.isNotEmpty;

  /// The name added to the list — always the headline the review shows.
  String get listName => leadsWithWrittenText ? cleanName : displayName;

  /// Only a match the person can see as the headline is linked.
  String? get listCanonicalItemId =>
      leadsWithWrittenText ? null : canonicalItemId;
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
    this.engine = 'ppocrv6-small-det-medium-rec-onnx',
    this.needsReview = false,
  });
}
