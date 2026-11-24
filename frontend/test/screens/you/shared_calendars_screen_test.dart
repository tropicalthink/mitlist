import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/external_calendar_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/you/shared_calendars_screen.dart';
import 'package:mitlist/services/api_error_mapper.dart';
import 'package:mitlist/services/device_calendar/device_calendar_source.dart';
import 'package:mitlist/services/device_calendar/device_calendar_sync.dart';
import 'package:mitlist/sheets/add_calendar_link_sheet.dart';
import 'package:mitlist/utils/external_calendar_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_external_calendar.dart';

final _home = Group(
  id: 'g1',
  name: 'Home',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
final _flat = Group(
  id: 'g2',
  name: 'Flat',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

CalendarConnection _work(
        {List<CalendarShare> shares = const [], String? error}) =>
    CalendarConnection(
      id: 'ics-1',
      kind: CalendarConnectionKind.ics,
      name: 'Work',
      lastError: error,
      calendars: [
        ExternalCalendar(
            id: 'k1', externalId: 'x', name: 'Work calendar', shares: shares),
      ],
    );

/// Text in any case: buttons and dialog titles render upper case.
Finder _text(String s) => find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').toLowerCase() == s.toLowerCase());

void main() {
  late FakeExternalCalendarService api;
  late FakeDeviceCalendarSource phone;
  var platform = TargetPlatform.android;

  setUp(() {
    platform = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    api = FakeExternalCalendarService();
    phone = FakeDeviceCalendarSource();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        externalCalendarServiceProvider.overrideWith((ref) async => api),
        deviceCalendarSourceProvider.overrideWithValue(phone),
        deviceCalendarPlatformProvider.overrideWithValue(platform),
        deviceInstallIdProvider.overrideWith((ref) async => 'install'),
        currentUserIdProvider.overrideWith((ref) async => 'me'),
        cachedGroupsProvider.overrideWith((ref) async => [_home, _flat]),
        deviceCalendarSyncProvider.overrideWith((ref) => DeviceCalendarSync(
              api: () async => api,
              source: phone,
              isSignedIn: () => true,
              currentUserId: () async => 'me',
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SharedCalendarsScreen(),
      ),
    ));
    await settle(tester);
  }

  test('sharesWith changes one household and keeps the others', () {
    final cal =
        ExternalCalendar(id: 'k', externalId: 'x', name: 'n', shares: const [
      CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
      CalendarShare(groupId: 'g2', visibility: ShareVisibility.details),
    ]);
    expect(sharesWith(cal, 'g1', ShareChoice.none), const [
      CalendarShare(groupId: 'g2', visibility: ShareVisibility.details)
    ]);
    expect(sharesWith(cal, 'g2', ShareChoice.busy), const [
      CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
      CalendarShare(groupId: 'g2', visibility: ShareVisibility.busy),
    ]);
    expect(shareChoiceOf(cal, 'g3'), ShareChoice.none);
  });

  test('link checks and add errors are friendly', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(isPlausibleCalendarLink('webcal://p01.icloud.com/x'), isTrue);
    expect(
        isPlausibleCalendarLink('https://calendar.google.com/a.ics'), isTrue);
    expect(isPlausibleCalendarLink('http://example.com/a.ics'), isFalse);
    expect(isPlausibleCalendarLink('not a link'), isFalse);
    expect(
        addLinkErrorMessage(
            const ApiException('x', code: 'not_calendar'), l10n),
        l10n.calendarLinkErrorNotCalendar);
    expect(
        addLinkErrorMessage(
            const ApiException('x', code: 'fetch_failed'), l10n),
        l10n.calendarLinkErrorFetch);
    expect(
        addLinkErrorMessage(const ApiException('x', code: 'too_large'), l10n),
        l10n.calendarConnectionErrorTooLarge);
    // A link reset or removed at the provider.
    expect(
        addLinkErrorMessage(
            const ApiException('x', code: 'unauthorized'), l10n),
        l10n.calendarConnectionErrorUnauthorized);
    expect(addLinkErrorMessage(StateError('raw internal detail'), l10n),
        isNot(contains('raw internal detail')));
  });

  testWidgets('a new calendar is not shared; choosing Busy only saves it',
      (tester) async {
    api.connections = [_work(error: 'fetch_failed')];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(find.text('Work calendar'), findsOneWidget);
    expect(find.text(l10n.calendarConnectionErrorFetchFailed), findsOneWidget);
    expect(find.text(l10n.sharedCalendarsNotSharedAnywhere), findsOneWidget);
    // Busy only is the first choice offered.
    final chips = tester
        .widgetList<Semantics>(find.descendant(
            of: find.byKey(const ValueKey('calendar-shares-k1')),
            matching: find.byType(Semantics)))
        .map((s) => s.properties.label)
        .whereType<String>()
        .where((l) => l.startsWith('Home: '))
        .toList();
    expect(chips.first, 'Home: Busy only');

    await tester.tap(find.byKey(const ValueKey('share-k1-g1-busy')));
    await settle(tester);
    expect(api.shareCalls.single.$1, 'k1');
    expect(api.shareCalls.single.$2, const [
      CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
    ]);
    // One sentence, for the household that sees something.
    expect(find.text(l10n.sharedCalendarsExplainBusy('Home')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share-k1-g2-details')));
    await settle(tester);
    expect(api.shareCalls.last.$2, const [
      CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
      CalendarShare(groupId: 'g2', visibility: ShareVisibility.details),
    ]);
    expect(
        find.text('${l10n.sharedCalendarsExplainBusy('Home')} '
            '${l10n.sharedCalendarsExplainDetails('Flat')}'),
        findsOneWidget);
  });

  testWidgets('upcoming events say what each household sees; overrides save',
      (tester) async {
    api.connections = [
      _work(shares: const [
        CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
        CalendarShare(groupId: 'g2', visibility: ShareVisibility.details),
      ]),
    ];
    final soon = DateTime.now().toUtc().add(const Duration(days: 1));
    api.mine = [
      MyExternalEvent(
        calendarId: 'k1',
        externalUid: 'u1',
        startsAt: soon,
        endsAt: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Dentist',
      ),
      MyExternalEvent(
        calendarId: 'k1',
        externalUid: 'u2',
        startsAt: soon.add(const Duration(hours: 3)),
        endsAt: soon.add(const Duration(hours: 4)),
        allDay: false,
        title: 'Therapy',
        sourcePrivate: true,
      ),
    ];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(find.text('Dentist'), findsOneWidget);
    final dentistSees = '${l10n.sharedCalendarsSeesDetails('Flat')}\n'
        '${l10n.sharedCalendarsSeesBusy('Home')}';
    expect(find.text(dentistSees), findsOneWidget);
    // Private in its calendar: busy everywhere, even where titles are shared.
    expect(
        find.text(l10n.sharedCalendarsSeesBusy('Home, Flat')), findsOneWidget);

    await tester.tap(find.text('Dentist'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('override-hidden')));
    await settle(tester);
    expect(api.overrideCalls.single, ('k1', 'u1', EventOverride.hidden));
    expect(find.text(l10n.sharedCalendarsSeesNothing), findsOneWidget);

    await tester.tap(find.text('Therapy'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('override-details')));
    await settle(tester);
    expect(api.overrideCalls.last, ('k1', 'u2', EventOverride.details));
    expect(find.text(dentistSees), findsNothing);
    // "With title" shows the title wherever the calendar is shared at all.
    final therapySees = l10n.sharedCalendarsSeesDetails('Home, Flat');
    expect(find.text(therapySees), findsOneWidget);

    // Back to the calendar's setting sends null.
    await tester.tap(find.text('Therapy'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('override-calendar')));
    await settle(tester);
    expect(api.overrideCalls.last, ('k1', 'u2', null));
  });

  testWidgets('adding a link: bad link, not a calendar, then success',
      (tester) async {
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.sharedCalendarsEmpty), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-calendar-link')));
    await settle(tester);
    expect(find.text(l10n.calendarLinkStepsGoogleTitle), findsOneWidget);
    expect(find.text(l10n.calendarLinkStepsAppleTitle), findsOneWidget);
    expect(find.text(l10n.calendarLinkStepsOutlookTitle), findsOneWidget);

    Finder field(String key) => find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));
    await tester.enterText(field('calendar-link-name'), 'Work');
    await tester.enterText(field('calendar-link-url'), 'calendar.example');
    await tester.tap(_text(l10n.commonAdd));
    await settle(tester);
    expect(find.text(l10n.calendarLinkErrorUrl), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('addIcs')), isEmpty);

    api.failures['addIcs'] = const ApiException('raw', code: 'not_calendar');
    await tester.enterText(field('calendar-link-url'), 'https://x.test/page');
    await tester.tap(_text(l10n.commonAdd));
    await settle(tester);
    expect(find.text(l10n.calendarLinkErrorNotCalendar), findsOneWidget);
    expect(find.text('raw'), findsNothing);

    await tester.enterText(field('calendar-link-url'), 'webcal://x.test/a.ics');
    await tester.tap(_text(l10n.commonAdd));
    await settle(tester);
    expect(api.calls.last, 'addIcs Work webcal://x.test/a.ics');
    expect(find.byKey(const ValueKey('calendar-connection-ics-1')),
        findsOneWidget);
    // Not shared until chosen.
    expect(find.text(l10n.sharedCalendarsNotSharedAnywhere), findsOneWidget);
    expect(api.shareCalls, isEmpty);
  });

  testWidgets('removing asks first, then deletes', (tester) async {
    api.connections = [_work()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.tap(find.byTooltip(l10n.commonRemove));
    await settle(tester);
    expect(_text(l10n.sharedCalendarsRemoveTitle('Work')), findsOneWidget);
    await tester.tap(_text(l10n.commonCancel));
    await settle(tester);
    expect(api.calls.where((c) => c.startsWith('delete')), isEmpty);

    await tester.tap(find.byTooltip(l10n.commonRemove));
    await settle(tester);
    await tester.tap(_text(l10n.commonRemove).last);
    await settle(tester);
    expect(api.calls, contains('delete ics-1'));
    expect(
        find.byKey(const ValueKey('calendar-connection-ics-1')), findsNothing);
  });

  testWidgets('renaming saves the new name', (tester) async {
    api.connections = [_work()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byTooltip(l10n.commonRename));
    await settle(tester);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('calendar-rename-input')),
            matching: find.byType(EditableText)),
        'Job');
    await tester.tap(_text(l10n.commonSave));
    await settle(tester);
    expect(api.calls, contains('rename ics-1 Job'));
    expect(find.text('Job'), findsOneWidget);
  });

  testWidgets('phone calendars: a denial explains the way to Settings',
      (tester) async {
    phone.status = DeviceCalendarPermission.notDetermined;
    phone.afterRequest = DeviceCalendarPermission.denied;
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('add-phone-calendars')));
    await settle(tester);
    expect(phone.requests, 1);
    expect(_text(l10n.sharedCalendarsPermissionDeniedTitle), findsOneWidget);
    await tester.tap(_text(l10n.sharedCalendarsOpenSettings));
    await settle(tester);
    expect(phone.settingsOpened, 1);
    expect(api.calls.where((c) => c.startsWith('addDevice')), isEmpty);
  });

  testWidgets('phone calendars: added unshared, then shared and filtered',
      (tester) async {
    final soon = DateTime.now().add(const Duration(days: 1));
    phone.calendarList = const [DeviceCalendarInfo(id: 'c1', name: 'Personal')];
    phone.eventList = [
      DeviceCalendarEvent(
        calendarId: 'c1',
        uid: 'e1',
        start: soon,
        end: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Physio',
      ),
    ];
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('add-phone-calendars')));
    await settle(tester);
    expect(api.calls, contains('addDevice install'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeviceCalendarSync.connectionKey('me')), 'dev-1');
    // First upload lists the calendar, sends no events: nothing is shared.
    expect(api.deviceSyncBodies.first['calendars'], hasLength(1));
    expect(api.deviceSyncBodies.first['events'], isEmpty);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-phone-calendars')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('share-srv-c1-g1-busy')));
    await settle(tester);
    final body = api.deviceSyncBodies.last;
    expect(body['events'], hasLength(1));
    expect((body['events'] as List).single.containsKey('title'), isFalse);
    // Upcoming reads the phone itself.
    expect(find.text('Physio'), findsOneWidget);

    await tester.tap(find.text('Physio'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('override-hidden')));
    await settle(tester);
    expect(api.overrideCalls.last, ('srv-c1', 'e1', EventOverride.hidden));
    // The phone stops uploading it.
    expect(api.deviceSyncBodies.last['events'], isEmpty);
  });

  testWidgets('a sync within a minute of the last fetch is not an error',
      (tester) async {
    api.connections = [_work()];
    api.failures['syncIcs'] = const ApiException('x', code: 'rate_limited');
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byTooltip(l10n.sharedCalendarsSyncNow));
    await settle(tester);
    expect(find.text(l10n.sharedCalendarsSyncTooSoon), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('at 10 connections adding explains the limit', (tester) async {
    api.connections = [
      for (var i = 0; i < 10; i++)
        CalendarConnection(
            id: 'c$i', kind: CalendarConnectionKind.ics, name: 'Cal $i'),
    ];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byKey(const ValueKey('add-calendar-link')));
    await settle(tester);
    expect(find.text(l10n.sharedCalendarsLimitReached), findsOneWidget);
    expect(find.text(l10n.calendarLinkSheetTitle), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('phone events in Upcoming use the server\'s choices too',
      (tester) async {
    final soon = DateTime.now().add(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({});
    phone.eventList = [
      DeviceCalendarEvent(
        calendarId: 'c1',
        uid: 'e1',
        start: soon,
        end: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Physio',
      ),
    ];
    api.connections = [
      const CalendarConnection(
        id: 'dev-1',
        kind: CalendarConnectionKind.device,
        name: 'Phone',
        deviceId: 'install',
        calendars: [
          ExternalCalendar(
            id: 'srv-c1',
            externalId: 'c1',
            name: 'Personal',
            shares: [
              CalendarShare(groupId: 'g1', visibility: ShareVisibility.details),
            ],
          ),
        ],
      ),
    ];
    // Hidden on the server, nothing on this (reinstalled) phone.
    api.serverOverrides['srv-c1|e1'] = EventOverride.hidden;
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text('Physio'), findsOneWidget);
    expect(find.text(l10n.sharedCalendarsSeesNothing), findsOneWidget);
    expect(
        find.text(l10n
            .sharedCalendarsEventChoice(l10n.sharedCalendarsOverrideHidden)),
        findsOneWidget);
  });

  testWidgets('phone events are not shown when the choices cannot be read',
      (tester) async {
    final soon = DateTime.now().add(const Duration(days: 1));
    phone.eventList = [
      DeviceCalendarEvent(
        calendarId: 'c1',
        uid: 'e1',
        start: soon,
        end: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Physio',
      ),
    ];
    api.connections = [
      const CalendarConnection(
        id: 'dev-1',
        kind: CalendarConnectionKind.device,
        name: 'Phone',
        deviceId: 'install',
        calendars: [
          ExternalCalendar(
            id: 'srv-c1',
            externalId: 'c1',
            name: 'Personal',
            shares: [
              CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
            ],
          ),
        ],
      ),
    ];
    api.failures['listOverrides'] = StateError('offline');
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text('Physio'), findsNothing);
    expect(find.text(l10n.sharedCalendarsUpcomingFailed), findsOneWidget);
  });

  CalendarConnection phoneConnection() => const CalendarConnection(
        id: 'dev-1',
        kind: CalendarConnectionKind.device,
        name: 'Phone',
        deviceId: 'install',
        calendars: [
          ExternalCalendar(
            id: 'srv-c1',
            externalId: 'c1',
            name: 'Personal',
            shares: [
              CalendarShare(groupId: 'g1', visibility: ShareVisibility.details),
            ],
          ),
        ],
      );

  testWidgets(
      'iPhone: says private events are not recognised, on the phone '
      'connection and above Upcoming', (tester) async {
    platform = TargetPlatform.iOS;
    final soon = DateTime.now().add(const Duration(days: 1));
    phone.eventList = [
      DeviceCalendarEvent(
        calendarId: 'c1',
        uid: 'e1',
        start: soon,
        end: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Therapy',
      ),
    ];
    api.connections = [phoneConnection()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.byKey(const ValueKey('connection-ios-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('upcoming-ios-note')), findsOneWidget);
    expect(find.text(l10n.sharedCalendarsIosPrivateNote), findsNWidgets(2));
  });

  testWidgets('Android: no iPhone note', (tester) async {
    api.connections = [phoneConnection()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.sharedCalendarsIosPrivateNote), findsNothing);
  });

  testWidgets('one tap hides an event from the Upcoming list, one shows it',
      (tester) async {
    api.connections = [
      _work(shares: const [
        CalendarShare(groupId: 'g1', visibility: ShareVisibility.details),
      ]),
    ];
    final soon = DateTime.now().toUtc().add(const Duration(days: 1));
    api.mine = [
      MyExternalEvent(
        calendarId: 'k1',
        externalUid: 'u1',
        startsAt: soon,
        endsAt: soon.add(const Duration(hours: 1)),
        allDay: false,
        title: 'Therapy',
        sourcePrivate: true,
      ),
    ];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    // The private note is shown in full.
    expect(find.text(l10n.sharedCalendarsEventPrivateNote), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.sharedCalendarsHideEvent));
    await settle(tester);
    expect(api.overrideCalls.single, ('k1', 'u1', EventOverride.hidden));
    expect(find.text(l10n.sharedCalendarsSeesNothing), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.sharedCalendarsShowAgain));
    await settle(tester);
    expect(api.overrideCalls.last, ('k1', 'u1', null));
  });

  testWidgets('Show me how replays the page\'s steps', (tester) async {
    api.connections = [_work()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester
        .tap(find.byKey(const ValueKey('shared-calendars-show-me-how')));
    await settle(tester);
    expect(find.text(l10n.calendarTourAdd), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await settle(tester);
    // A calendar exists: the choices step follows.
    expect(find.text(l10n.calendarTourChoices), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await settle(tester);
    expect(find.text(l10n.calendarTourChoices), findsNothing);
  });

  test('sync times read like the rest of the app', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 11, 24, 12);
    String at(Duration ago) =>
        syncedLabel(now.subtract(ago), l10n, 'en', now: now);
    expect(at(const Duration(seconds: 20)), 'Synced just now');
    expect(at(const Duration(minutes: 5)), 'Synced 5\u00A0min ago');
    expect(at(const Duration(hours: 3)), 'Synced 3\u00A0h ago');
    expect(at(const Duration(hours: 30)), 'Synced yesterday');
    expect(at(const Duration(days: 4)), 'Synced Nov 20');
  });

  CalendarConnection threeCalendars() => const CalendarConnection(
        id: 'dev-1',
        kind: CalendarConnectionKind.device,
        name: 'Phone',
        deviceId: 'install',
        calendars: [
          ExternalCalendar(
            id: 'k-personal',
            externalId: 'p',
            name: 'Personal',
            shares: [
              CalendarShare(groupId: 'g1', visibility: ShareVisibility.details),
            ],
          ),
          ExternalCalendar(
            id: 'k-work',
            externalId: 'w',
            name: 'Work',
            shares: [
              CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
              CalendarShare(groupId: 'g2', visibility: ShareVisibility.busy),
            ],
          ),
          ExternalCalendar(id: 'k-family', externalId: 'f', name: 'Family'),
        ],
      );

  testWidgets('several calendars: one summary row each, opened on tap',
      (tester) async {
    api.connections = [threeCalendars()];
    await pump(tester);
    expect(find.text('Home: with titles · Flat: not shared'), findsOneWidget);
    expect(find.text('Home: busy only · Flat: busy only'), findsOneWidget);
    expect(find.text('Not shared'), findsWidgets);
    // Collapsed: no controls yet, for any of them.
    expect(find.byKey(const ValueKey('share-k-work-g1-busy')), findsNothing);
    expect(
        find.byKey(const ValueKey('share-k-personal-g1-busy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('calendar-toggle-k-work')));
    await settle(tester);
    expect(find.byKey(const ValueKey('share-k-work-g1-busy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-toggle-k-work')));
    await settle(tester);
    expect(find.byKey(const ValueKey('share-k-work-g1-busy')), findsNothing);
  });

  testWidgets('a single calendar starts open', (tester) async {
    api.connections = [_work()];
    await pump(tester);
    expect(find.byKey(const ValueKey('share-k1-g1-busy')), findsOneWidget);
  });

  testWidgets('the replay opens the calendar it points at', (tester) async {
    api.connections = [threeCalendars()];
    await pump(tester);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester
        .tap(find.byKey(const ValueKey('shared-calendars-show-me-how')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await settle(tester);
    expect(find.text(l10n.calendarTourChoices), findsOneWidget);
    expect(
        find.byKey(const ValueKey('share-k-personal-g1-busy')), findsOneWidget);
  });
}
