import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/share_target_service.dart';

final shareTargetServiceProviderAsync = FutureProvider<ShareTargetService>((ref) async {
  return ShareTargetService.create(ref);
});

