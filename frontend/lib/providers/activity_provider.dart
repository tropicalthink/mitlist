import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/activity_service.dart';

final activityServiceProviderAsync = FutureProvider<ActivityService>((ref) async {
  return ActivityService.create(ref);
});

