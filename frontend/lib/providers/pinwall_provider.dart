import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinwall_models.dart';
import '../providers/list_provider.dart';
import '../repositories/pinwall_repository.dart';
import '../services/pinwall_service.dart';

final pinwallServiceProviderAsync = FutureProvider<PinwallService>((ref) async {
  return PinwallService.create(ref);
});

final pinwallRepositoryProvider = FutureProvider<PinwallRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(pinwallServiceProviderAsync.future);
  return PinwallRepository(db: db, remote: service);
});

final pinwallPostsByGroupProvider =
    StreamProvider.family<List<PinwallPost>, String>((ref, groupId) async* {
  final repo = await ref.watch(pinwallRepositoryProvider.future);
  final cached = await repo.getPostsOnce(groupId);
  if (cached.isNotEmpty) {
    yield cached;
  }
  // Keep yielding cache updates.
  yield* repo.watchPosts(groupId);
});

