import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinwall_media_models.dart';
import '../models/pinwall_models.dart';
import '../providers/list_provider.dart';
import '../repositories/pinwall_repository.dart';
import '../services/pinwall_service.dart';

final pinwallServiceProviderAsync = FutureProvider<PinwallService>((ref) async {
  return PinwallService.create(ref);
});

final pinwallRepositoryProvider =
    FutureProvider<PinwallRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(pinwallServiceProviderAsync.future);
  return PinwallRepository(
    db: db,
    remote: service,
    onLocalWrite: ref.watch(syncSchedulerProvider).noteLocalWrite,
  );
});

final pinwallMediaByPostProvider = FutureProvider.family<List<PinwallMediaItem>,
    ({String groupId, String postId})>(
  (ref, args) async {
    final svc = await ref.read(pinwallServiceProviderAsync.future);
    return svc.listPostAttachments(groupId: args.groupId, postId: args.postId);
  },
);

final pinwallPostsByGroupProvider =
    StreamProvider.family<List<PinwallPost>, String>((ref, groupId) async* {
  ref.keepAlive();
  final repo = await ref.watch(pinwallRepositoryProvider.future);
  final fresh = await repo.getFreshPosts(groupId);
  if (fresh != null) {
    yield fresh;
    yield* repo.watchPosts(groupId);
    return;
  }
  final cached = await repo.getPostsOnce(groupId);
  if (cached.isNotEmpty) {
    yield cached;
    // Best-effort background refresh.
    unawaited(
      repo.refreshPosts(groupId).catchError((_) {}),
    );
    // Keep yielding cache updates.
    yield* repo.watchPosts(groupId);
    return;
  }

  // No cache yet (fresh group / fresh install): fetch once so we don't render
  // an empty wall forever.
  try {
    await repo.refreshPosts(groupId);
  } catch (_) {
    // If refresh fails, still fall back to watching cache (may remain empty).
  }
  yield* repo.watchPosts(groupId);
});
