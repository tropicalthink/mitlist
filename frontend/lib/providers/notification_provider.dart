import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import 'account_provider.dart';

final notificationServiceProviderAsync =
    FutureProvider<NotificationService>((ref) async {
  return NotificationService.create(ref);
});

/// The bell badge. Reads, marks and deletes still queued offline are taken
/// off the server's count (which offline is the last one it gave), so the
/// badge agrees with the inbox the user just cleared.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final service = await ref.watch(notificationServiceProviderAsync.future);
  final count = await service.countUnreadNotifications();
  try {
    final account = await ref.read(accountRepositoryProvider.future);
    return await account.unreadCountWithPending(count);
  } catch (_) {
    return count;
  }
});
