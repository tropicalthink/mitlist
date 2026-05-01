import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/list_models.dart';
import '../repositories/list_repository.dart';
import '../services/list_service.dart';
import '../storage/app_database.dart';

final listServiceProviderAsync = FutureProvider<ListService>((ref) async {
  return await ListService.create(ref);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
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
  final repo = await ref.watch(listRepositoryProvider.future);
  yield* repo.watchListsByGroup(groupId);
});

final cachedListItemsProvider =
    StreamProvider.family<List<ListItem>, String>((ref, listId) async* {
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
