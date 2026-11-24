import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'dart:async';

import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/providers/calendar_provider.dart';
import 'package:mitlist/providers/external_calendar_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show sseServiceProvider;
import 'package:mitlist/providers/presence_provider.dart'
    show boardMembersProvider;
import 'package:mitlist/services/sse_service.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/calendar/calendar_screen.dart';
import 'package:mitlist/widgets/app_card.dart';
import 'package:mitlist/widgets/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSse extends SseService {
  final _ctrl = StreamController<SseEvent>.broadcast();
  @override
  Future<void> connect(String groupId) async {}

  @override
  Stream<SseEvent> get events => _ctrl.stream;

  void emit(SseEvent e) => _ctrl.add(e);

  @override
  void dispose() {
    _ctrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const groupId = '11111111-1111-1111-1111-111111111111';

  Group group() => Group(
        id: groupId,
        name: 'Home',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  CalendarEvent todayEvent() => CalendarEvent(
        id: 'e1',
        type: CalendarEventType.chore,
        title: 'Team dinner',
        date: DateTime.now(),
        groupId: groupId,
      );

  // Someone in the household shares a calendar with it (no first-run hint).
  final sharing = [
    const CalendarConnection(
      id: 'c1',
      kind: CalendarConnectionKind.ics,
      name: 'Work',
      calendars: [
        ExternalCalendar(
          id: 'k1',
          externalId: 'x',
          name: 'Work',
          shares: [
            CalendarShare(groupId: groupId, visibility: ShareVisibility.busy),
          ],
        ),
      ],
    ),
  ];

  late _FakeSse sse;
  late int fetches;

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<CalendarEvent> events,
    List<CalendarConnection>? connections,
  }) async {
    sse = _FakeSse();
    fetches = 0;
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group()]),
          calendarEventsProvider.overrideWith((ref, range) async {
            fetches++;
            return events;
          }),
          sseServiceProvider.overrideWithValue(sse),
          boardMembersProvider.overrideWith((ref, id) async => const [
                GroupMemberProfile(
                    userId: 'me', displayName: 'Mia', role: 'owner'),
                GroupMemberProfile(
                    userId: 'sam', displayName: 'Sam Lee', role: 'member'),
                GroupMemberProfile(
                    userId: 'ana', displayName: 'Ana', role: 'member'),
                GroupMemberProfile(
                    userId: 'kim', displayName: 'Kim', role: 'member'),
              ]),
          currentUserIdProvider.overrideWith((ref) async => 'me'),
          calendarConnectionsProvider
              .overrideWith((ref) async => connections ?? sharing),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders the loaded events (week view, no lingering skeleton)',
      (tester) async {
    await pumpCalendar(tester, events: [todayEvent()]);

    expect(find.text('Team dinner'), findsWidgets);
    expect(find.byType(AppSkeleton), findsNothing);
  });

  testWidgets('navigating weeks keeps last data visible instead of blanking',
      (tester) async {
    await pumpCalendar(tester, events: [todayEvent()]);
    expect(find.text('Team dinner'), findsWidgets);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CalendarScreen)),
    )!;

    // Previous week: the range key changes and refetches, but the screen must
    // never fall back to skeletons (the regression this refactor fixed).
    await tester.tap(find.byTooltip(l10n.calendarPreviousWeek));
    await tester.pump();
    expect(find.byType(AppSkeleton), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Back to the current week — event is in range again.
    await tester.tap(find.byTooltip(l10n.calendarNextWeek));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Team dinner'), findsWidgets);
  });

  String hm(int hour) => DateFormat.jm('en').format(DateTime(2026, 1, 1, hour));

  DateTime today0() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  CalendarEvent shared(
    String id,
    String user, {
    required DateTime start,
    required DateTime end,
    String title = '',
    bool busyOnly = true,
    bool allDay = false,
    bool free = false,
  }) =>
      CalendarEvent.fromJson({
        'id': id,
        'type': 'external_event',
        'title': title,
        'date': (allDay
                ? DateTime.utc(start.year, start.month, start.day)
                : start.toUtc())
            .toIso8601String(),
        'group_id': groupId,
        'external': {
          'user_id': user,
          'starts_at': (allDay
                  ? DateTime.utc(start.year, start.month, start.day)
                  : start.toUtc())
              .toIso8601String(),
          'ends_at': (allDay
                  ? DateTime.utc(end.year, end.month, end.day)
                  : end.toUtc())
              .toIso8601String(),
          'all_day': allDay,
          'busy_only': busyOnly,
          'free': free,
        },
      });

  testWidgets('a busy-only block shows who and "Busy", never a title',
      (tester) async {
    final t = today0();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 18)),
          end: t.add(const Duration(hours: 20)),
          // Even if a title slipped into the payload, busy-only hides it.
          title: 'Job interview'),
    ]);
    expect(find.textContaining('Job interview'), findsNothing);
    expect(find.textContaining('Busy'), findsWidgets);
    expect(find.textContaining('Sam Lee'), findsWidgets);
    expect(find.textContaining('${hm(18)} – ${hm(20)}'), findsWidgets);
  });

  testWidgets('a block shared with titles shows its title', (tester) async {
    final t = today0();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 18)),
          end: t.add(const Duration(hours: 20)),
          title: 'Climbing',
          busyOnly: false),
    ]);
    expect(find.textContaining('Climbing'), findsWidgets);
  });

  testWidgets('a multi-day event shows on each day it covers', (tester) async {
    final t = today0();
    // en_US weeks start on Sunday.
    final ws = t.subtract(Duration(days: t.weekday % 7));
    await pumpCalendar(tester, events: [
      shared('ext:trip', 'ana',
          start: ws,
          end: ws.add(const Duration(days: 3)),
          allDay: true,
          title: 'Lisbon',
          busyOnly: false),
    ]);
    expect(find.textContaining('Lisbon'), findsNWidgets(3));
    expect(find.textContaining('All day'), findsNWidgets(3));
  });

  testWidgets('free events are drawn lighter and marked free', (tester) async {
    final t = today0();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 9)),
          end: t.add(const Duration(hours: 10)),
          free: true),
    ]);
    expect(find.textContaining('· free'), findsOneWidget);
  });

  /// A day of the current week that is not today (statuses for today
  /// depend on the clock).
  DateTime otherDay() {
    final t = today0();
    final ws = t.subtract(Duration(days: t.weekday % 7));
    return t == ws ? ws.add(const Duration(days: 1)) : ws;
  }

  Future<void> selectDay(WidgetTester tester, DateTime day) async {
    await tester.tap(find.text(DateFormat.EEEE('en').format(day)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets("who's around: free from, away, not sharing, and the evening",
      (tester) async {
    final d = otherDay();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: d.add(const Duration(hours: 18)),
          end: d.add(const Duration(hours: 20))),
      shared('ext:2', 'ana',
          start: d, end: d.add(const Duration(days: 1)), allDay: true),
    ]);
    await selectDay(tester, d);
    final card = find.byKey(const ValueKey('calendar-whos-around'));
    expect(card, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-whos-around-toggle')));
    await tester.pump();
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.textContaining(text));
    expect(inCard("Who's around"), findsOneWidget);
    expect(inCard('Free from ${hm(20)}'), findsOneWidget);
    expect(inCard('Busy ${hm(18)} – ${hm(20)}'), findsOneWidget);
    expect(inCard('Away all day'), findsOneWidget);
    // The viewer shares a calendar here too and has nothing on.
    expect(inCard('You'), findsOneWidget);
    expect(inCard('Free all day'), findsOneWidget);
    // Kim shares nothing: never counted as free.
    expect(inCard("Doesn't share a calendar"), findsOneWidget);
    expect(inCard('Not everyone who shares is free in the evening'),
        findsOneWidget);
  });

  testWidgets("who's around says when everyone who shares is free",
      (tester) async {
    final d = otherDay();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: d.add(const Duration(hours: 17)),
          end: d.add(const Duration(hours: 19))),
    ]);
    await selectDay(tester, d);
    expect(find.text('Everyone who shares is free from ${hm(19)}'),
        findsOneWidget);
  });

  testWidgets('the selected day is marked and announced as selected',
      (tester) async {
    final d = otherDay();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: d.add(const Duration(hours: 9)),
          end: d.add(const Duration(hours: 10))),
    ]);
    await selectDay(tester, d);
    final header = find.ancestor(
      of: find.text(DateFormat.EEEE('en').format(d)),
      matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.selected ?? false)),
    );
    expect(header, findsWidgets);
  });

  testWidgets('a calendar:external_changed event refetches', (tester) async {
    await pumpCalendar(tester, events: [todayEvent()]);
    final before = fetches;
    sse.emit(const SseEvent(
        type: 'calendar:external_changed',
        groupId: groupId,
        payload: {'user_id': 'sam'}));
    sse.emit(const SseEvent(
        type: 'calendar:external_changed',
        groupId: 'another-group',
        payload: {'user_id': 'sam'}));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(fetches, before + 1);
  });

  testWidgets('first run: a hint leads to shared calendars; Not now hides it',
      (tester) async {
    await pumpCalendar(tester, events: [todayEvent()], connections: const []);
    expect(find.byKey(const ValueKey('calendar-share-hint')), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(find.byKey(const ValueKey('calendar-share-hint')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calendar_share_hint_dismissed'), isTrue);
  });

  testWidgets('no hint once someone in the household shares', (tester) async {
    final t = today0();
    await pumpCalendar(tester, connections: const [], events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 18)),
          end: t.add(const Duration(hours: 20))),
    ]);
    expect(find.byKey(const ValueKey('calendar-share-hint')), findsNothing);
  });

  testWidgets("who's around is compact by default, badges say each status",
      (tester) async {
    final semantics = tester.ensureSemantics();
    final d = otherDay();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: d.add(const Duration(hours: 18)),
          end: d.add(const Duration(hours: 20))),
      shared('ext:2', 'ana',
          start: d, end: d.add(const Duration(days: 1)), allDay: true),
    ]);
    await selectDay(tester, d);
    final card = find.byKey(const ValueKey('calendar-whos-around'));
    // Compact: no per-person rows, at most about 130dp for these members.
    expect(find.descendant(of: card, matching: find.text('Sam Lee')),
        findsNothing);
    expect(tester.getSize(card).height, lessThanOrEqualTo(132));
    String badgeLabel(String id) => tester
        .getSemantics(find.byKey(ValueKey('whos-around-badge-$id')))
        .label;
    expect(badgeLabel('sam'), 'Sam Lee: Free from ${hm(20)}');
    expect(badgeLabel('ana'), 'Ana: Away all day');
    expect(badgeLabel('kim'), "Kim: Doesn't share a calendar");
    expect(find.byTooltip("Show everyone's times"), findsOneWidget);

    // Expand, then collapse again.
    await tester.tap(find.byKey(const ValueKey('calendar-whos-around-toggle')));
    await tester.pump();
    expect(find.descendant(of: card, matching: find.text('Sam Lee')),
        findsOneWidget);
    expect(find.byTooltip('Show less'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-whos-around-toggle')));
    await tester.pump();
    expect(find.descendant(of: card, matching: find.text('Sam Lee')),
        findsNothing);
    semantics.dispose();
  });

  testWidgets('today is the badge only; the selected day is the filled card',
      (tester) async {
    final t = today0();
    final d = otherDay();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 9)),
          end: t.add(const Duration(hours: 10))),
      shared('ext:2', 'sam',
          start: d.add(const Duration(hours: 9)),
          end: d.add(const Duration(hours: 10))),
    ]);
    AppCardVariant variantOf(DateTime day) => tester
        .widget<AppCard>(find
            .ancestor(
                of: find.text(DateFormat.EEEE('en').format(day)),
                matching: find.byType(AppCard))
            .first)
        .variant;
    // Today selected (the default).
    expect(variantOf(t), AppCardVariant.filled);
    expect(find.text('Today'), findsWidgets);
    // Another day selected: today goes back to an outlined card.
    await selectDay(tester, d);
    expect(variantOf(d), AppCardVariant.filled);
    expect(variantOf(t), AppCardVariant.outlined);
  });
}
