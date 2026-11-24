import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/providers/calendar_provider.dart';
import 'package:mitlist/services/api_client.dart' show dioProvider;
import 'package:mitlist/services/calendar_service.dart';
import 'package:mitlist/services/external_calendar_service.dart';

Map<String, dynamic> ext({
  String title = 'Dinner at Sam\'s',
  bool? busyOnly,
  bool allDay = false,
  String starts = '2026-12-01T18:00:00Z',
  String ends = '2026-12-01T20:00:00Z',
  bool free = false,
}) =>
    {
      'id': 'ext:1',
      'type': 'external_event',
      'title': title,
      'date': starts,
      'group_id': 'g1',
      'external': {
        'user_id': 'u2',
        'starts_at': starts,
        'ends_at': ends,
        'all_day': allDay,
        if (busyOnly != null) 'busy_only': busyOnly,
        'free': free,
      },
    };

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object Function(RequestOptions)? respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = respond?.call(options) ?? {};
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('external_event in the household calendar', () {
    test('parses the new type and its block', () {
      final e = CalendarEvent.fromJson(ext(busyOnly: false));
      expect(e.type, CalendarEventType.externalEvent);
      expect(e.title, 'Dinner at Sam\'s');
      expect(e.external!.userId, 'u2');
      expect(e.external!.busyOnly, isFalse);
      expect(e.external!.allDay, isFalse);
    });

    test('a busy-only block never carries a title, whatever the payload says',
        () {
      expect(CalendarEvent.fromJson(ext(busyOnly: true)).title, isEmpty);
    });

    test('a block without busy_only is treated as busy', () {
      final e = CalendarEvent.fromJson(ext());
      expect(e.external!.busyOnly, isTrue);
      expect(e.title, isEmpty);
    });

    test('unknown types still fall back as before', () {
      final e = CalendarEvent.fromJson({
        'id': 'x',
        'type': 'something_new',
        'title': 't',
        'date': '2026-12-01T00:00:00Z',
        'group_id': 'g1',
      });
      expect(e.type, CalendarEventType.mealPlan);
    });

    test('parseCalendarEvents drops an external event without its block', () {
      final raw = [
        ext(busyOnly: false),
        {
          'id': 'ext:2',
          'type': 'external_event',
          'title': 'Secret',
          'date': '2026-12-01T00:00:00Z',
          'group_id': 'g1',
        },
      ];
      final parsed = CalendarService.parseCalendarEvents(raw);
      expect(parsed.map((e) => e.id), ['ext:1']);
    });

    test('an all-day event covers its local dates, end exclusive', () {
      final x = CalendarEvent.fromJson(ext(
        allDay: true,
        starts: '2026-12-04T00:00:00Z',
        ends: '2026-12-07T00:00:00Z',
      )).external!;
      expect(x.days, [
        DateTime(2026, 12, 4),
        DateTime(2026, 12, 5),
        DateTime(2026, 12, 6),
      ]);
    });

    test('a one-day all-day event covers that day', () {
      final x = CalendarEvent.fromJson(ext(
        allDay: true,
        starts: '2026-12-04T00:00:00Z',
        ends: '2026-12-04T00:00:00Z',
      )).external!;
      expect(x.days, [DateTime(2026, 12, 4)]);
    });

    test('a timed event spanning midnight covers both local days', () {
      final start = DateTime(2026, 12, 1, 22);
      final end = DateTime(2026, 12, 2, 2);
      final x = CalendarEvent.fromJson(ext(
        starts: start.toUtc().toIso8601String(),
        ends: end.toUtc().toIso8601String(),
      )).external!;
      expect(x.days, [DateTime(2026, 12, 1), DateTime(2026, 12, 2)]);
    });

    test('a timed event ending exactly at midnight does not cover the next day',
        () {
      final start = DateTime(2026, 12, 1, 20);
      final end = DateTime(2026, 12, 2);
      final x = CalendarEvent.fromJson(ext(
        starts: start.toUtc().toIso8601String(),
        ends: end.toUtc().toIso8601String(),
      )).external!;
      expect(x.days, [DateTime(2026, 12, 1)]);
    });
  });

  group('connection models', () {
    test('parse connections, calendars, shares and errors', () {
      final c = CalendarConnection.fromJson({
        'id': 'c1',
        'kind': 'device',
        'name': 'Pixel',
        'device_id': 'dev',
        'last_synced_at': '2026-12-01T10:00:00Z',
        'last_error': 'not_calendar',
        'calendars': [
          {
            'id': 'k1',
            'external_id': '7',
            'name': 'Work',
            'color': '#00FF00',
            'shares': [
              {'group_id': 'g1', 'visibility': 'busy'},
              {'group_id': 'g2', 'visibility': 'details'},
              // A visibility this build does not know is dropped, never
              // read as "with titles".
              {'group_id': 'g3', 'visibility': 'everything'},
            ],
          },
        ],
      });
      expect(c.isDevice, isTrue);
      expect(c.deviceId, 'dev');
      expect(c.error, ConnectionError.notCalendar);
      expect(c.lastSyncedAt, DateTime.utc(2026, 12, 1, 10));
      final cal = c.calendars.single;
      expect(cal.shareFor('g1'), ShareVisibility.busy);
      expect(cal.shareFor('g2'), ShareVisibility.details);
      expect(cal.shareFor('g3'), isNull);
      expect(cal.shares, hasLength(2));
    });

    test('maps every last_error code', () {
      ConnectionError? err(String? code) => CalendarConnection.fromJson(
          {'id': 'c', 'kind': 'ics', 'name': 'x', 'last_error': code}).error;
      expect(err(null), isNull);
      expect(err('fetch_failed'), ConnectionError.fetchFailed);
      expect(err('not_calendar'), ConnectionError.notCalendar);
      expect(err('too_large'), ConnectionError.tooLarge);
      expect(err('unauthorized'), ConnectionError.unauthorized);
      expect(err('new_code'), ConnectionError.other);
    });

    test('parses the owner\'s events with overrides', () {
      final e = MyExternalEvent.fromJson({
        'calendar_id': 'k1',
        'external_uid': 'abc',
        'starts_at': '2026-12-01T18:00:00Z',
        'ends_at': '2026-12-01T19:00:00Z',
        'all_day': false,
        'title': 'Yoga',
        'source_private': true,
        'free': false,
        'override': 'hidden',
      });
      expect(e.override, EventOverride.hidden);
      expect(e.sourcePrivate, isTrue);
      expect(e.title, 'Yoga');
    });
  });

  group('services', () {
    test('the household calendar asks for external events', () async {
      final adapter = _Adapter()
        ..respond = (_) => {
              'events': [ext(busyOnly: true)],
            };
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      final service = await container.read(calendarServiceProviderAsync.future);
      final events = await service.getCalendar(
          'g1', DateTime(2026, 12, 1), DateTime(2026, 12, 7));
      expect(adapter.requests.single.path, '/calendar');
      expect(adapter.requests.single.queryParameters['include'], 'external');
      expect(events.single.type, CalendarEventType.externalEvent);
      expect(events.single.title, isEmpty);
    });

    test('ExternalCalendarService uses the contract\'s endpoints', () async {
      final adapter = _Adapter()
        ..respond = (o) {
          if (o.path.endsWith('/connections') && o.method == 'GET') {
            return {
              'connections': [
                {'id': 'c1', 'kind': 'ics', 'name': 'Work', 'calendars': []},
              ],
            };
          }
          if (o.path.contains('/shares')) {
            return {
              'id': 'k1',
              'external_id': 'x',
              'name': 'Work',
              'shares': []
            };
          }
          if (o.path.endsWith('/events/mine')) return {'events': []};
          return {'id': 'c1', 'kind': 'ics', 'name': 'Work', 'calendars': []};
        };
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final s = ExternalCalendarService(dio);

      expect((await s.listConnections()).single.name, 'Work');
      await s.addIcsConnection(name: 'Work', url: 'webcal://x.test/a.ics');
      await s.addDeviceConnection(name: 'Phone', deviceId: 'dev');
      await s.renameConnection('c1', 'Job');
      await s.deleteConnection('c1');
      await s.syncIcs('c1');
      await s.deviceSync('c1', {'calendars': [], 'events': []});
      await s.setShares('k1', const [
        CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
      ]);
      await s.myEvents(DateTime.utc(2026, 12, 1), DateTime.utc(2026, 12, 15));
      await s.setOverride(calendarId: 'k1', externalUid: 'u', visibility: null);

      final seen = [
        for (final r in adapter.requests) '${r.method} ${r.path}',
      ];
      expect(seen, [
        'GET /calendar/external/connections',
        'POST /calendar/external/connections',
        'POST /calendar/external/connections',
        'PATCH /calendar/external/connections/c1',
        'DELETE /calendar/external/connections/c1',
        'POST /calendar/external/connections/c1/sync',
        'PUT /calendar/external/connections/c1/device-sync',
        'PUT /calendar/external/calendars/k1/shares',
        'GET /calendar/external/events/mine',
        'PUT /calendar/external/overrides',
      ]);
      expect(adapter.requests[1].data,
          {'kind': 'ics', 'name': 'Work', 'url': 'webcal://x.test/a.ics'});
      expect(adapter.requests[2].data,
          {'kind': 'device', 'name': 'Phone', 'device_id': 'dev'});
      expect(adapter.requests[7].data, {
        'shares': [
          {'group_id': 'g1', 'visibility': 'busy'},
        ],
      });
      expect(adapter.requests[8].queryParameters['from'],
          '2026-12-01T00:00:00.000Z');
      // null clears the override and is sent as JSON null.
      expect(adapter.requests[9].data, {
        'calendar_id': 'k1',
        'external_uid': 'u',
        'visibility': null,
      });
    });
  });

  test('listOverrides reads the caller\'s overrides and fails closed',
      () async {
    final adapter = _Adapter()
      ..respond = (_) => {
            'overrides': [
              {
                'calendar_id': 'k1',
                'external_uid': 'u1',
                'visibility': 'hidden'
              },
              {'calendar_id': 'k1', 'external_uid': 'u2', 'visibility': 'odd'},
            ],
          };
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = adapter;
    final s = ExternalCalendarService(dio);
    final list = await s.listOverrides();
    expect(adapter.requests.single.path, '/calendar/external/overrides');
    expect(list.single.externalUid, 'u1');
    expect(list.single.visibility, EventOverride.hidden);

    adapter.respond = (_) => {'something': 'else'};
    expect(s.listOverrides(), throwsA(isA<FormatException>()));
  });
}
