import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/external_calendar_visibility.dart';

/// Calendar access on this phone, as the app needs it: read only.
enum DeviceCalendarPermission { granted, notDetermined, denied, restricted }

/// Reads the phone's own calendars (every account synced to it). Behind an
/// interface so tests and web use a fake or [UnsupportedDeviceCalendarSource].
abstract class DeviceCalendarSource {
  /// Whether this platform has device calendars at all (iOS and Android).
  bool get isSupported;

  /// The current permission, without prompting.
  Future<DeviceCalendarPermission> permission();

  /// Asks for read access. Only call when the person chose "Calendars on
  /// this phone".
  Future<DeviceCalendarPermission> requestPermission();

  /// Opens the system settings page for this app (after a denial).
  Future<void> openSettings();

  Future<List<DeviceCalendarInfo>> calendars();

  /// Occurrences overlapping [from]..[to], recurring series expanded.
  Future<List<DeviceCalendarEvent>> events(DateTime from, DateTime to);

  /// The source for this platform.
  static DeviceCalendarSource forPlatform() {
    if (kIsWeb) return const UnsupportedDeviceCalendarSource();
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => PluginDeviceCalendarSource(),
      TargetPlatform.android => AndroidDeviceCalendarSource(),
      _ => const UnsupportedDeviceCalendarSource(),
    };
  }
}

class UnsupportedDeviceCalendarSource implements DeviceCalendarSource {
  const UnsupportedDeviceCalendarSource();

  @override
  bool get isSupported => false;

  @override
  Future<DeviceCalendarPermission> permission() async =>
      DeviceCalendarPermission.restricted;

  @override
  Future<DeviceCalendarPermission> requestPermission() async =>
      DeviceCalendarPermission.restricted;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => const [];

  @override
  Future<List<DeviceCalendarEvent>> events(DateTime from, DateTime to) async =>
      const [];
}

/// iOS: EventKit through `device_calendar_plus` (full access on iOS 17+,
/// which is the read tier; EventKit has no per-event privacy flag).
class PluginDeviceCalendarSource implements DeviceCalendarSource {
  PluginDeviceCalendarSource([plugin.DeviceCalendar? calendar])
      : _calendar = calendar ?? plugin.DeviceCalendar.instance;

  final plugin.DeviceCalendar _calendar;

  @override
  bool get isSupported => true;

  static DeviceCalendarPermission _map(plugin.CalendarPermissionStatus s) =>
      switch (s) {
        plugin.CalendarPermissionStatus.granted =>
          DeviceCalendarPermission.granted,
        plugin.CalendarPermissionStatus.notDetermined =>
          DeviceCalendarPermission.notDetermined,
        plugin.CalendarPermissionStatus.restricted =>
          DeviceCalendarPermission.restricted,
        // Write-only cannot read events: as good as denied here.
        plugin.CalendarPermissionStatus.writeOnly ||
        plugin.CalendarPermissionStatus.denied =>
          DeviceCalendarPermission.denied,
      };

  @override
  Future<DeviceCalendarPermission> permission() async =>
      _map(await _calendar.hasPermissions());

  @override
  Future<DeviceCalendarPermission> requestPermission() async =>
      _map(await _calendar.requestPermissions());

  @override
  Future<void> openSettings() => _calendar.openAppSettings();

  @override
  Future<List<DeviceCalendarInfo>> calendars() async {
    final list = await _calendar.listCalendars();
    return [
      for (final c in list)
        DeviceCalendarInfo(id: c.id, name: c.name, color: c.colorHex),
    ];
  }

  @override
  Future<List<DeviceCalendarEvent>> events(DateTime from, DateTime to) async {
    final list = await _calendar.listEvents(from, to);
    return [
      for (final e in list)
        DeviceCalendarEvent(
          calendarId: e.calendarId,
          // Shared by every occurrence of a series: one override covers it.
          uid: e.eventId,
          start: e.startDate,
          end: e.endDate,
          allDay: e.isAllDay,
          title: e.title,
          free: e.availability == plugin.EventAvailability.free,
          cancelled: e.status == plugin.EventStatus.canceled,
        ),
    ];
  }
}

/// Android: CalendarContract read in `DeviceCalendarChannel.kt`. Native so
/// the app asks for READ_CALENDAR only and sees each event's access level
/// (private/confidential events are uploaded as busy at most).
class AndroidDeviceCalendarSource implements DeviceCalendarSource {
  AndroidDeviceCalendarSource([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'me.mitlist/device_calendar';

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  static DeviceCalendarPermission _parse(Object? value) => switch (value) {
        'granted' => DeviceCalendarPermission.granted,
        'notDetermined' => DeviceCalendarPermission.notDetermined,
        'restricted' => DeviceCalendarPermission.restricted,
        _ => DeviceCalendarPermission.denied,
      };

  @override
  Future<DeviceCalendarPermission> permission() async =>
      _parse(await _channel.invokeMethod<String>('permission'));

  @override
  Future<DeviceCalendarPermission> requestPermission() async =>
      _parse(await _channel.invokeMethod<String>('requestPermission'));

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<List<DeviceCalendarInfo>> calendars() async {
    final raw = await _channel.invokeListMethod<Map>('calendars') ?? const [];
    return [
      for (final c in raw)
        DeviceCalendarInfo(
          id: '${c['id']}',
          name: c['name'] as String? ?? '',
          color: c['color'] as String?,
        ),
    ];
  }

  @override
  Future<List<DeviceCalendarEvent>> events(DateTime from, DateTime to) async {
    final raw = await _channel.invokeListMethod<Map>('events', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
        }) ??
        const [];
    return [
      for (final e in raw) _parseEvent(e),
    ];
  }

  static DeviceCalendarEvent _parseEvent(Map e) {
    final allDay = e['allDay'] as bool? ?? false;
    final begin = (e['begin'] as num).toInt();
    final end = (e['end'] as num?)?.toInt() ?? begin;
    // CalendarContract stores all-day events at UTC midnights; read their
    // date components as the local date.
    DateTime at(int ms) {
      if (!allDay) return DateTime.fromMillisecondsSinceEpoch(ms);
      final u = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      return DateTime(u.year, u.month, u.day);
    }

    return DeviceCalendarEvent(
      calendarId: '${e['calendarId']}',
      uid: '${e['eventId']}',
      start: at(begin),
      end: at(end),
      allDay: allDay,
      title: e['title'] as String? ?? '',
      sourcePrivate: e['private'] as bool? ?? false,
      free: e['free'] as bool? ?? false,
      cancelled: e['cancelled'] as bool? ?? false,
    );
  }
}
