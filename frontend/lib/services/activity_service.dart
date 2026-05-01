import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/activity_models.dart';
import 'api_client.dart';

class ActivityService {
  final Dio _dio;
  final Logger _logger = Logger();

  ActivityService._(this._dio);

  static Future<ActivityService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return ActivityService._(dio);
  }

  Future<List<ActivityLogModel>> listActivityLogs(String groupId,
      {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/activity', queryParameters: {
        'group_id': groupId,
        'limit': limit,
      });
      final data = r.data as Map<String, dynamic>;
      final rawEvents = data['events'] as List<dynamic>? ?? [];
      return rawEvents
          .map((e) => ActivityLogModel.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List activity failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<ActivityLogModel> getActivityLog(String id) async {
    final r = await _dio.get('/activity-logs/$id');
    return ActivityLogModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteActivityLog(String id) async {
    await _dio.delete('/activity-logs/$id');
  }
}
