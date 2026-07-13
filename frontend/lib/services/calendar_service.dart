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
    try {
      final r = await _dio.get('/calendar', queryParameters: {
        'group_id': groupId,
        'from': _formatDate(from),
        'to': _formatDate(to),
      });
      final data = r.data as Map<String, dynamic>;
      final rawEvents = data['events'] as List<dynamic>? ?? [];
      return rawEvents
          .map(
              (e) => CalendarEvent.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('Get calendar failed: ${e.response?.data}');
      throw apiException(e);
    }
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
