import 'package:mitlist/models/external_calendar_models.dart';
import 'package:mitlist/services/device_calendar/device_calendar_source.dart';
import 'package:mitlist/services/external_calendar_service.dart';
import 'package:mitlist/utils/external_calendar_visibility.dart';

/// In-memory stand-in for [ExternalCalendarService] that records calls.
class FakeExternalCalendarService implements ExternalCalendarService {
  FakeExternalCalendarService({List<CalendarConnection>? connections})
      : connections = connections ?? [];

  List<CalendarConnection> connections;
  List<MyExternalEvent> mine = [];
  final calls = <String>[];
  final deviceSyncBodies = <Map<String, dynamic>>[];
  final shareCalls = <(String, List<CalendarShare>)>[];
  final overrideCalls = <(String, String, EventOverride?)>[];

  /// What the server keeps, keyed by "calendarId|uid".
  final serverOverrides = <String, EventOverride>{};

  /// Thrown by the next call of that name, then cleared.
  final failures = <String, Object>{};

  void _maybeFail(String name) {
    final f = failures.remove(name);
    if (f != null) Error.throwWithStackTrace(f, StackTrace.current);
  }

  @override
  Future<List<CalendarConnection>> listConnections() async {
    calls.add('list');
    _maybeFail('list');
    return [...connections];
  }

  @override
  Future<CalendarConnection> addIcsConnection(
      {required String name, required String url}) async {
    calls.add('addIcs $name $url');
    _maybeFail('addIcs');
    final c = CalendarConnection(
      id: 'ics-${connections.length + 1}',
      kind: CalendarConnectionKind.ics,
      name: name,
      calendars: [
        ExternalCalendar(
            id: 'cal-ics-${connections.length + 1}',
            externalId: url,
            name: name),
      ],
    );
    connections.add(c);
    return c;
  }

  @override
  Future<CalendarConnection> addDeviceConnection(
      {required String name, required String deviceId}) async {
    calls.add('addDevice $deviceId');
    _maybeFail('addDevice');
    final c = CalendarConnection(
      id: 'dev-1',
      kind: CalendarConnectionKind.device,
      name: name,
      deviceId: deviceId,
    );
    connections.removeWhere((x) => x.id == c.id);
    connections.add(c);
    return c;
  }

  @override
  Future<CalendarConnection> renameConnection(String id, String name) async {
    calls.add('rename $id $name');
    _maybeFail('rename');
    final i = connections.indexWhere((c) => c.id == id);
    connections[i] = connections[i].copyWith(name: name);
    return connections[i];
  }

  @override
  Future<void> deleteConnection(String id) async {
    calls.add('delete $id');
    _maybeFail('delete');
    connections.removeWhere((c) => c.id == id);
  }

  @override
  Future<CalendarConnection> syncIcs(String id) async {
    calls.add('syncIcs $id');
    _maybeFail('syncIcs');
    return connections.firstWhere((c) => c.id == id);
  }

  @override
  Future<CalendarConnection> deviceSync(
      String id, Map<String, dynamic> body) async {
    calls.add('deviceSync $id');
    _maybeFail('deviceSync');
    deviceSyncBodies.add(body);
    final i = connections.indexWhere((c) => c.id == id);
    final existing = {
      for (final c in connections[i].calendars) c.externalId: c
    };
    final calendars = [
      for (final raw
          in (body['calendars'] as List).cast<Map<String, dynamic>>())
        existing[raw['external_id']] ??
            ExternalCalendar(
              id: 'srv-${raw['external_id']}',
              externalId: raw['external_id'] as String,
              name: raw['name'] as String,
            ),
    ];
    connections[i] = connections[i].copyWith(calendars: calendars);
    return connections[i];
  }

  @override
  Future<ExternalCalendar> setShares(
      String calendarId, List<CalendarShare> shares) async {
    calls.add('shares $calendarId');
    _maybeFail('shares');
    shareCalls.add((calendarId, shares));
    for (var i = 0; i < connections.length; i++) {
      final c = connections[i];
      connections[i] = c.copyWith(calendars: [
        for (final cal in c.calendars)
          cal.id == calendarId ? cal.copyWith(shares: shares) : cal,
      ]);
    }
    return connections
        .expand((c) => c.calendars)
        .firstWhere((c) => c.id == calendarId);
  }

  @override
  Future<List<MyExternalEvent>> myEvents(DateTime from, DateTime to) async {
    calls.add('mine');
    _maybeFail('mine');
    return [...mine];
  }

  @override
  Future<void> setOverride(
      {required String calendarId,
      required String externalUid,
      required EventOverride? visibility}) async {
    calls.add('override $calendarId $externalUid ${visibility?.name}');
    _maybeFail('override');
    overrideCalls.add((calendarId, externalUid, visibility));
    final key = '$calendarId|$externalUid';
    if (visibility == null) {
      serverOverrides.remove(key);
    } else {
      serverOverrides[key] = visibility;
    }
  }

  @override
  Future<List<StoredOverride>> listOverrides() async {
    calls.add('listOverrides');
    _maybeFail('listOverrides');
    return [
      for (final e in serverOverrides.entries)
        StoredOverride(
          calendarId: e.key.split('|').first,
          externalUid: e.key.split('|').last,
          visibility: e.value,
        ),
    ];
  }
}

/// A phone with calendars and events, and a settable permission.
class FakeDeviceCalendarSource implements DeviceCalendarSource {
  FakeDeviceCalendarSource({
    this.status = DeviceCalendarPermission.granted,
    this.afterRequest = DeviceCalendarPermission.granted,
    this.supported = true,
    List<DeviceCalendarInfo>? calendars,
    List<DeviceCalendarEvent>? events,
  })  : calendarList = calendars ?? [],
        eventList = events ?? [];

  DeviceCalendarPermission status;
  DeviceCalendarPermission afterRequest;
  bool supported;
  List<DeviceCalendarInfo> calendarList;
  List<DeviceCalendarEvent> eventList;
  int requests = 0;
  int settingsOpened = 0;
  int reads = 0;

  /// Runs inside [events], to simulate something happening mid-read.
  void Function()? duringRead;

  @override
  bool get isSupported => supported;

  @override
  Future<DeviceCalendarPermission> permission() async => status;

  @override
  Future<DeviceCalendarPermission> requestPermission() async {
    requests++;
    status = afterRequest;
    return status;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => [...calendarList];

  @override
  Future<List<DeviceCalendarEvent>> events(DateTime from, DateTime to) async {
    reads++;
    duringRead?.call();
    return [...eventList];
  }
}
