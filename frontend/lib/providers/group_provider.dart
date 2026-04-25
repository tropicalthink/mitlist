import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/group_service.dart';

/// Provider for the GroupService instance.
final groupServiceProviderAsync = FutureProvider<GroupService>((ref) async {
  return await GroupService.create(ref);
});
