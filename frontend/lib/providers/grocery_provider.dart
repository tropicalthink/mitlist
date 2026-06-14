import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/grocery_repository.dart';
import '../services/restock_service.dart';
import '../services/scan/correction_memory_service.dart';
import '../services/scan/grocery_suggestion_service.dart';
import '../services/scan/scan_pipeline_service.dart';
import '../services/scan/static_embedding_service.dart';
export 'outbox_provider.dart' show connectivityServiceProvider;
import 'list_provider.dart';
import 'scan_provider.dart';

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
  final cloudSvc = await ref.watch(scanServiceProviderAsync.future);
  return ScanPipelineService(db: db, cloudFallback: cloudSvc);
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

/// Watches a group's grocery graph and keeps it up to date via SSE.
/// Attach this provider in any screen that needs fresh grocery data for a group.
final groceryGraphSyncProvider =
    FutureProvider.family<void, String>((ref, groupId) async {
  final sseService = ref.watch(sseServiceProvider);
  final repo = await ref.watch(groceryRepositoryProvider.future);
  repo.attachSse(sseService, groupId);
  // Initial pull to hydrate from server on first attach.
  await repo.pullDelta(groupId);
  ref.onDispose(repo.detachSse);
});
