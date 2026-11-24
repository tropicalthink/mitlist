/// Shared household calendars (calendar contract): a member's own calendars,
/// synced from the phone (`device`) or a private iCal link (`ics`), shared
/// per household as busy blocks or with titles.
library;

/// How much of a calendar a household sees. No share row means not shared.
enum ShareVisibility {
  busy,
  details;

  String get wire => name;

  static ShareVisibility? fromWire(Object? value) => switch (value) {
        'busy' => ShareVisibility.busy,
        'details' => ShareVisibility.details,
        _ => null,
      };
}

/// The owner's choice for one event (a recurring series is one event).
enum EventOverride {
  hidden,
  busy,
  details;

  String get wire => name;

  static EventOverride? fromWire(Object? value) => switch (value) {
        'hidden' => EventOverride.hidden,
        'busy' => EventOverride.busy,
        'details' => EventOverride.details,
        _ => null,
      };
}

enum CalendarConnectionKind {
  ics,
  device;

  static CalendarConnectionKind fromWire(Object? value) => value == 'device'
      ? CalendarConnectionKind.device
      : CalendarConnectionKind.ics;
}

class CalendarShare {
  final String groupId;
  final ShareVisibility visibility;

  const CalendarShare({required this.groupId, required this.visibility});

  /// Null for a row this build does not understand: an unknown visibility is
  /// dropped rather than guessed, so it can never read as "with titles".
  static CalendarShare? tryFromJson(Map<String, dynamic> json) {
    final groupId = json['group_id'];
    final visibility = ShareVisibility.fromWire(json['visibility']);
    if (groupId is! String || groupId.isEmpty || visibility == null) {
      return null;
    }
    return CalendarShare(groupId: groupId, visibility: visibility);
  }

  Map<String, dynamic> toJson() =>
      {'group_id': groupId, 'visibility': visibility.wire};

  @override
  bool operator ==(Object other) =>
      other is CalendarShare &&
      other.groupId == groupId &&
      other.visibility == visibility;

  @override
  int get hashCode => Object.hash(groupId, visibility);
}

class ExternalCalendar {
  final String id;
  final String externalId;
  final String name;
  final String? color;
  final List<CalendarShare> shares;

  const ExternalCalendar({
    required this.id,
    required this.externalId,
    required this.name,
    this.color,
    this.shares = const [],
  });

  factory ExternalCalendar.fromJson(Map<String, dynamic> json) =>
      ExternalCalendar(
        id: json['id'] as String,
        externalId: json['external_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String?,
        shares: [
          for (final raw in (json['shares'] as List? ?? const []))
            if (raw is Map)
              if (CalendarShare.tryFromJson(raw.cast<String, dynamic>())
                  case final share?)
                share,
        ],
      );

  /// This calendar's share with [groupId], or null when not shared there.
  ShareVisibility? shareFor(String groupId) {
    for (final share in shares) {
      if (share.groupId == groupId) return share.visibility;
    }
    return null;
  }

  bool get isShared => shares.isNotEmpty;

  ExternalCalendar copyWith({List<CalendarShare>? shares}) => ExternalCalendar(
        id: id,
        externalId: externalId,
        name: name,
        color: color,
        shares: shares ?? this.shares,
      );
}

/// Machine codes the server reports in `last_error`.
enum ConnectionError { fetchFailed, notCalendar, tooLarge, unauthorized, other }

class CalendarConnection {
  final String id;
  final CalendarConnectionKind kind;
  final String name;
  final String? deviceId;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final List<ExternalCalendar> calendars;

  const CalendarConnection({
    required this.id,
    required this.kind,
    required this.name,
    this.deviceId,
    this.lastSyncedAt,
    this.lastError,
    this.calendars = const [],
  });

  factory CalendarConnection.fromJson(Map<String, dynamic> json) {
    final synced = json['last_synced_at'];
    final error = json['last_error'];
    return CalendarConnection(
      id: json['id'] as String,
      kind: CalendarConnectionKind.fromWire(json['kind']),
      name: json['name'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      lastSyncedAt: synced is String ? DateTime.tryParse(synced) : null,
      lastError: error is String && error.isNotEmpty ? error : null,
      calendars: [
        for (final raw in (json['calendars'] as List? ?? const []))
          if (raw is Map)
            ExternalCalendar.fromJson(raw.cast<String, dynamic>()),
      ],
    );
  }

  ConnectionError? get error => switch (lastError) {
        null => null,
        'fetch_failed' => ConnectionError.fetchFailed,
        'not_calendar' => ConnectionError.notCalendar,
        'too_large' => ConnectionError.tooLarge,
        'unauthorized' => ConnectionError.unauthorized,
        _ => ConnectionError.other,
      };

  bool get isDevice => kind == CalendarConnectionKind.device;

  CalendarConnection copyWith({
    String? name,
    List<ExternalCalendar>? calendars,
  }) =>
      CalendarConnection(
        id: id,
        kind: kind,
        name: name ?? this.name,
        deviceId: deviceId,
        lastSyncedAt: lastSyncedAt,
        lastError: lastError,
        calendars: calendars ?? this.calendars,
      );
}

/// One per-event choice as the server keeps it.
class StoredOverride {
  final String calendarId;
  final String externalUid;
  final EventOverride visibility;

  const StoredOverride({
    required this.calendarId,
    required this.externalUid,
    required this.visibility,
  });

  static StoredOverride? tryFromJson(Map<String, dynamic> json) {
    final calendarId = json['calendar_id'];
    final uid = json['external_uid'];
    final visibility = EventOverride.fromWire(json['visibility']);
    if (calendarId is! String || uid is! String || visibility == null) {
      return null;
    }
    return StoredOverride(
        calendarId: calendarId, externalUid: uid, visibility: visibility);
  }
}

/// One of the owner's stored events (`GET /calendar/external/events/mine`),
/// with its title: only the owner gets these.
class MyExternalEvent {
  final String calendarId;
  final String externalUid;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? title;
  final bool sourcePrivate;
  final bool free;
  final EventOverride? override;

  const MyExternalEvent({
    required this.calendarId,
    required this.externalUid,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    this.title,
    this.sourcePrivate = false,
    this.free = false,
    this.override,
  });

  factory MyExternalEvent.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    return MyExternalEvent(
      calendarId: json['calendar_id'] as String,
      externalUid: json['external_uid'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      allDay: json['all_day'] as bool? ?? false,
      title: title is String && title.isNotEmpty ? title : null,
      sourcePrivate: json['source_private'] as bool? ?? false,
      free: json['free'] as bool? ?? false,
      override: EventOverride.fromWire(json['override']),
    );
  }
}
