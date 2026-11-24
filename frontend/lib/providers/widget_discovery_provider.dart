import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/widgets/home_widget_kind.dart';
import 'home_widgets_provider.dart';

/// The platform whose widget instructions the app shows. A provider so
/// tests can render the Android and iOS variants.
final homeWidgetPlatformProvider =
    Provider<TargetPlatform>((ref) => defaultTargetPlatform);

/// The kinds of mitlist widgets on the home screen, as `HomeWidgetKind`
/// ids; null when native code cannot tell. The app invalidates it on
/// resume, so the Widgets page updates after someone adds a widget and
/// comes back.
///
/// Only known kinds count: native code may report ids this build has no
/// card for (a newer widget), and those are dropped rather than trusted.
final installedHomeWidgetsProvider = FutureProvider<List<String>?>((ref) async {
  final ids = await ref.watch(widgetBridgeProvider).installedWidgets();
  if (ids == null) return null;
  return [for (final kind in HomeWidgetKind.parseAll(ids)) kind.id];
});

/// Whether the launcher pins widgets in one tap (Android only).
final pinWidgetSupportedProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(homeWidgetPlatformProvider) != TargetPlatform.android) {
    return false;
  }
  return ref.watch(widgetBridgeProvider).isPinWidgetSupported();
});

/// The clock the widget promo reads; injectable for tests.
final widgetPromoClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);
