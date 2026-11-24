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
}
