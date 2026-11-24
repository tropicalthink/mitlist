import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/utils/household_availability.dart';

CalendarEvent block(String user, DateTime start, DateTime end,
    {bool allDay = false, bool free = false}) {
  return CalendarEvent(
    id: 'ext:$user$start',
    type: CalendarEventType.externalEvent,
    title: '',
    date: start,
    groupId: 'g1',
    external: CalendarExternalEvent(
      userId: user,
      startsAt:
          allDay ? DateTime.utc(start.year, start.month, start.day) : start,
      endsAt: allDay ? DateTime.utc(end.year, end.month, end.day) : end,
      allDay: allDay,
      busyOnly: true,
      free: free,
    ),
  );
}

void main() {
  final day = DateTime(2026, 12, 3);

  test('free, busy with merged times, and away all day', () {
    final events = [
      block('a', DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 11)),
      block('a', DateTime(2026, 12, 3, 10), DateTime(2026, 12, 3, 12)),
      block('a', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 19)),
      block('b', DateTime(2026, 12, 2), DateTime(2026, 12, 5), allDay: true),
    ];
    final around = whosAround(day, events, ['a', 'b', 'c']);
    expect(around.map((m) => m.status),
        [AroundStatus.busy, AroundStatus.away, AroundStatus.free]);
    expect(around.first.busy, [
      BusyRange(DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 12)),
      BusyRange(DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 19)),
    ]);
  });

  test('free events never make anyone busy or away', () {
    final events = [
      block('a', DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 11),
          free: true),
      block('a', DateTime(2026, 12, 3), DateTime(2026, 12, 4),
          allDay: true, free: true),
    ];
    expect(whosAround(day, events, ['a']).single.status, AroundStatus.free);
  });

  test('timed events are clipped to the day', () {
    final events = [
      block('a', DateTime(2026, 12, 2, 22), DateTime(2026, 12, 3, 2)),
    ];
    final m = whosAround(day, events, ['a']).single;
    expect(m.status, AroundStatus.busy);
    expect(m.busy.single,
        BusyRange(DateTime(2026, 12, 3), DateTime(2026, 12, 3, 2)));
  });

  test('a timed event covering the whole day means away', () {
    final events = [
      block('a', DateTime(2026, 12, 2, 8), DateTime(2026, 12, 4, 20)),
    ];
    expect(whosAround(day, events, ['a']).single.status, AroundStatus.away);
  });

  test('an all-day event ending the day before does not count', () {
    final events = [
      block('a', DateTime(2026, 12, 1), DateTime(2026, 12, 3), allDay: true),
    ];
    expect(whosAround(day, events, ['a']).single.status, AroundStatus.free);
  });

  test('other event types and other people are ignored; sharers deduped', () {
    final events = [
      CalendarEvent(
        id: 'chore',
        type: CalendarEventType.chore,
        title: 'Bins',
        date: DateTime(2026, 12, 3, 9),
        groupId: 'g1',
      ),
      block('z', DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 10)),
    ];
    final around = whosAround(day, events, ['a', 'a']);
    expect(around, hasLength(1));
    expect(around.single.status, AroundStatus.free);
  });

  group('busy members: when they become free', () {
    test('free from the end of the last busy stretch', () {
      final m = whosAround(day, [
        block('a', DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 17)),
      ], [
        'a'
      ]).single;
      expect(m.freeFrom, DateTime(2026, 12, 3, 17));
      expect(m.busyFrom, isNull);
    });

    test('busy past midnight: busy from, never free from', () {
      final m = whosAround(day, [
        block('a', DateTime(2026, 12, 3, 22), DateTime(2026, 12, 4, 2)),
      ], [
        'a'
      ]).single;
      expect(m.freeFrom, isNull);
      expect(m.busyFrom, DateTime(2026, 12, 3, 22));
    });

    test('today: busy until the end of the stretch they are in now', () {
      final m = whosAround(
        day,
        [
          block('a', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 19)),
          block('a', DateTime(2026, 12, 3, 19), DateTime(2026, 12, 3, 21, 30)),
        ],
        ['a'],
        now: DateTime(2026, 12, 3, 18, 30),
      ).single;
      expect(m.busyUntil, DateTime(2026, 12, 3, 21, 30));
    });

    test('members who share nothing are listed as not sharing, never free', () {
      final around = whosAround(day, const [], ['a'], members: ['a', 'b']);
      expect(around.map((m) => m.status),
          [AroundStatus.free, AroundStatus.notSharing]);
    });
  });

  group('the household evening (18:00 to 23:00)', () {
    HouseholdEvening? evening(List<CalendarEvent> events,
            {List<String> sharers = const ['a', 'b'],
            List<String> members = const [],
            DateTime? now}) =>
        householdEvening(
            day, whosAround(day, events, sharers, members: members, now: now),
            now: now);

    test('everyone free all evening', () {
      final e = evening([
        block('a', DateTime(2026, 12, 3, 9), DateTime(2026, 12, 3, 17)),
      ])!;
      expect(e.kind, EveningKind.freeAllEvening);
      expect(e.onlySharers, isFalse);
    });

    test('everyone free from the latest end of overlapping evening plans', () {
      final e = evening([
        block('a', DateTime(2026, 12, 3, 17), DateTime(2026, 12, 3, 19)),
        block(
            'a', DateTime(2026, 12, 3, 18, 30), DateTime(2026, 12, 3, 19, 30)),
        block('b', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 19)),
      ])!;
      expect(e.kind, EveningKind.freeFrom);
      expect(e.from, DateTime(2026, 12, 3, 19, 30));
    });

    test('someone busy across midnight: not everyone is free', () {
      final e = evening([
        block('b', DateTime(2026, 12, 3, 22), DateTime(2026, 12, 4, 1)),
      ])!;
      // 22:00 to 23:00 is taken: everyone is free 18:00 to 22:00.
      expect(e.kind, EveningKind.freeBetween);
      expect(e.from, DateTime(2026, 12, 3, 18));
      expect(e.until, DateTime(2026, 12, 3, 22));
      final late = evening([
        block('b', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 4, 1)),
      ])!;
      expect(late.kind, EveningKind.notEveryoneFree);
    });

    test('an event from the night before ending in the morning is fine', () {
      final e = evening([
        block('a', DateTime(2026, 12, 2, 22), DateTime(2026, 12, 3, 2)),
      ])!;
      expect(e.kind, EveningKind.freeAllEvening);
    });

    test('a gap shorter than 30 minutes is not announced', () {
      final e = evening([
        block('a', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 20)),
        block('b', DateTime(2026, 12, 3, 20, 20), DateTime(2026, 12, 3, 23)),
      ])!;
      expect(e.kind, EveningKind.notEveryoneFree);
    });

    test('anyone away all day: not everyone is free', () {
      final e = evening([
        block('a', DateTime(2026, 12, 3), DateTime(2026, 12, 4), allDay: true),
      ])!;
      expect(e.kind, EveningKind.notEveryoneFree);
    });

    test('free (transparent) events do not take the evening', () {
      final e = evening([
        block('a', DateTime(2026, 12, 3, 18), DateTime(2026, 12, 3, 23),
            free: true),
      ])!;
      expect(e.kind, EveningKind.freeAllEvening);
    });

    test('only speaks for people who share', () {
      final e = evening(const [], sharers: ['a'], members: ['a', 'c'])!;
      expect(e.kind, EveningKind.freeAllEvening);
      expect(e.onlySharers, isTrue);
    });

    test('nobody shares: nothing to say', () {
      expect(evening(const [], sharers: const [], members: ['c']), isNull);
    });

    test('today after the evening started: from now, rounded up', () {
      final e = evening(const [], now: DateTime(2026, 12, 3, 19, 5))!;
      expect(e.kind, EveningKind.freeFrom);
      expect(e.from, DateTime(2026, 12, 3, 19, 15));
      expect(evening(const [], now: DateTime(2026, 12, 3, 23, 10)), isNull);
    });
  });
}
