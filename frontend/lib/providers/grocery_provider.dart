import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/grocery_repository.dart';
import '../services/restock_service.dart';
import '../services/scan/correction_memory_service.dart';
import '../services/scan/grocery_suggestion_service.dart';
import '../services/scan/scan_pipeline_service.dart';
import '../services/scan/static_embedding_service.dart';
export 'outbox_provider.dart' show connectivityServiceProvider;
import 'list_provider.dart';

/// On-device static semantic embedder (pure Dart, no ML runtime).
///
/// Loads the Model2Vec-distilled vocab + catalog bundles lazily. Returns an
/// instance that degrades gracefully (returns []) if the bundle is absent.
final staticEmbeddingServiceProvider = Provider<StaticEmbeddingService>((ref) {
  return StaticEmbeddingService();
});

/// Local, offline grocery autocomplete over the canonical seed (alias-powered).
/// When the embedder bundle is present, results are semantically blended.
final grocerySuggestionServiceProvider =
    Provider<GrocerySuggestionService>((ref) {
  return GrocerySuggestionService(
    ref.watch(appDatabaseProvider),
    embedder: ref.watch(staticEmbeddingServiceProvider),
  );
});

/// On-device purchase-cadence restock predictor. Pure reads, no network.
final restockServiceProvider = Provider<RestockService>((ref) {
  return RestockService(ref.watch(appDatabaseProvider));
});

final scanPipelineProvider = FutureProvider<ScanPipelineService>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return ScanPipelineService(db: db);
});

final correctionMemoryProvider = Provider<CorrectionMemoryService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CorrectionMemoryService(db);
});

/// Grocery graph repository — handles delta sync + SSE invalidation.
final groceryRepositoryProvider =
    FutureProvider<GroceryRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return GroceryRepository.create(db, ref);
});

/// Restock predictions for [groupId] — most-overdue grocery items the household
/// is due to rebuy, computed on-device from purchase cadence. Returns [] when
/// there is not enough history.
final runningLowProvider =
    FutureProvider.family<List<RestockSuggestion>, String>(
        (ref, groupId) async {
  return ref.read(restockServiceProvider).due(groupId: groupId, limit: 8);
});

/// Best-effort shell preload for the grocery graph.
///
/// This must stay bounded: the app shell watches it during normal navigation,
/// and widget tests should not be held open by a persistent SSE loop.
final groceryGraphSyncProvider =
    FutureProvider.family<void, String>((ref, groupId) async {
  final repo = await ref.watch(groceryRepositoryProvider.future);
  try {
    await repo.pullDelta(groupId).timeout(const Duration(seconds: 3));
  } catch (_) {
    // Non-critical preload; list and scan flows still work from local data.
  }
});
