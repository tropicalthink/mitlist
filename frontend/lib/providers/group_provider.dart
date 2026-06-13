import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_models.dart';
import '../services/group_service.dart';

/// Provider for the GroupService instance.
final groupServiceProviderAsync = FutureProvider<GroupService>((ref) async {
  return await GroupService.create(ref);
});

/// Cached household list shared across screens. Call
/// `ref.invalidate(cachedGroupsProvider)` after create/join household.
final cachedGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final groupSvc = await ref.read(groupServiceProviderAsync.future);
  return groupSvc.listGroups(limit: 50);
});
