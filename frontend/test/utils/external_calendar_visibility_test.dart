import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/utils/external_calendar_visibility.dart';

/// The contract's visibility rules, written out independently of the code.
HousemateView expected(
    ShareVisibility? share, EventOverride? o, bool private, bool hasTitle) {
  if (share == null) return HousemateView.nothing; // rule 1
  if (o == EventOverride.hidden) return HousemateView.nothing; // rule 2
  HousemateView v;
  if (o == EventOverride.busy) {
    v = HousemateView.busy;
  } else if (o == EventOverride.details) {
    v = HousemateView.details;
  } else if (private) {
    v = HousemateView.busy; // rule 3
  } else {
    v = share == ShareVisibility.busy
        ? HousemateView.busy
        : HousemateView.details;
  }
  if (v == HousemateView.details && !hasTitle) v = HousemateView.busy; // rule 4
  return v;
}

const shareSets = <String, List<CalendarShare>>{
  'none': [],
  'busy': [CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy)],
  'details': [
    CalendarShare(groupId: 'g1', visibility: ShareVisibility.details)
  ],
  'mixed': [
    CalendarShare(groupId: 'g1', visibility: ShareVisibility.busy),
    CalendarShare(groupId: 'g2', visibility: ShareVisibility.details),
  ],
};

