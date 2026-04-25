import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chore_service.dart';
import '../models/chore_models.dart';

final choreServiceProviderAsync = FutureProvider<ChoreService>((ref) async {
  return await ChoreService.create(ref);
});

final choresByGroupProvider = FutureProvider.family<List<Chore>, String>((ref, groupId) async {
  final service = await ref.read(choreServiceProviderAsync.future);
  return service.listChores(groupId);
});
