import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/list_service.dart';
import '../models/list_models.dart';

final listServiceProviderAsync = FutureProvider<ListService>((ref) async {
  return await ListService.create(ref);
});

final listsByGroupProvider = FutureProvider.family<List<ItemList>, String>((ref, groupId) async {
  final service = await ref.read(listServiceProviderAsync.future);
  return service.listLists(groupId);
});

final listItemsProvider = FutureProvider.family<List<ListItem>, String>((ref, listId) async {
  final service = await ref.read(listServiceProviderAsync.future);
  return service.listItems(listId);
});
