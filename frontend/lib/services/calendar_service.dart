import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/calendar_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

class CalendarService {
  final Dio _dio;
  final Logger _logger;

  CalendarService._(this._dio) : _logger = Logger();

  static Future<CalendarService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return CalendarService._(dio);
  }

  Future<List<CalendarEvent>> getCalendar(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    return parseCalendarEvents(await getCalendarRaw(groupId, from, to));
  }

  /// The server's raw `events` array, undecoded.
  ///
  /// The offline cache stores this rather than re-serialised models:
  /// [CalendarEvent] has five optional nested payloads and no `toJson`, so a
  /// hand-written one would be a second, drifting definition of the wire
  /// format. Keeping the server's own JSON means the cache cannot disagree
  /// with it, and [parseCalendarEvents] is the single decode path for both.
  Future<List<dynamic>> getCalendarRaw(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final r = await _dio.get('/calendar', queryParameters: {
        'group_id': groupId,
        'from': _formatDate(from),
        'to': _formatDate(to),
      });
      final data = r.data as Map<String, dynamic>;
      return data['events'] as List<dynamic>? ?? [];
    } on DioException catch (e) {
      _logger.e('Get calendar failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  static List<CalendarEvent> parseCalendarEvents(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((e) => CalendarEvent.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Fetches the household calendar as an iCalendar (.ics) document over
  /// [from]..[to], suitable for saving or subscribing to in any calendar app.
  Future<String> exportIcal(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final r = await _dio.get(
        '/calendar/ical',
        queryParameters: {
          'group_id': groupId,
          'from': _formatDate(from),
          'to': _formatDate(to),
        },
        options: Options(responseType: ResponseType.plain),
      );
      return r.data as String;
    } on DioException catch (e) {
      _logger.e('Export calendar iCal failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
