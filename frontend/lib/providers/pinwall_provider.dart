import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pinwall_models.dart';
import '../services/pinwall_service.dart';

final pinwallServiceProviderAsync = FutureProvider<PinwallService>((ref) async {
  return PinwallService.create(ref);
});

final pinwallPostsByGroupProvider =
    FutureProvider.family<List<PinwallPost>, String>((ref, groupId) async {
  final service = await ref.read(pinwallServiceProviderAsync.future);
  return service.listPosts(groupId, limit: 20, offset: 0);
});

