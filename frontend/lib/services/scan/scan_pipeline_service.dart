import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:uuid/uuid.dart';

import '../../storage/app_database.dart';
import 'canonical_resolver_service.dart';
import 'confidence_service.dart';
import 'correction_memory_service.dart';
import 'document_rectifier_service.dart';
import 'enhancement_service.dart';
import 'extraction_service.dart';
import 'grocery_classifier_service.dart';
import 'ocr_service.dart';
import 'static_embedding_service.dart';
import 'scan_models.dart';

const _uuid = Uuid();

/// Single entry point for the grocery scan pipeline.
///
/// Flow: rectify → enhance → OCR → extract → resolve → aisle → confidence
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
          // Plan 037: the calibrated ensemble (candidate-union + household
          // prior + canonicalNameSim) — on the eval it lifts precision@auto
          // 73%→100% with no confident-wrong auto-accepts. Eager model voting
          // costs a bit more per line; both models are fast.
          useEnsemble: true,
        ),
        _corrections = CorrectionMemoryService(db),
        _confidence = ConfidenceService();

  // Expose the correction service so the review screen can record fixes.
  CorrectionMemoryService get corrections => _corrections;

  Future<GroceryScanResult> run({
    required Uint8List imageBytes,
    required String groupId,
    String? storeId,
    List<String> listContextCanonicalIds = const [],
    bool isOnline = true,
  }) async {
    // 1. Perspective rectify — find document quad and warp to flat rectangle.
    //    Runs on a worker isolate to avoid janking the UI.
    final rectified = await compute(_rectifyIsolate, imageBytes);

    // 2. OCR — uses the non-binarized image so the neural OCR engine (ML Kit)
    //     receives a natural photograph rather than an adaptive-thresholded
    //     binary image (which is out-of-distribution for modern neural models).
    //     The binarized preview is produced in the capture UI (smart_capture_launcher),
    //     not here.
    final forOcr = await _enhancement.enhanceForOcr(rectified);
    final lines = await _ocr.recognise(forOcr);

    // 3. Extract qty / unit / price / name.
    final parsed = _extraction.extractAll(lines);

    // 4. Canonical resolve + confidence.
    final predictions = <GroceryPrediction>[];
    final ignored = <GroceryPrediction>[];
    final aisleByCanonicalId = <String, StoreAislesTableData?>{};
    final canonicalById = <String, CanonicalItemsTableData?>{};

    // Build the household resolution context once per scan (purchase history +
    // co-occurrence) so it is not redundantly rebuilt for every scanned line.
    final resolutionContext = await _resolver.prepareContext(
      groupId,
      listContext: listContextCanonicalIds,
    );

    for (final item in parsed) {
      final resolved = await _resolver.resolve(
        item.itemName,
        groupId,
        listContext: listContextCanonicalIds,
        context: resolutionContext,
      );

      // 5. Aisle assignment. With a store selected, use its shipped layout
      //    (shopping-path sort order); otherwise fall back to the item's
      //    category as a coarse aisle label.
      String? aisle;
      int aisleSortOrder = 99;
      if (resolved.canonicalItemId != null) {
        final canonicalItemId = resolved.canonicalItemId!;
        if (storeId != null) {
          final row = aisleByCanonicalId.containsKey(canonicalItemId)
              ? aisleByCanonicalId[canonicalItemId]
              : await _db.getStoreAisle(
                  groupId: groupId,
                  storeId: storeId,
                  canonicalItemId: canonicalItemId,
                );
          if (!aisleByCanonicalId.containsKey(canonicalItemId)) {
            aisleByCanonicalId[canonicalItemId] = row;
          }
          aisle = row?.aisle;
          aisleSortOrder = row?.sortOrder ?? 99;
        }

        // Fall back to category-level default from canonical item.
        if (aisle == null) {
          final canonical = canonicalById.containsKey(canonicalItemId)
              ? canonicalById[canonicalItemId]
              : await _db.getCanonicalItemById(canonicalItemId);
          canonicalById[canonicalItemId] = canonical;
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
        autoThreshold: resolved.autoThreshold,
        reviewThreshold: resolved.reviewThreshold,
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

/// Top-level function used by [compute()] to run perspective rectification on
/// a worker isolate without blocking the UI thread.
Uint8List _rectifyIsolate(Uint8List bytes) {
  try {
    return const DocumentRectifierService().rectify(bytes).bytes;
  } catch (_) {
    return bytes;
  }
}
