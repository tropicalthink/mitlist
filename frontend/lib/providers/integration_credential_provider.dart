import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/integration_credential_models.dart';
import '../services/integration_credential_service.dart';

final integrationCredentialServiceProvider =
    FutureProvider<IntegrationCredentialService>((ref) async {
  return IntegrationCredentialService.build(ref);
});

final integrationCredentialsProvider =
    FutureProvider<List<IntegrationCredential>>((ref) async {
  final service = await ref.watch(integrationCredentialServiceProvider.future);
  return service.list();
});
