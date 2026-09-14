import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_service.dart';
import 'push_subscription_service.dart';

enum PushPermissionOutcome {
  /// The OS allowed it and the device is registered with the backend.
  granted,

  /// The user refused, or the OS refused on their behalf (Android stops
  /// showing the dialog after two refusals). Only the phone's settings can
  /// change this now.
  denied,

  /// Nothing to ask on this platform or build (desktop, debug web, no
  /// Firebase config).
  unsupported,
}

/// One door to the platform-specific push permission: FCM on Android and
/// iOS, VAPID subscriptions on web, nothing elsewhere.
class PushPermission {
  static bool get isSupported => kIsWeb || FcmService.isSupported;

  /// Whether this device can already receive push, read without prompting.
  static Future<bool> isGranted() async {
    if (kIsWeb) return PushSubscriptionService().isSubscribed();
    return FcmService.hasPermission();
  }

  /// Shows the platform prompt and enrols the device when allowed.
  static Future<PushPermissionOutcome> request(Dio dio) async {
    if (kIsWeb) {
      final web = PushSubscriptionService();
      await web.init();
      return await web.isSubscribed()
          ? PushPermissionOutcome.granted
          : PushPermissionOutcome.denied;
    }
    if (!FcmService.isSupported) return PushPermissionOutcome.unsupported;
    final status = await FcmService.requestPermission(dio);
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermissionOutcome.granted,
      AuthorizationStatus.denied => PushPermissionOutcome.denied,
      AuthorizationStatus.notDetermined => PushPermissionOutcome.unsupported,
    };
  }
}
