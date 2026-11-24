import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether Home starts the shared calendars tour (coach marks over
/// the real screens). Pure, so every rule is unit tested:
/// - only for a signed-in person with a household, after onboarding;
/// - never on a Home visit that already showed another promo (one thing
///   per visit; the tour waits for a later one), and never while a sheet,
///   dialog or another page is on top of Home;
/// - never once the person has any calendar connection;
/// - the first time: shown, even when the connection state is unknown;
/// - after that: again every [repeatAfter] while the person has connected
///   no calendar. An unknown state (offline, the request failed) is not
///   asked twice.
class CalendarTourDecision {
  const CalendarTourDecision._();

  /// Six weeks between showings, like the widget promo.
  static const Duration repeatAfter = Duration(days: 42);

  static bool shouldShow({
    required DateTime now,
    required DateTime? lastShownAt,
    required bool? hasConnection,
    required bool signedIn,
    required bool hasHousehold,
    required bool onboardingDone,
    required bool otherPromoThisVisit,
    required bool somethingOnTop,
  }) {
    if (!signedIn || !hasHousehold || !onboardingDone) return false;
    if (otherPromoThisVisit || somethingOnTop) return false;
    if (hasConnection == true) return false;
    if (lastShownAt == null) return true;
    if (hasConnection == null) return false;
    return !now.isBefore(lastShownAt.add(repeatAfter));
  }
}

/// When the tour was last shown to an account. Per account (another person
/// signing in on this phone gets their own), kept across sign-out.
class CalendarTourStore {
  const CalendarTourStore._();

  static String key(String userId) => 'calendar_tour_last_shown_at.$userId';

  static Future<DateTime?> lastShownAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(key(userId));
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> markShown(String userId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key(userId), at.millisecondsSinceEpoch);
  }
}

/// The tour's steps, each on the screen that owns its target.
enum CalendarTourStep {
  /// Home: the calendar button in the app bar.
  homeCalendar,

  /// Calendar: who's around, or the shared calendars button.
  calendarShare,

  /// Shared calendars: the add-a-calendar buttons.
  sharedAdd,

  /// Shared calendars, once a calendar exists: what each household sees.
  sharedChoices,

  /// Shared calendars, once events exist: hiding one event.
  sharedUpcoming,
}

/// A step handed from one screen to the next.
class PendingTourStep {
  const PendingTourStep({
    required this.step,
    required this.index,
    required this.total,
    required this.at,
  });

  final CalendarTourStep step;
  final int index;
  final int total;
  final DateTime at;
}

/// Carries the tour across screens. A screen shows its step only when the
/// previous screen just handed it over; anything else (the person went
/// elsewhere, backed out, waited) ends the tour, which still counts as
/// shown.
class CalendarTourController extends StateNotifier<PendingTourStep?> {
  CalendarTourController({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(null);

  /// A hand-off the next screen did not pick up within this ends the tour.
  static const handOffWindow = Duration(seconds: 10);

  final DateTime Function() _now;

  /// True from the first step until the tour ends.
  bool active = false;

  void begin() => active = true;

  void handOff(CalendarTourStep step,
      {required int index, required int total}) {
    active = true;
    state = PendingTourStep(step: step, index: index, total: total, at: _now());
  }

  /// The pending step if it is [step] and fresh; consumes it.
  PendingTourStep? take(CalendarTourStep step) {
    final pending = state;
    if (pending == null || pending.step != step) return null;
    state = null;
    if (_now().difference(pending.at) > handOffWindow) {
      end();
      return null;
    }
    return pending;
  }

  void end() {
    active = false;
    state = null;
  }
}

final calendarTourProvider =
    StateNotifierProvider<CalendarTourController, PendingTourStep?>(
        (ref) => CalendarTourController());
