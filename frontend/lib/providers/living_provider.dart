import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/living_service.dart';
import '../models/living_models.dart';

final livingServiceProviderAsync = FutureProvider<LivingService>((ref) async {
  return await LivingService.create(ref);
});

final livingThingsByGroupProvider = FutureProvider.family<List<LivingThing>, String>((ref, groupId) async {
  final service = await ref.read(livingServiceProviderAsync.future);
  return service.listLivingThings(groupId);
});
