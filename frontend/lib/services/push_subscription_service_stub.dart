import 'package:flutter/foundation.dart';

class PushSubscriptionService {
  PushSubscriptionService([Object? tokenStore]);

  Future<void> init() async {
    if (!kReleaseMode) return;
  }

  Future<bool> isSubscribed() async => false;

  Future<void> unsubscribe() async {}
}
