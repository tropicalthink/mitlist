import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_models.dart';
import '../repositories/group_repository.dart';
import '../services/group_service.dart';
import 'auth_provider.dart' show authStateProvider;
import 'list_provider.dart' show appDatabaseProvider;

/// Provider for the GroupService instance.
final groupServiceProviderAsync = FutureProvider<GroupService>((ref) async {
  return await GroupService.create(ref);
});

/// Offline-first repository for the household list (Drift-cached).
final groupRepositoryProvider = FutureProvider<GroupRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(groupServiceProviderAsync.future);
  return GroupRepository(db: db, groups: service);
});

/// Cached household list shared across screens. Call
/// `ref.invalidate(cachedGroupsProvider)` after create/join household.
///
/// Reads come from the Drift cache and are refreshed from the network on each
/// resolve; when offline the cache is returned instead of throwing, so every
/// screen can resolve its active group offline. Rebuilds when
/// [authStateProvider] flips so a stale 401 from a prior session is not reused
/// after sign-in.
final cachedGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final isAuthenticated = ref.watch(authStateProvider);
  if (!isAuthenticated) return const [];

  final repo = await ref.read(groupRepositoryProvider.future);
  return repo.loadGroups(limit: 50);
});

/// Live stream of the cached household list for reactive widgets that want to
/// react to cache updates without re-resolving the network.
final watchGroupsProvider = StreamProvider<List<Group>>((ref) async* {
  final isAuthenticated = ref.watch(authStateProvider);
  if (!isAuthenticated) {
    yield const [];
    return;
  }
  final repo = await ref.read(groupRepositoryProvider.future);
  yield* repo.watchGroups();
});
