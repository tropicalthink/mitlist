import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/template_service.dart';

final templateServiceProviderAsync = FutureProvider<TemplateService>((ref) async {
  return TemplateService.create(ref);
});

