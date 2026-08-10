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

/// Cached household list shared across screens.
///
/// Resolves from the Drift cache **without waiting on the network** and
/// refreshes in the background. Every screen's `_resolveGroupId()` awaits this,
/// so a blocking read here stalls the whole app behind one request.
///
/// After creating or joining a household the cache is stale by definition —
/// use [refreshCachedGroups], not a bare `ref.invalidate`, or the new household
/// will be missing from the very read that is supposed to find it.
///
/// Rebuilds when [authStateProvider] flips so a stale 401 from a prior session
/// is not reused after sign-in.
final cachedGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final isAuthenticated = ref.watch(authStateProvider);
  if (!isAuthenticated) return const [];

  final repo = await ref.read(groupRepositoryProvider.future);
  return repo.loadGroups(limit: 50);
});

/// Brings the household cache up to date, then rebuilds [cachedGroupsProvider]
/// so the next read sees it. The correct call after any change to household
/// membership or settings.
///
/// Pass [ensure] with the household a create/join flow just received. It is
/// written to the cache directly, so the new household is present even if the
/// refetch below fails — which is precisely when it matters, since a flaky
/// network would otherwise leave the user staring at an error for a household
/// the server has already accepted.
///
/// The network refresh is best-effort and never throws: the caller's own API
/// call already succeeded or failed on its own terms, and failing a completed
/// action because a cache warm-up failed would be a lie about what happened.
Future<void> refreshCachedGroups(WidgetRef ref, {Group? ensure}) async {
  final repo = await ref.read(groupRepositoryProvider.future);
  if (ensure != null) await repo.cacheGroup(ensure);
  try {
    await repo.refreshGroups(limit: 50);
  } catch (_) {
    // Offline or server down. The cache still holds [ensure]; the background
    // refresh in loadGroups reconciles later.
  }
  ref.invalidate(cachedGroupsProvider);
}

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