void main() {
  group('housemateView', () {
    test('matches the contract for every combination', () {
      var n = 0;
      for (final share in [null, ...ShareVisibility.values]) {
        for (final o in [null, ...EventOverride.values]) {
          for (final private in [false, true]) {
            for (final hasTitle in [false, true]) {
              n++;
              expect(
                housemateView(
                  share: share,
                  override: o,
                  sourcePrivate: private,
                  hasTitle: hasTitle,
                ),
                expected(share, o, private, hasTitle),
                reason: 'share=$share override=$o private=$private '
                    'title=$hasTitle',
              );
            }
          }
        }
      }
      expect(n, 48);
    });

    test('an unshared calendar shows nothing even when overridden "details"',
        () {
      expect(
        housemateView(
          share: null,
          override: EventOverride.details,
          sourcePrivate: false,
          hasTitle: true,
        ),
        HousemateView.nothing,
      );
    });

    test('private events are busy unless the owner reveals them', () {
      expect(
        housemateView(
            share: ShareVisibility.details,
            override: null,
            sourcePrivate: true,
            hasTitle: true),
        HousemateView.busy,
      );
      expect(
        housemateView(
            share: ShareVisibility.details,
            override: EventOverride.details,
            sourcePrivate: true,
            hasTitle: true),
        HousemateView.details,
      );
    });
  });

  group('buildDeviceUpload', () {
    const cal =
        DeviceCalendarInfo(id: 'c1', name: 'Personal', color: '#FF0000');
    DeviceCalendarEvent event({
      String uid = 'u1',
      String title = 'Dentist',
      bool private = false,
      bool cancelled = false,
      bool free = false,
      String calendarId = 'c1',
      DateTime? start,
    }) =>
        DeviceCalendarEvent(
          calendarId: calendarId,
          uid: uid,
          start: start ?? DateTime(2026, 12, 1, 10),
          end: (start ?? DateTime(2026, 12, 1, 10))
              .add(const Duration(hours: 1)),
          allDay: false,
          title: title,
          sourcePrivate: private,
          free: free,
          cancelled: cancelled,
        );

    test('obeys the upload rule for every combination', () {
      var n = 0;
      for (final entry in shareSets.entries) {
        for (final o in [null, ...EventOverride.values]) {
          for (final private in [false, true]) {
            for (final title in ['', 'Dentist']) {
              for (final cancelled in [false, true]) {
                n++;
                final upload = buildDeviceUpload(
                  calendars: const [cal],
                  events: [
                    event(title: title, private: private, cancelled: cancelled)
                  ],
                  shares: {'c1': entry.value},
                  overrides: (c, u) => c == 'c1' && u == 'u1' ? o : null,
                );
                final reason = 'shares=${entry.key} override=$o '
                    'private=$private title="$title" cancelled=$cancelled';
                // Calendar metadata is always listed (the owner needs its id).
                expect(upload.calendars.single['external_id'], 'c1');

                final shouldUpload = entry.value.isNotEmpty &&
                    o != EventOverride.hidden &&
                    !cancelled;
                expect(upload.events.length, shouldUpload ? 1 : 0,
                    reason: reason);
                if (!shouldUpload) continue;

                final anyDetails = entry.value
                    .any((s) => s.visibility == ShareVisibility.details);
                final mayTitle = title.isNotEmpty &&
                    (o == EventOverride.details ||
                        (o == null && !private && anyDetails));
                final sent = upload.events.single;
                expect(sent.containsKey('title'), mayTitle, reason: reason);
                if (mayTitle) expect(sent['title'], 'Dentist');
                expect(sent['source_private'], private);
                // Nothing else from the event leaves the phone.
                expect(
                  sent.keys.toSet().difference({
                    'calendar_external_id',
                    'external_uid',
                    'starts_at',
                    'ends_at',
                    'all_day',
                    'title',
                    'source_private',
                    'free',
                  }),
                  isEmpty,
                );
              }
            }
          }
        }
      }
      expect(n, 4 * 4 * 2 * 2 * 2);
    });

    test('no title ever leaves for a calendar shared busy only', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [for (var i = 0; i < 20; i++) event(uid: 'u$i')],
        shares: {'c1': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(upload.events, hasLength(20));
      expect(upload.events.where((e) => e.containsKey('title')), isEmpty);
    });

    test('events of other calendars only follow their own shares', () {
      const other = DeviceCalendarInfo(id: 'c2', name: 'Therapy');
      final upload = buildDeviceUpload(
        calendars: const [cal, other],
        events: [event(uid: 'a'), event(uid: 'b', calendarId: 'c2')],
        shares: {'c1': shareSets['details']!},
        overrides: (_, __) => null,
      );
      expect(upload.events.map((e) => e['external_uid']), ['a']);
      expect(upload.calendars.map((c) => c['external_id']),
          containsAll(['c1', 'c2']));
    });

    test('an event of a calendar the phone did not list is dropped', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [event(calendarId: 'ghost')],
        shares: {'ghost': shareSets['details']!},
        overrides: (_, __) => null,
      );
      expect(upload.events, isEmpty);
    });

    test('all-day events go up as UTC midnights of their dates, end exclusive',
        () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [
          DeviceCalendarEvent(
            calendarId: 'c1',
            uid: 'trip',
            start: DateTime(2026, 12, 4),
            end: DateTime(2026, 12, 7),
            allDay: true,
            title: 'Lisbon',
          ),
          // A one-day all-day event whose end equals its start.
          DeviceCalendarEvent(
            calendarId: 'c1',
            uid: 'bday',
            start: DateTime(2026, 12, 9),
            end: DateTime(2026, 12, 9),
            allDay: true,
          ),
        ],
        shares: {'c1': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(upload.events[0]['starts_at'], '2026-12-04T00:00:00.000Z');
      expect(upload.events[0]['ends_at'], '2026-12-07T00:00:00.000Z');
      expect(upload.events[0]['all_day'], isTrue);
      expect(upload.events[1]['starts_at'], '2026-12-09T00:00:00.000Z');
      expect(upload.events[1]['ends_at'], '2026-12-10T00:00:00.000Z');
    });

    test('timed events go up as UTC instants', () {
      final start = DateTime(2026, 12, 1, 18, 30);
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [event(start: start)],
        shares: {'c1': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(
          upload.events.single['starts_at'], start.toUtc().toIso8601String());
    });

    test(
        'a recurring series keeps one uid, occurrences differ by start; '
        'duplicates are sent once', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [
          event(uid: 'gym', start: DateTime(2026, 12, 1, 7)),
          event(uid: 'gym', start: DateTime(2026, 12, 8, 7)),
          event(uid: 'gym', start: DateTime(2026, 12, 8, 7)),
        ],
        shares: {'c1': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(upload.events, hasLength(2));
    });

    test('hiding a series hides every occurrence', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [
          event(uid: 'gym', start: DateTime(2026, 12, 1, 7)),
          event(uid: 'gym', start: DateTime(2026, 12, 8, 7)),
          event(uid: 'other'),
        ],
        shares: {'c1': shareSets['details']!},
        overrides: (_, u) => u == 'gym' ? EventOverride.hidden : null,
      );
      expect(upload.events.map((e) => e['external_uid']), ['other']);
    });

    test('titles are cut to 200 characters and blank titles are omitted', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [
          event(uid: 'long', title: 'x' * 250),
          event(uid: 'blank', title: '   '),
        ],
        shares: {'c1': shareSets['details']!},
        overrides: (_, __) => null,
      );
      final byUid = {for (final e in upload.events) e['external_uid']: e};
      expect((byUid['long']!['title'] as String).length, 200);
      expect(byUid['blank']!.containsKey('title'), isFalse);
    });

    test('free events are marked free', () {
      final upload = buildDeviceUpload(
        calendars: const [cal],
        events: [event(free: true)],
        shares: {'c1': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(upload.events.single['free'], isTrue);
    });

    test('keeps to the calendar and event limits, shared calendars first', () {
      final calendars = [
        for (var i = 0; i < 60; i++)
          DeviceCalendarInfo(id: 'c$i', name: 'Calendar $i'),
      ];
      final upload = buildDeviceUpload(
        calendars: calendars,
        events: [
          for (var i = 0; i < 5100; i++)
            event(
                uid: 'e$i',
                calendarId: 'c59',
                start: DateTime(2026, 12, 1).add(Duration(minutes: i))),
        ],
        shares: {'c59': shareSets['busy']!},
        overrides: (_, __) => null,
      );
      expect(upload.calendars, hasLength(kMaxCalendarsPerConnection));
      expect(upload.calendars.first['external_id'], 'c59');
      expect(upload.events, hasLength(kMaxEventsPerConnection));
    });
  });
}
