import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/weekly_summary_models.dart';
import 'api_client.dart';

class WeeklySummaryService {
  final Dio _dio;
  final Logger _logger = Logger();

  WeeklySummaryService._(this._dio);

  static Future<WeeklySummaryService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return WeeklySummaryService._(dio);
  }

  /// Fetches the household's last seven days of activity with the preceding
  /// week for comparison.
  ///
  /// The device's UTC offset is sent so the server buckets the daily sparkline
  /// against the user's own calendar. An offset is used rather than an IANA
  /// zone name because Dart exposes no tz database without a new dependency —
  /// `timeZoneName` is an ambiguous abbreviation ("CEST"), not a zone id.
  Future<WeeklySummary> getWeeklySummary(String groupId) async {
    try {
      final r = await _dio.get(
        '/groups/$groupId/weekly-summary',
        queryParameters: {
          'tz_offset': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      return WeeklySummary.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Weekly summary failed: ${e.response?.data}');
      rethrow;
    }
  }
}
