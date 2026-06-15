import 'dart:typed_data';
import 'package:uuid/uuid.dart';

import '../../storage/app_database.dart';
import 'canonical_resolver_service.dart';
import 'confidence_service.dart';
import 'correction_memory_service.dart';
import 'enhancement_service.dart';
import 'extraction_service.dart';
import 'grocery_classifier_service.dart';
import 'ocr_service.dart';
import 'static_embedding_service.dart';
import 'scan_models.dart';

const _uuid = Uuid();

/// Single entry point for the grocery scan pipeline.
///
/// Flow: enhance → OCR → extract → resolve → aisle → confidence
class ScanPipelineService {
  final AppDatabase _db;
  final EnhancementService _enhancement;
  final OcrService _ocr;
  final ExtractionService _extraction;
  final CanonicalResolverService _resolver;
  final CorrectionMemoryService _corrections;
  final ConfidenceService _confidence;

  ScanPipelineService({
    required AppDatabase db,
  })  : _db = db,
        _enhancement = EnhancementService(),
        _ocr = OcrService(),
        _extraction = ExtractionService(),
        _resolver = CanonicalResolverService(
          db,
          classifier: GroceryClassifierService(),
          embedder: StaticEmbeddingService(),
        ),
        _corrections = CorrectionMemoryService(db),
        _confidence = ConfidenceService();

  // Expose the correction service so the review screen can record fixes.
  CorrectionMemoryService get corrections => _corrections;

  Future<GroceryScanResult> run({
    required Uint8List imageBytes,
    required String groupId,
    String? storeId,
    bool isOnline = true,
  }) async {
    // 1. Enhance.
    final enhanced = _enhancement.enhance(imageBytes);

    // 2. OCR.
    final lines = await _ocr.recognise(enhanced);

    // 3. Extract qty / unit / price / name.
    final parsed = _extraction.extractAll(lines);

    // 4. Canonical resolve + confidence.
    final predictions = <GroceryPrediction>[];
    final ignored = <GroceryPrediction>[];

    for (final item in parsed) {
      final resolved = await _resolver.resolve(item.itemName, groupId);

      // 5. Aisle assignment. With a store selected, use its shipped layout
      //    (shopping-path sort order); otherwise fall back to the item's
      //    category as a coarse aisle label.
      String? aisle;
      int aisleSortOrder = 99;
      if (resolved.canonicalItemId != null) {
        if (storeId != null) {
          final aisleRow = await _db.getStoreAisle(
            groupId: groupId,
            storeId: storeId,
            canonicalItemId: resolved.canonicalItemId!,
          );
          aisle = aisleRow?.aisle;
          aisleSortOrder = aisleRow?.sortOrder ?? 99;
        }

        // Fall back to category-level default from canonical item.
        if (aisle == null) {
          final canonical = await _db.getCanonicalItemById(resolved.canonicalItemId!);
          aisle = canonical?.category;
        }
      }

      final prediction = _confidence.applyTo(
        GroceryPrediction(
          id: _uuid.v4(),
          rawText: item.rawText,
          displayName: resolved.displayName,
          canonicalItemId: resolved.canonicalItemId,
          quantity: item.quantity,
          unit: item.unit,
          priceCents: item.priceCents,
          markStatus: item.markStatus,
          alternatives: resolved.alternatives,
          aisle: aisle,
          aisleSortOrder: aisleSortOrder,
        ),
        resolved.score,
      );

      if (item.markStatus == MarkStatus.crossedOut ||
          item.markStatus == MarkStatus.checked) {
        ignored.add(prediction);
      } else {
        predictions.add(prediction);
      }
    }

    // Sort by aisle order so the list follows the shopping path.
    predictions.sort((a, b) => a.aisleSortOrder.compareTo(b.aisleSortOrder));

    final needsReview = predictions.any(
      (p) => p.confidenceLevel != ConfidenceLevel.autoAccept,
    );

    return GroceryScanResult(
      imageBytes: imageBytes,
      items: predictions,
      ignored: ignored,
      engine: 'mlkit',
      needsReview: needsReview,
    );
  }
}
