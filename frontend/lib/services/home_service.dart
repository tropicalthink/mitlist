import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/home_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'group_id_validator.dart';
import 'response_cache_interceptor.dart';

class HomeService {
  final Dio _dio;
  final Logger _logger = Logger();

  HomeService._(this._dio);

  static Future<HomeService> create([Ref? ref]) async {
    return HomeService._(resolveDio(ref));
  }

  Future<HomeSnapshot> getSnapshot(
    String groupId, {
    required String date,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final response = await _dio.get(
        '/groups/$groupId/home',
        queryParameters: {'date': date},
        // Home writes this aggregate into the hub, pinwall and meal-plan
        // Drift caches. A stale offline copy would overwrite them with older
        // data than they already hold, so offline this fails and Home keeps
        // painting from those caches instead.
        options: Options(extra: {ResponseCacheInterceptor.liveOnlyExtra: true}),
      );
      return HomeSnapshot.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      _logger.e('Load Home snapshot failed: ${error.response?.data}');
      throw apiException(error);
    }
  }
}
