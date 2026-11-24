import '../models/calendar_models.dart';

/// Where someone is on a day, from the calendars they share.
enum AroundStatus {
  /// Nothing busy that day.
  free,

  /// Busy at some times ([MemberAround.busy]).
  busy,

  /// An all-day event, or timed ones covering the whole day.
  away,

  /// A member who shares no calendar with the household: nothing can be
  /// said about them, so they are never counted as free.
  notSharing,
}

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

  /// When the last busy stretch of the day ends, if it ends before midnight:
  /// "Free from 5:00 PM".
  final DateTime? freeFrom;

  /// For today: the end of the stretch the person is busy in right now.
  final DateTime? busyUntil;

  /// When the last busy stretch starts, for someone busy until midnight.
  final DateTime? busyFrom;

  const MemberAround({
    required this.userId,
    required this.status,
    this.busy = const [],
    this.freeFrom,
    this.busyUntil,
    this.busyFrom,
  });
}

/// Everyone in [sharers] on [day] (a local date): away all day (an all-day
/// event, or timed ones covering the whole day), busy at the merged times
/// of their timed events, or free. Events marked free in the source
/// calendar never make anyone busy. [members] who are not [sharers] are
/// listed after them as [AroundStatus.notSharing]. [now] (for today) fills
/// [MemberAround.busyUntil].
List<MemberAround> whosAround(
  DateTime day,
  Iterable<CalendarEvent> events,
  Iterable<String> sharers, {
  Iterable<String> members = const [],
  DateTime? now,
}) {
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
    if (away) {
      out.add(MemberAround(userId: userId, status: AroundStatus.away));
      continue;
    }
    if (merged.isEmpty) {
      out.add(MemberAround(userId: userId, status: AroundStatus.free));
      continue;
    }
    final last = merged.last;
    DateTime? busyUntil;
    if (now != null) {
      for (final r in merged) {
        if (!now.isBefore(r.start) && now.isBefore(r.end)) busyUntil = r.end;
      }
    }
    out.add(MemberAround(
      userId: userId,
      status: AroundStatus.busy,
      busy: merged,
      freeFrom: last.end.isBefore(dayEnd) ? last.end : null,
      busyFrom: last.end.isBefore(dayEnd) ? null : last.start,
      busyUntil: busyUntil,
    ));
  }
  for (final userId in members) {
    if (!seen.add(userId)) continue;
    out.add(MemberAround(userId: userId, status: AroundStatus.notSharing));
  }
  return out;
}

/// What can truthfully be said about the household's evening.
enum EveningKind {
  /// Every sharer is free for the whole evening.
  freeAllEvening,

  /// Every sharer is free from [HouseholdEvening.from] until it ends.
  freeFrom,

  /// Every sharer is free from [HouseholdEvening.from] until
  /// [HouseholdEvening.until], before the evening ends (the longest such
  /// stretch, at least [kMinEveningStretch]).
  freeBetween,

  /// At least one sharer is away or busy until the evening ends.
  notEveryoneFree,
}

class HouseholdEvening {
  final EveningKind kind;
  final DateTime? from;
  final DateTime? until;

  /// True when some members share no calendar: the line then speaks only
  /// for the people who share ("Everyone who shares is free…").
  final bool onlySharers;

  const HouseholdEvening({
    required this.kind,
    this.from,
    this.until,
    required this.onlySharers,
  });
}

/// The evening is 18:00 to 23:00 local time.
const kEveningStartHour = 18;
const kEveningEndHour = 23;

/// The shortest shared free stretch worth announcing.
const kMinEveningStretch = Duration(minutes: 30);

/// One line for the household's evening on [day], from [around] (as built
/// by [whosAround]). Null when nobody shares a calendar, or when [now] is
/// already past this day's evening. Only people who share are counted;
/// [AroundStatus.notSharing] members only make the line say so.
HouseholdEvening? householdEvening(
  DateTime day,
  List<MemberAround> around, {
  DateTime? now,
}) {
  final sharers =
      around.where((m) => m.status != AroundStatus.notSharing).toList();
  if (sharers.isEmpty) return null;
  final onlySharers = sharers.length != around.length;
  final eveningStart =
      DateTime(day.year, day.month, day.day, kEveningStartHour);
  final eveningEnd = DateTime(day.year, day.month, day.day, kEveningEndHour);
  if (now != null && !now.isBefore(eveningEnd)) return null;

  var start = eveningStart;
  if (now != null && now.isAfter(start)) start = _roundUpToQuarter(now);
  final none = HouseholdEvening(
      kind: EveningKind.notEveryoneFree, onlySharers: onlySharers);
  if (!start.isBefore(eveningEnd)) return null;

  // Everyone's busy times in the evening, merged: what is left is free for
  // every sharer.
  final taken = <BusyRange>[];
  for (final m in sharers) {
    if (m.status == AroundStatus.away) return none;
    for (final r in m.busy) {
      if (r.end.isAfter(start) && r.start.isBefore(eveningEnd)) {
        taken.add(BusyRange(r.start.isBefore(start) ? start : r.start,
            r.end.isAfter(eveningEnd) ? eveningEnd : r.end));
      }
    }
  }
  final gaps = <BusyRange>[];
  var cursor = start;
  for (final r in _merge(taken)) {
    if (r.start.isAfter(cursor)) gaps.add(BusyRange(cursor, r.start));
    if (r.end.isAfter(cursor)) cursor = r.end;
  }
  if (cursor.isBefore(eveningEnd)) gaps.add(BusyRange(cursor, eveningEnd));

  if (gaps.length == 1 &&
      gaps.first.start == eveningStart &&
      gaps.first.end == eveningEnd) {
    return HouseholdEvening(
        kind: EveningKind.freeAllEvening, onlySharers: onlySharers);
  }
  // Free until the evening ends beats a longer stretch in the middle: it is
  // the evening people can plan.
  final tail = gaps.where((g) =>
      g.end == eveningEnd && g.end.difference(g.start) >= kMinEveningStretch);
  if (tail.isNotEmpty) {
    return HouseholdEvening(
        kind: EveningKind.freeFrom,
        from: tail.first.start,
        onlySharers: onlySharers);
  }
  BusyRange? best;
  for (final g in gaps) {
    if (g.end.difference(g.start) < kMinEveningStretch) continue;
    if (best == null ||
        g.end.difference(g.start) > best.end.difference(best.start)) {
      best = g;
    }
  }
  if (best == null) return none;
  return HouseholdEvening(
    kind: EveningKind.freeBetween,
    from: best.start,
    until: best.end,
    onlySharers: onlySharers,
  );
}

DateTime _roundUpToQuarter(DateTime t) {
  final base = DateTime(t.year, t.month, t.day, t.hour);
  final minutes = t.minute + (t.second > 0 || t.millisecond > 0 ? 1 : 0);
  final quarters = (minutes / 15).ceil();
  return base.add(Duration(minutes: quarters * 15));
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
