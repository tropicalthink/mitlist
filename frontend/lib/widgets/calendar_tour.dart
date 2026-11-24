import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/external_calendar_provider.dart';
import '../services/calendar_tour.dart';
import 'coach_mark.dart';

/// Clock for the tour's rules; overridden in tests.
final calendarTourClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// The calendar screen's own first-run hint points at the same thing: once
/// the tour has run, it stays away.
const calendarShareHintPref = 'calendar_share_hint_dismissed';

/// Whether [context]'s route is on top and its tab visible (no sheet,
/// dialog or pushed page over it).
bool _onTop(BuildContext context) =>
    (ModalRoute.of(context)?.isCurrent ?? true) &&
    TickerMode.valuesOf(context).enabled;

/// Starts the tour from Home when [CalendarTourDecision] says so. Returns
/// whether it started. [otherPromoThisVisit] is true when Home already
/// showed something this visit (the widget promo): then it waits.
Future<bool> maybeStartCalendarTour(
  BuildContext context,
  WidgetRef ref, {
  required GlobalKey calendarButton,
  required bool onboardingDone,
  required bool otherPromoThisVisit,
}) async {
  final signedIn = ref.read(authStateProvider);
  if (!signedIn || otherPromoThisVisit) return false;
  final String? userId;
  try {
    userId = await ref.read(currentUserIdProvider.future);
  } catch (_) {
    return false;
  }
  if (userId == null || !context.mounted) return false;
  final lastShownAt = await CalendarTourStore.lastShownAt(userId);
  bool? hasConnection;
  try {
    final service = await ref.read(externalCalendarServiceProvider.future);
    // Dio's own timeouts bound this; no extra timer here.
    final list = await service.listConnections();
    hasConnection = list.isNotEmpty;
  } catch (_) {
    hasConnection = null;
  }
  if (!context.mounted) return false;
  final now = ref.read(calendarTourClockProvider)();
  final show = CalendarTourDecision.shouldShow(
    now: now,
    lastShownAt: lastShownAt,
    hasConnection: hasConnection,
    signedIn: ref.read(authStateProvider),
    hasHousehold: true,
    onboardingDone: onboardingDone,
    otherPromoThisVisit: otherPromoThisVisit,
    somethingOnTop: !_onTop(context),
  );
  if (!show) return false;
  // Recorded before it opens: an app killed mid-tour has shown it.
  await CalendarTourStore.markShown(userId, now);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(calendarShareHintPref, true);
  if (!context.mounted) return false;
  final tour = ref.read(calendarTourProvider.notifier)..begin();
  final l10n = AppLocalizations.of(context)!;
  const total = 3;
  final result = await showCoachMark(
    context,
    target: calendarButton,
    message: l10n.calendarTourHome,
    step: 1,
    total: total,
  );
  if (result != CoachMarkResult.next || !context.mounted) {
    tour.end();
    return true;
  }
  tour.handOff(CalendarTourStep.calendarShare, index: 2, total: total);
  unawaited(context.pushNamed('calendar'));
  return true;
}

/// The calendar screen's step, when Home just handed it over.
Future<void> continueCalendarTourOnCalendar(
  BuildContext context,
  WidgetRef ref, {
  required GlobalKey shareButton,
}) async {
  final tour = ref.read(calendarTourProvider.notifier);
  final pending = tour.take(CalendarTourStep.calendarShare);
  if (pending == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final result = await showCoachMark(
    context,
    target: shareButton,
    message: l10n.calendarTourShare,
    step: pending.index,
    total: pending.total,
  );
  if (result != CoachMarkResult.next || !context.mounted) {
    tour.end();
    return;
  }
  tour.handOff(CalendarTourStep.sharedAdd,
      index: pending.index + 1, total: pending.total);
  unawaited(context.pushNamed('sharedCalendars'));
}

/// The Shared calendars page's steps: when the calendar screen just handed
/// over, or from "Show me how" ([replay]). The page decides which targets
/// exist: the choices only once a calendar exists, Upcoming only with
/// events.
Future<void> runSharedCalendarsTour(
  BuildContext context,
  WidgetRef ref, {
  required GlobalKey addButtons,
  GlobalKey? choices,
  GlobalKey? upcoming,
  bool replay = false,
}) async {
  final tour = ref.read(calendarTourProvider.notifier);
  var index = 1;
  if (!replay) {
    final pending = tour.take(CalendarTourStep.sharedAdd);
    if (pending == null) return;
    index = pending.index;
  } else {
    tour.begin();
  }
  final l10n = AppLocalizations.of(context)!;
  final steps = <(GlobalKey, String)>[
    (addButtons, l10n.calendarTourAdd),
    if (choices != null) (choices, l10n.calendarTourChoices),
    if (upcoming != null) (upcoming, l10n.calendarTourUpcoming),
  ];
  final total = index - 1 + steps.length;
  for (final (key, message) in steps) {
    if (!context.mounted) break;
    final result = await showCoachMark(
      context,
      target: key,
      message: message,
      step: index,
      total: total,
    );
    if (result != CoachMarkResult.next) break;
    index++;
  }
  tour.end();
}
