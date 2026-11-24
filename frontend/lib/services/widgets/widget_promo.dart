import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether Home offers the home screen widgets (the promo sheet).
///
/// Pure, so every rule is unit tested without a widget tree:
/// - never on a platform without widgets, and never before the person has
///   finished onboarding (signed in, with a household, on Home);
/// - never when a mitlist widget is already on the home screen;
/// - the first time: shown, even when native code cannot say what is
///   installed;
/// - after that: again every [repeatAfter], and only while native code
///   reports a known empty home screen. An unknown state is not asked twice.
class WidgetPromoDecision {
  const WidgetPromoDecision._();

  /// Six weeks between showings.
  static const Duration repeatAfter = Duration(days: 42);

  static bool shouldShow({
    required DateTime now,
    required DateTime? lastShownAt,
    required List<String>? installedKinds,
    required bool supported,
    required bool onboardingDone,
  }) {
    if (!supported || !onboardingDone) return false;
    if (installedKinds != null && installedKinds.isNotEmpty) return false;
    if (lastShownAt == null) return true;
    if (installedKinds == null) return false;
    return !now.isBefore(lastShownAt.add(repeatAfter));
  }
}

/// When the widget promo was last shown on this device. Kept across
/// sign-out on purpose: it is about this phone's home screen, not the
/// account.
class WidgetPromoStore {
  const WidgetPromoStore._();

  static const key = 'widget_promo_last_shown_at';

  static Future<DateTime?> lastShownAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> markShown(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, at.millisecondsSinceEpoch);
  }
}
