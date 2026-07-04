import 'package:flutter/foundation.dart';

class PushSubscriptionService {
  PushSubscriptionService([Object? tokenStore]);

  Future<void> init() async {
    if (!kReleaseMode) return;
  }

  Future<void> unsubscribe() async {}
}
