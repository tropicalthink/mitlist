import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/grocery_repository.dart';
import '../services/scan/correction_memory_service.dart';
import '../services/scan/grocery_suggestion_service.dart';
import '../services/scan/scan_pipeline_service.dart';
import '../services/connectivity_service.dart';
import 'list_provider.dart';
import 'scan_provider.dart';


final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Local, offline grocery autocomplete over the canonical seed (alias-powered).
final grocerySuggestionServiceProvider =
    Provider<GrocerySuggestionService>((ref) {
  return GrocerySuggestionService(ref.watch(appDatabaseProvider));
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
