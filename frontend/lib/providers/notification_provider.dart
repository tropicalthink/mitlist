import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

final notificationServiceProviderAsync =
    FutureProvider<NotificationService>((ref) async {
  return NotificationService.create(ref);
});
