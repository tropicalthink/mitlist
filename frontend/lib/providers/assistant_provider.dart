import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/assistant_service.dart';

final assistantServiceProviderAsync = FutureProvider<AssistantService>((ref) async {
  return AssistantService.create(ref);
});

