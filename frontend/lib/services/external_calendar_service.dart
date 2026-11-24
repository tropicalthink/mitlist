import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/external_calendar_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

/// Client for `/calendar/external/*`: a member's connected calendars, how
/// each is shared, and per-event choices. Session auth only.
class ExternalCalendarService {
  ExternalCalendarService(this._dio);

  final Dio _dio;

  static Future<ExternalCalendarService> build([Ref? ref]) async {
    return ExternalCalendarService(resolveDio(ref));
  }

  Future<List<CalendarConnection>> listConnections() async {
    try {
      final r = await _dio.get('/calendar/external/connections');
      final data = r.data;
      final raw = data is Map ? data['connections'] : null;
      if (raw is! List) return const [];
      return [
        for (final c in raw)
          if (c is Map) CalendarConnection.fromJson(c.cast<String, dynamic>()),
      ];
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Adds a private iCal link. The server fetches it once before answering;
  /// a link that is not a calendar fails with code `not_calendar` (422).
  Future<CalendarConnection> addIcsConnection({
    required String name,
    required String url,
  }) async {
    try {
      final r = await _dio.post('/calendar/external/connections', data: {
        'kind': 'ics',
        'name': name,
        'url': url,
      });
      return CalendarConnection.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Registers (or finds) this phone's connection.
  Future<CalendarConnection> addDeviceConnection({
    required String name,
    required String deviceId,
  }) async {
    try {
      final r = await _dio.post('/calendar/external/connections', data: {
        'kind': 'device',
        'name': name,
        'device_id': deviceId,
      });
      return CalendarConnection.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  Future<CalendarConnection> renameConnection(String id, String name) async {
    try {
      final r = await _dio
          .patch('/calendar/external/connections/$id', data: {'name': name});
      return CalendarConnection.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  Future<void> deleteConnection(String id) async {
    try {
      await _dio.delete('/calendar/external/connections/$id');
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Refetches an iCal link now (429 within a minute of the last fetch).
  Future<CalendarConnection> syncIcs(String id) async {
    try {
      final r = await _dio.post('/calendar/external/connections/$id/sync');
      return CalendarConnection.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Replaces everything this phone uploaded with [body] (built by
  /// `buildDeviceUpload`, never by hand).
  Future<CalendarConnection> deviceSync(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _dio.put(
        '/calendar/external/connections/$id/device-sync',
        data: body,
      );
      return CalendarConnection.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Replaces a calendar's shares; an empty list shares it with nobody.
  Future<ExternalCalendar> setShares(
    String calendarId,
    List<CalendarShare> shares,
  ) async {
    try {
      final r = await _dio.put(
        '/calendar/external/calendars/$calendarId/shares',
        data: {
          'shares': [for (final s in shares) s.toJson()]
        },
      );
      return ExternalCalendar.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// The owner's stored events (with titles) overlapping [from]..[to].
  Future<List<MyExternalEvent>> myEvents(DateTime from, DateTime to) async {
    try {
      final r =
          await _dio.get('/calendar/external/events/mine', queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      });
      final data = r.data;
      final raw = data is Map ? data['events'] : null;
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) MyExternalEvent.fromJson(e.cast<String, dynamic>()),
      ];
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Every per-event choice the caller made, including ones for events the
  /// server never stored (a hidden phone event is never uploaded).
  Future<List<StoredOverride>> listOverrides() async {
    try {
      final r = await _dio.get('/calendar/external/overrides');
      final data = r.data;
      final raw = data is Map ? data['overrides'] : null;
      if (raw is! List) {
        // A body we cannot read must not pass for "no overrides".
        throw const FormatException('overrides response without a list');
      }
      return [
        for (final o in raw)
          if (o is Map)
            if (StoredOverride.tryFromJson(o.cast<String, dynamic>())
                case final parsed?)
              parsed,
      ];
    } on DioException catch (e) {
      throw apiException(e);
    }
  }

  /// Sets (or with null clears) the owner's choice for one event.
  Future<void> setOverride({
    required String calendarId,
    required String externalUid,
    required EventOverride? visibility,
  }) async {
    try {
      await _dio.put('/calendar/external/overrides', data: {
        'calendar_id': calendarId,
        'external_uid': externalUid,
        'visibility': visibility?.wire,
      });
    } on DioException catch (e) {
      throw apiException(e);
    }
  }
}
