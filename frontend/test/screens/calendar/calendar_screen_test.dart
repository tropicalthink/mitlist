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

  testWidgets("who's around: free, busy with times, away all day",
      (tester) async {
    final t = today0();
    await pumpCalendar(tester, events: [
      shared('ext:1', 'sam',
          start: t.add(const Duration(hours: 18)),
          end: t.add(const Duration(hours: 20))),
      shared('ext:2', 'ana',
          start: t, end: t.add(const Duration(days: 1)), allDay: true),
    ]);
    final card = find.byKey(const ValueKey('calendar-whos-around'));
    expect(card, findsOneWidget);
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.textContaining(text));
    expect(inCard("Who's around"), findsOneWidget);
    expect(inCard('Busy ${hm(18)} – ${hm(20)}'), findsOneWidget);
    expect(inCard('Away all day'), findsOneWidget);
    // The viewer shares a calendar here too and has nothing on: free.
    expect(inCard('You'), findsOneWidget);
    expect(inCard('Free'), findsOneWidget);
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
}
