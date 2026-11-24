import '../models/calendar_models.dart';

/// Where someone is on a day, from the calendars they share.
enum AroundStatus { free, busy, away }

class BusyRange {
  final DateTime start;
  final DateTime end;

  const BusyRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is BusyRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'BusyRange($start, $end)';
}

class MemberAround {
  final String userId;
  final AroundStatus status;

  /// Busy times that day (local, clipped to the day, merged), for [busy].
  final List<BusyRange> busy;

  const MemberAround({
    required this.userId,
    required this.status,
    this.busy = const [],
  });
}

/// Everyone in [sharers] on [day] (a local date): away all day (an all-day
/// event, or timed ones covering the whole day), busy at the merged times
/// of their timed events, or free. Events marked free in the source
/// calendar do not make anyone busy. [events] may hold any calendar events;
/// only shared-calendar ones are read.
List<MemberAround> whosAround(
  DateTime day,
  Iterable<CalendarEvent> events,
  Iterable<String> sharers,
) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final byUser = <String, List<CalendarExternalEvent>>{};
  for (final e in events) {
    final x = e.external;
    if (e.type != CalendarEventType.externalEvent || x == null || x.free) {
      continue;
    }
    byUser.putIfAbsent(x.userId, () => []).add(x);
  }

  final out = <MemberAround>[];
  final seen = <String>{};
  for (final userId in sharers) {
    if (!seen.add(userId)) continue;
    var away = false;
    final ranges = <BusyRange>[];
    for (final x in byUser[userId] ?? const <CalendarExternalEvent>[]) {
      if (x.allDay) {
        if (!x.startDay.isAfter(dayStart) &&
            x.endDayExclusive.isAfter(dayStart)) {
          away = true;
        }
        continue;
      }
      final start = x.startsAt.toLocal();
      final end = x.endsAt.toLocal();
      if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) continue;
      final s = start.isBefore(dayStart) ? dayStart : start;
      final en = end.isAfter(dayEnd) ? dayEnd : end;
      if (!en.isAfter(s)) continue;
      ranges.add(BusyRange(s, en));
    }
    final merged = _merge(ranges);
    if (!away &&
        merged.length == 1 &&
        merged.first.start == dayStart &&
        merged.first.end == dayEnd) {
      away = true;
    }
    out.add(MemberAround(
      userId: userId,
      status: away
          ? AroundStatus.away
          : (merged.isEmpty ? AroundStatus.free : AroundStatus.busy),
      busy: away ? const [] : merged,
    ));
  }
  return out;
}

List<BusyRange> _merge(List<BusyRange> ranges) {
  if (ranges.isEmpty) return const [];
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final out = <BusyRange>[sorted.first];
  for (final r in sorted.skip(1)) {
    final last = out.last;
    if (!r.start.isAfter(last.end)) {
      if (r.end.isAfter(last.end)) {
        out[out.length - 1] = BusyRange(last.start, r.end);
      }
    } else {
      out.add(r);
    }
  }
  return out;
}
