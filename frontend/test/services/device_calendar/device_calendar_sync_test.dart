import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/services/device_calendar/device_calendar_source.dart';
import 'package:mitlist/services/device_calendar/device_calendar_sync.dart';
import 'package:mitlist/utils/external_calendar_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_external_calendar.dart';

void main() {
  late FakeExternalCalendarService api;
  late FakeDeviceCalendarSource source;
  late bool signedIn;
  late DateTime now;

  CalendarConnection phone({List<ExternalCalendar> calendars = const []}) =>
      CalendarConnection(
        id: 'dev-1',
        kind: CalendarConnectionKind.device,
        name: 'Phone',
        deviceId: 'install',
        calendars: calendars,
      );

  DeviceCalendarSync build() => DeviceCalendarSync(
        api: () async => api,
        source: source,
        isSignedIn: () => signedIn,
        currentUserId: () async => 'me',
        now: () => now,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      DeviceCalendarSync.connectionKey('me'): 'dev-1',
    });
    signedIn = true;
    now = DateTime(2026, 12, 1, 12);
    api = FakeExternalCalendarService(connections: [
      phone(calendars: const [
        ExternalCalendar(
          id: 'k1',
          externalId: 'c1',
          name: 'Personal',
          shares: [
            CalendarShare(groupId: 'g1', visibility: ShareVisibility.details),
          ],
        ),
      ]),
    ]);
    source = FakeDeviceCalendarSource(
      calendars: const [DeviceCalendarInfo(id: 'c1', name: 'Personal')],
      events: [
        DeviceCalendarEvent(
          calendarId: 'c1',
          uid: 'e1',
          start: DateTime(2026, 12, 2, 9),
          end: DateTime(2026, 12, 2, 10),
          allDay: false,
          title: 'Dentist',
        ),
        DeviceCalendarEvent(
          calendarId: 'c1',
          uid: 'e2',
          start: DateTime(2026, 12, 3, 9),
          end: DateTime(2026, 12, 3, 10),
          allDay: false,
          title: 'Therapy',
        ),
      ],
    );
  });

  test('uploads the filtered calendar on start', () async {
    final outcome = await build().syncIfDue();
    expect(outcome, DeviceSyncOutcome.synced);
    final body = api.deviceSyncBodies.single;
    expect((body['events'] as List).map((e) => e['title']),
        ['Dentist', 'Therapy']);
  });

  test('start/resume syncs at most every 15 minutes; settings changes always',
      () async {
    final sync = build();
    expect(await sync.syncIfDue(), DeviceSyncOutcome.synced);
    now = now.add(const Duration(minutes: 14));
    expect(await sync.syncIfDue(), DeviceSyncOutcome.throttled);
    expect(await build().syncIfDue(), DeviceSyncOutcome.throttled,
        reason: 'the throttle survives a cold start');
    expect(await sync.syncNow(), DeviceSyncOutcome.synced);
    now = now.add(const Duration(minutes: 16));
    expect(await sync.syncIfDue(), DeviceSyncOutcome.synced);
    expect(api.deviceSyncBodies, hasLength(3));
  });

  test('does nothing without a device connection for this install', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await build().syncIfDue(), DeviceSyncOutcome.skipped);
    expect(api.calls, isEmpty);
    expect(source.reads, 0);
  });

  test('does nothing while signed out', () async {
    signedIn = false;
    expect(await build().syncNow(), DeviceSyncOutcome.skipped);
    expect(api.calls, isEmpty);
  });

  test('never prompts and skips without calendar permission', () async {
    source.status = DeviceCalendarPermission.denied;
    expect(await build().syncNow(), DeviceSyncOutcome.noPermission);
    expect(source.requests, 0);
    expect(api.deviceSyncBodies, isEmpty);
  });

  test('does nothing where device calendars are unsupported (web)', () async {
    source.supported = false;
    expect(await build().syncNow(), DeviceSyncOutcome.skipped);
    expect(api.calls, isEmpty);
  });

  test('signing out mid-read sends nothing', () async {
    source.duringRead = () => signedIn = false;
    expect(await build().syncNow(), DeviceSyncOutcome.stopped);
    expect(api.deviceSyncBodies, isEmpty);
  });

  test('stop() (sign-out) mid-read sends nothing, and nothing after', () async {
    final sync = build();
    source.duringRead = sync.stop;
    expect(await sync.syncNow(), DeviceSyncOutcome.stopped);
    source.duringRead = null;
    expect(await sync.syncNow(), DeviceSyncOutcome.stopped);
    expect(api.deviceSyncBodies, isEmpty);
  });

  test('a connection removed elsewhere stops syncing this install', () async {
    api.connections.clear();
    final sync = build();
    expect(await sync.syncNow(), DeviceSyncOutcome.skipped);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeviceCalendarSync.connectionKey('me')), isNull);
  });

  test('hidden events stay on the phone; busy overrides lose their title',
      () async {
    const store = DeviceOverrideStore();
    await store.set('me',
        calendarId: 'k1', uid: 'e2', visibility: EventOverride.hidden);
    await store.set('me',
        calendarId: 'k1', uid: 'e1', visibility: EventOverride.busy);
    await build().syncNow();
    final events = api.deviceSyncBodies.single['events'] as List;
    expect(events.map((e) => e['external_uid']), ['e1']);
    expect((events.single as Map).containsKey('title'), isFalse);

    // Back to the calendar's setting.
    await store.set('me', calendarId: 'k1', uid: 'e2', visibility: null);
    await build().syncNow();
    expect((api.deviceSyncBodies.last['events'] as List), hasLength(2));
  });

  test('overrides belong to one account', () async {
    await const DeviceOverrideStore().set('someone-else',
        calendarId: 'k1', uid: 'e1', visibility: EventOverride.hidden);
    await build().syncNow();
    expect((api.deviceSyncBodies.single['events'] as List), hasLength(2));
  });

  test('a settings change during a sync gets its own run afterwards', () async {
    final sync = build();
    // b and c arrive while a is in flight (it is set synchronously).
    final a = sync.syncNow();
    final b = sync.syncNow();
    final c = sync.syncNow();
    expect(await a, DeviceSyncOutcome.synced);
    expect(await b, DeviceSyncOutcome.synced);
    expect(await c, DeviceSyncOutcome.synced);
    // One run, then one coalesced rerun for the two changes.
    expect(api.deviceSyncBodies, hasLength(2));
  });

  test('a failing server is reported, not thrown, and counts as an attempt',
      () async {
    api.failures['deviceSync'] = StateError('boom');
    final sync = build();
    expect(await sync.syncIfDue(), DeviceSyncOutcome.failed);
    expect(await sync.syncIfDue(), DeviceSyncOutcome.throttled);
  });

  group('the server is the source of truth for overrides', () {
    List<String> uploadedUids() => [
          for (final e in api.deviceSyncBodies.last['events'] as List)
            (e as Map)['external_uid'] as String,
        ];

    test('reinstall: nothing stored locally, server says hidden', () async {
      api.serverOverrides['k1|e2'] = EventOverride.hidden;
      expect(await build().syncNow(), DeviceSyncOutcome.synced);
      expect(uploadedUids(), ['e1']);
      // The phone now mirrors it, confirmed.
      final local = await const DeviceOverrideStore().entries('me');
      expect(local[DeviceOverrideStore.entryKey('k1', 'e2')]?.value,
          EventOverride.hidden);
      expect(local[DeviceOverrideStore.entryKey('k1', 'e2')]?.pending, isFalse);
    });

    test('overrides fetch fails: no upload this run, next trigger retries',
        () async {
      api.serverOverrides['k1|e2'] = EventOverride.hidden;
      api.failures['listOverrides'] = StateError('offline');
      final sync = build();
      expect(await sync.syncNow(), DeviceSyncOutcome.failed);
      expect(api.deviceSyncBodies, isEmpty);
      expect(await sync.syncNow(), DeviceSyncOutcome.synced);
      expect(uploadedUids(), ['e1']);
    });

    test('a pending local hidden is sent first, then the upload omits it',
        () async {
      await const DeviceOverrideStore().set('me',
          calendarId: 'k1', uid: 'e2', visibility: EventOverride.hidden);
      expect(await build().syncNow(), DeviceSyncOutcome.synced);
      final putAt = api.calls.indexOf('override k1 e2 hidden');
      final uploadAt = api.calls.indexOf('deviceSync dev-1');
      expect(putAt, greaterThanOrEqualTo(0));
      expect(putAt, lessThan(uploadAt));
      expect(uploadedUids(), ['e1']);
      final local = await const DeviceOverrideStore().entries('me');
      expect(local[DeviceOverrideStore.entryKey('k1', 'e2')]?.pending, isFalse);
    });

    test(
        'a pending choice that cannot be sent blocks the upload and stays '
        'pending', () async {
      await const DeviceOverrideStore().set('me',
          calendarId: 'k1', uid: 'e2', visibility: EventOverride.hidden);
      api.failures['override'] = StateError('offline');
      final sync = build();
      expect(await sync.syncNow(), DeviceSyncOutcome.failed);
      expect(api.deviceSyncBodies, isEmpty);
      final local = await const DeviceOverrideStore().entries('me');
      expect(local[DeviceOverrideStore.entryKey('k1', 'e2')]?.pending, isTrue);
      expect(await sync.syncNow(), DeviceSyncOutcome.synced);
      expect(uploadedUids(), ['e1']);
    });

    test('otherwise the server wins over what the phone remembered', () async {
      // Confirmed here earlier, then cleared on another device.
      await const DeviceOverrideStore().replaceConfirmed('me', {
        DeviceOverrideStore.entryKey('k1', 'e2'): EventOverride.hidden,
      });
      expect(await build().syncNow(), DeviceSyncOutcome.synced);
      expect(uploadedUids(), ['e1', 'e2']);
    });

    test('a pending clear is sent and the server copy dropped', () async {
      api.serverOverrides['k1|e2'] = EventOverride.hidden;
      await const DeviceOverrideStore()
          .set('me', calendarId: 'k1', uid: 'e2', visibility: null);
      expect(await build().syncNow(), DeviceSyncOutcome.synced);
      expect(api.calls, contains('override k1 e2 null'));
      expect(uploadedUids(), ['e1', 'e2']);
    });

    test('choices stored by the first build are re-sent', () async {
      SharedPreferences.setMockInitialValues({
        DeviceCalendarSync.connectionKey('me'): 'dev-1',
        'device_calendar_overrides.me': '{"k1\\ne2":"hidden"}',
      });
      expect(await build().syncNow(), DeviceSyncOutcome.synced);
      expect(api.calls, contains('override k1 e2 hidden'));
      expect(uploadedUids(), ['e1']);
    });
  });
}
