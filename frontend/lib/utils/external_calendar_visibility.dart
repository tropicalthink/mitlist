import '../models/external_calendar_models.dart';

/// What a housemate sees of one event, by the calendar contract's visibility
/// rules. The server enforces them; the app uses the same rules to filter
/// what a phone uploads and to tell the owner what each household sees.
enum HousemateView { nothing, busy, details }

/// What a housemate in one household sees of an event.
///
/// [share] is the calendar's share with that household (null: not shared).
/// [hasTitle] is whether a title is (or would be) stored: "with titles"
/// without a title degrades to busy.
HousemateView housemateView({
  required ShareVisibility? share,
  required EventOverride? override,
  required bool sourcePrivate,
  required bool hasTitle,
}) {
  // 1. Not shared with this household: nothing, whatever the override.
  if (share == null) return HousemateView.nothing;
  // 2. The owner's choice for this event wins over the calendar's.
  final HousemateView wanted;
  switch (override) {
    case EventOverride.hidden:
      return HousemateView.nothing;
    case EventOverride.busy:
      wanted = HousemateView.busy;
    case EventOverride.details:
      wanted = HousemateView.details;
    case null:
      // 3. Private in the source calendar: busy at most.
      wanted = sourcePrivate
          ? HousemateView.busy
          : (share == ShareVisibility.details
              ? HousemateView.details
              : HousemateView.busy);
  }
  // 4. Details without a title is a busy block.
  if (wanted == HousemateView.details && !hasTitle) return HousemateView.busy;
  return wanted;
}

/// The longest title the server keeps.
const kExternalTitleMaxLength = 200;

/// Limits from the contract; the phone trims to them before uploading.
const kMaxCalendarsPerConnection = 50;
const kMaxEventsPerConnection = 5000;

/// A calendar as the phone reports it.
class DeviceCalendarInfo {
  final String id;
  final String name;
  final String? color;

  const DeviceCalendarInfo({required this.id, required this.name, this.color});
}

/// One occurrence read from the phone. A recurring series shares [uid];
/// occurrences differ by [start].
class DeviceCalendarEvent {
  final String calendarId;
  final String uid;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String title;
  final bool sourcePrivate;
  final bool free;
  final bool cancelled;

  const DeviceCalendarEvent({
    required this.calendarId,
    required this.uid,
    required this.start,
    required this.end,
    required this.allDay,
    this.title = '',
    this.sourcePrivate = false,
    this.free = false,
    this.cancelled = false,
  });

  /// The instant the server stores as starts_at: for all-day events the UTC
  /// midnight of the local date (end exclusive), else the instant itself.
  DateTime get wireStart => allDay ? _utcMidnight(start) : start.toUtc();

  DateTime get wireEnd {
    if (!allDay) {
      final e = end.toUtc();
      return e.isBefore(wireStart) ? wireStart : e;
    }
    final e = _utcMidnight(end);
    // A one-day all-day event can come back with end == start (or end at
    // 23:59 of the same day); it still covers that day.
    return e.isAfter(wireStart) ? e : wireStart.add(const Duration(days: 1));
  }

  static DateTime _utcMidnight(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);
}

/// The `PUT /calendar/external/connections/{id}/device-sync` body.
class DeviceUpload {
  final List<Map<String, dynamic>> calendars;
  final List<Map<String, dynamic>> events;

  const DeviceUpload({required this.calendars, required this.events});

  Map<String, dynamic> toJson() => {'calendars': calendars, 'events': events};
}

/// Builds what this phone uploads, by the contract's device client upload
/// rule. The one place that decides what leaves the phone:
/// - every calendar's name and colour is listed (the owner needs the server's
///   id for a calendar to share it; housemates never see calendar names), but
///   events go up only from calendars shared with at least one household;
/// - cancelled events and events the owner hid are never uploaded;
/// - a title goes up only when some household could see it: the event is
///   overridden "with title", or has no override, is not private in its
///   source and its calendar is shared "with titles" somewhere.
///
/// [shares] maps a device calendar id to its server shares; [overrides] maps
/// a device calendar id and event uid to the owner's choice.
DeviceUpload buildDeviceUpload({
  required List<DeviceCalendarInfo> calendars,
  required List<DeviceCalendarEvent> events,
  required Map<String, List<CalendarShare>> shares,
  required EventOverride? Function(String calendarId, String uid) overrides,
}) {
  final listed = <DeviceCalendarInfo>[];
  final seenCalendars = <String>{};
  // Shared calendars first, so the 50-calendar cap never drops one of them.
  final ordered = [
    ...calendars.where((c) => (shares[c.id] ?? const []).isNotEmpty),
    ...calendars.where((c) => (shares[c.id] ?? const []).isEmpty),
  ];
  for (final c in ordered) {
    if (c.id.isEmpty || !seenCalendars.add(c.id)) continue;
    if (listed.length >= kMaxCalendarsPerConnection) break;
    listed.add(c);
  }
  final listedIds = {for (final c in listed) c.id};

  final out = <Map<String, dynamic>>[];
  final seenEvents = <String>{};
  final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
  for (final e in sorted) {
    if (out.length >= kMaxEventsPerConnection) break;
    if (e.cancelled || e.uid.isEmpty) continue;
    if (!listedIds.contains(e.calendarId)) continue;
    final calendarShares = shares[e.calendarId] ?? const <CalendarShare>[];
    if (calendarShares.isEmpty) continue;
    final override = overrides(e.calendarId, e.uid);
    if (override == EventOverride.hidden) continue;
    final key = '${e.calendarId}|${e.uid}|${e.wireStart.toIso8601String()}';
    if (!seenEvents.add(key)) continue;

    final title = e.title.trim();
    final anyDetailsShare =
        calendarShares.any((s) => s.visibility == ShareVisibility.details);
    final sendTitle = title.isNotEmpty &&
        (override == EventOverride.details ||
            (override == null && !e.sourcePrivate && anyDetailsShare));

    out.add({
      'calendar_external_id': e.calendarId,
      'external_uid': e.uid,
      'starts_at': e.wireStart.toIso8601String(),
      'ends_at': e.wireEnd.toIso8601String(),
      'all_day': e.allDay,
      if (sendTitle)
        'title': title.runes.length > kExternalTitleMaxLength
            ? String.fromCharCodes(title.runes.take(kExternalTitleMaxLength))
            : title,
      'source_private': e.sourcePrivate,
      'free': e.free,
    });
  }

  return DeviceUpload(
    calendars: [
      for (final c in listed)
        {
          'external_id': c.id,
          'name': c.name,
          if (c.color != null && c.color!.isNotEmpty) 'color': c.color,
        },
    ],
    events: out,
  );
}
