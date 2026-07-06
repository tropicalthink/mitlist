import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/list_models.dart';
import '../repositories/list_repository.dart';
import '../services/grocery_seed_loader.dart';
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

/// Runs the grocery seed on first launch (no-op if already seeded).
/// Watch this in the app shell to ensure seed is loaded before first scan.
final grocerySeedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await GrocerySeedLoader(db).loadIfNeeded();
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
