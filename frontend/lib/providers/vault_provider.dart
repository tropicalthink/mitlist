import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vault_service.dart';
import '../models/vault_models.dart';

final vaultServiceProviderAsync = FutureProvider<VaultService>((ref) async {
  return await VaultService.create(ref);
});

final vaultItemsByGroupProvider = FutureProvider.family<List<VaultItem>, String>((ref, groupId) async {
  final service = await ref.read(vaultServiceProviderAsync.future);
  return service.listVaultItems(groupId);
});
