import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_models.dart';
import '../services/group_service.dart';
import 'auth_provider.dart' show authStateProvider;

/// Provider for the GroupService instance.
final groupServiceProviderAsync = FutureProvider<GroupService>((ref) async {
  return await GroupService.create(ref);
});

/// Cached household list shared across screens. Call
/// `ref.invalidate(cachedGroupsProvider)` after create/join household.
///
/// Rebuilds when [authStateProvider] flips so a stale 401 from a prior session
/// is not reused after sign-in.
final cachedGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final isAuthenticated = ref.watch(authStateProvider);
  if (!isAuthenticated) return const [];

  final groupSvc = await ref.read(groupServiceProviderAsync.future);
  return groupSvc.listGroups(limit: 50);
});
