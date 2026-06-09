import 'dart:typed_data';
import 'package:uuid/uuid.dart';

import '../../services/scan_service.dart';
import '../../storage/app_database.dart';
import 'canonical_resolver_service.dart';
import 'confidence_service.dart';
import 'correction_memory_service.dart';
import 'enhancement_service.dart';
import 'extraction_service.dart';
import 'ocr_service.dart';
import 'routing_service.dart';
import 'scan_models.dart';

const _uuid = Uuid();

/// Single entry point for the grocery scan pipeline.
///
/// On-device flow (ML Kit):
///   enhance → OCR → routing decision → extract → resolve → aisle → confidence
///
/// Cloud fallback (CrofAI):
///   Called when routing says the on-device result is too low quality.
///   CrofAI items are wrapped into [GroceryPrediction]s without canonical
///   resolution (they pass through as-is for the user to confirm).
class ScanPipelineService {
  final AppDatabase _db;
  final ScanService _cloudFallback;
  final EnhancementService _enhancement;
  final OcrService _ocr;
  final RoutingService _routing;
  final ExtractionService _extraction;
  final CanonicalResolverService _resolver;
  final CorrectionMemoryService _corrections;
  final ConfidenceService _confidence;

  ScanPipelineService({
    required AppDatabase db,
    required ScanService cloudFallback,
  })  : _db = db,
        _cloudFallback = cloudFallback,
        _enhancement = EnhancementService(),
        _ocr = OcrService(),
        _routing = RoutingService(),
        _extraction = ExtractionService(),
        _resolver = CanonicalResolverService(db),
        _corrections = CorrectionMemoryService(db),
        _confidence = ConfidenceService();

  // Expose the correction service so the review screen can record fixes.
  CorrectionMemoryService get corrections => _corrections;

  Future<GroceryScanResult> run({
    required Uint8List imageBytes,
    required String groupId,
    bool isOnline = true,
  }) async {
    // 1. Enhance.
    final enhanced = _enhancement.enhance(imageBytes);

    // 2. OCR.
    final lines = await _ocr.recognise(enhanced);

    // 3. Route.
    final decision = _routing.decide(lines, isOnline: isOnline);

    if (!decision.useOnDevice) {
      return _runCloud(imageBytes);
    }

    // 4. Extract qty / unit / price / name.
    final parsed = _extraction.extractAll(lines);

    // 5. Canonical resolve + confidence.
    final predictions = <GroceryPrediction>[];
    final ignored = <GroceryPrediction>[];

    for (final item in parsed) {
      final resolved = await _resolver.resolve(item.itemName, groupId);

      // 6. Aisle assignment (best-effort from Drift, no store selected yet).
      String? aisle;
      int aisleSortOrder = 99;
      if (resolved.canonicalItemId != null) {
        final aisleRow = await _db.getStoreAisle(
          groupId: groupId,
          storeId: '__default__',
          canonicalItemId: resolved.canonicalItemId!,
        );
        aisle = aisleRow?.aisle;
        aisleSortOrder = aisleRow?.sortOrder ?? 99;

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

  /// Cloud fallback: calls CrofAI and wraps the items as unresolved predictions.
  Future<GroceryScanResult> _runCloud(Uint8List imageBytes) async {
    try {
      final result =
          await _cloudFallback.scanImage(imageBytes.toList(), 'image/jpeg');
      final predictions = result.items.map((item) {
        final qty = double.tryParse(item.quantity ?? '1') ?? 1;
        return _confidence.applyTo(
          GroceryPrediction(
            id: _uuid.v4(),
            rawText: item.name,
            displayName: item.name,
            quantity: qty,
            unit: item.unit ?? '',
            priceCents: item.priceCents,
          ),
          // Cloud result: moderate baseline confidence — user should confirm.
          0.7,
        );
      }).toList();

      return GroceryScanResult(
        imageBytes: imageBytes,
        items: predictions,
        engine: 'crofai',
        needsReview: true,
      );
    } catch (_) {
      // Cloud call failed. Return empty result so user can retry.
      return const GroceryScanResult(items: [], engine: 'crofai', needsReview: false);
    }
  }
}
