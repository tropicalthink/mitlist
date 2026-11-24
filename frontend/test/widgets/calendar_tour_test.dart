import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/external_calendar_provider.dart';
import 'package:mitlist/services/calendar_tour.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/calendar_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_external_calendar.dart';

final _calendarButton = GlobalKey();
final _shareButton = GlobalKey();
final _addButtons = GlobalKey();

class _CalendarStandIn extends ConsumerStatefulWidget {
  const _CalendarStandIn();
  @override
  ConsumerState<_CalendarStandIn> createState() => _CalendarStandInState();
}

class _CalendarStandInState extends ConsumerState<_CalendarStandIn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        continueCalendarTourOnCalendar(context, ref,
            shareButton: _shareButton));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: [
          IconButton(
              key: _shareButton,
              tooltip: 'share',
              onPressed: () {},
              icon: const Icon(Icons.group)),
        ]),
        body: const Text('calendar page'),
      );
}

class _SharedStandIn extends ConsumerStatefulWidget {
  const _SharedStandIn();
  @override
  ConsumerState<_SharedStandIn> createState() => _SharedStandInState();
}

class _SharedStandInState extends ConsumerState<_SharedStandIn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => runSharedCalendarsTour(context, ref, addButtons: _addButtons));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: SizedBox(
                key: _addButtons,
                width: 300,
                height: 120,
                child: const Text('add buttons'))),
      );
}

void main() {
  late FakeExternalCalendarService api;
  late DateTime now;
  late bool otherPromo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeExternalCalendarService();
    now = DateTime(2026, 11, 24, 12);
    otherPromo = false;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            appBar: AppBar(actions: [
              IconButton(
                  key: _calendarButton,
                  tooltip: 'calendar',
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month)),
            ]),
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => maybeStartCalendarTour(context, ref,
                    calendarButton: _calendarButton,
                    onboardingDone: true,
                    otherPromoThisVisit: otherPromo),
                child: const Text('home visit'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/calendar',
          name: 'calendar',
          builder: (context, state) => const _CalendarStandIn(),
        ),
        GoRoute(
          path: '/you/calendars',
          name: 'sharedCalendars',
          builder: (context, state) => const _SharedStandIn(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => true),
        currentUserIdProvider.overrideWith((ref) async => 'maya'),
        externalCalendarServiceProvider.overrideWith((ref) async => api),
        calendarTourClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        theme: MitlistTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> visitHome(WidgetTester tester) async {
    await tester.tap(find.text('home visit'));
    await tester.pumpAndSettle();
  }

  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('three steps across Home, Calendar and Shared calendars',
      (tester) async {
    await pumpApp(tester);
    await visitHome(tester);
    expect(find.text(l10n.calendarTourHome), findsOneWidget);
    expect(find.bySemanticsLabel('Tip 1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await tester.pumpAndSettle();
    expect(find.text('calendar page'), findsOneWidget);
    expect(find.text(l10n.calendarTourShare), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await tester.pumpAndSettle();
    expect(find.text('add buttons'), findsOneWidget);
    expect(find.text(l10n.calendarTourAdd), findsOneWidget);
    // The last step has no Skip.
    expect(find.byKey(const ValueKey('coachMark-skip')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarTourAdd), findsNothing);

    // Recorded per account; the calendar's own hint stays away.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(CalendarTourStore.key('maya')), isNotNull);
    expect(prefs.getBool(calendarShareHintPref), isTrue);
  });

  testWidgets('Skip ends it, counted as shown; not again the next visit',
      (tester) async {
    await pumpApp(tester);
    await visitHome(tester);
    await tester.tap(find.byKey(const ValueKey('coachMark-skip')));
    await tester.pumpAndSettle();
    expect(find.text('calendar page'), findsNothing);
    await visitHome(tester);
    expect(find.text(l10n.calendarTourHome), findsNothing);
    // 42 days later, still nothing connected: again.
    now = now.add(const Duration(days: 42));
    await visitHome(tester);
    expect(find.text(l10n.calendarTourHome), findsOneWidget);
  });

  testWidgets('never once a calendar is connected', (tester) async {
    api.connections = [
      const CalendarConnection(
          id: 'c1', kind: CalendarConnectionKind.ics, name: 'Work'),
    ];
    await pumpApp(tester);
    await visitHome(tester);
    expect(find.text(l10n.calendarTourHome), findsNothing);
  });

  testWidgets('not on a visit that showed another promo', (tester) async {
    otherPromo = true;
    await pumpApp(tester);
    await visitHome(tester);
    expect(find.text(l10n.calendarTourHome), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(CalendarTourStore.key('maya')), isNull);
  });

  testWidgets('back on the first step ends the tour', (tester) async {
    await pumpApp(tester);
    await visitHome(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(l10n.calendarTourHome), findsNothing);
    expect(find.text('calendar page'), findsNothing);
  });
}
