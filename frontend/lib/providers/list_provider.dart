import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/list_models.dart';
import '../repositories/list_repository.dart';
import '../services/grocery_reference_installer.dart';
import '../services/list_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';

/// Singleton SSE service. Disposed when the Riverpod container tears down.
final sseServiceProvider = Provider<SseService>((ref) {
  final svc = SseService();
  ref.onDispose(svc.dispose);
  return svc;
});

final listServiceProviderAsync = FutureProvider<ListService>((ref) async {
  return await ListService.create(ref);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Installs the prebuilt global grocery reference DB (a version-gated file copy
/// of a bundled asset — no row inserts) and attaches it to [AppDatabase] so the
/// grocery read methods can merge global reference rows with household rows.
///
/// Named `grocerySeedProvider` for continuity with its existing watch sites.
/// Completes in milliseconds–~1s, so awaiting it on a hot path (canonical
/// linking) no longer stalls an add. Kept alive so its `AsyncData` state
/// persists for the app's lifetime.
final grocerySeedProvider = FutureProvider<void>((ref) async {
  ref.keepAlive();
  final db = ref.watch(appDatabaseProvider);
  final reference = await GroceryReferenceInstaller(db).installAndOpen();
  db.attachReference(reference);
  ref.onDispose(reference.close);
});

/// Live per-list (open, total) item counts for the hub cards' "N left" label.
/// Straight from the local DB; lists never synced locally have no entry and
/// cards fall back to the server-provided item_count.
final listItemCountsProvider =
    StreamProvider.family<Map<String, ({int open, int total})>, String>(
        (ref, groupId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchItemCountsByGroup(groupId);
});

final listRepositoryProvider = FutureProvider<ListRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(listServiceProviderAsync.future);
  return ListRepository(db: db, remote: service);
});

// ---------------------------------------------------------------------------
// Offline-first cached streams (DB-first)
// ---------------------------------------------------------------------------

final cachedListsByGroupProvider =
    StreamProvider.family<List<ItemList>, String>((ref, groupId) async* {
  ref.keepAlive();
  final repo = await ref.watch(listRepositoryProvider.future);
  yield* repo.watchListsByGroup(groupId);
});

final cachedListItemsProvider =
    StreamProvider.family<List<ListItem>, String>((ref, listId) async* {
  ref.keepAlive();
  final repo = await ref.watch(listRepositoryProvider.future);
  yield* repo.watchItemsByList(listId);
});

// Keep existing network-only providers for now (used in some flows).
final listsByGroupProvider =
    FutureProvider.family<List<ItemList>, String>((ref, groupId) async {
  final service = await ref.read(listServiceProviderAsync.future);
  return service.listLists(groupId);
});

final listItemsProvider =
    FutureProvider.family<List<ListItem>, String>((ref, listId) async {
  final service = await ref.read(listServiceProviderAsync.future);
  return service.listItems(listId);
});
