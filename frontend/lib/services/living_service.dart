import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/living_models.dart';
import 'api_client.dart';
import 'group_id_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LivingService {
  final Dio _dio;
  final Logger _logger = Logger();
  LivingService._(this._dio);
  static Future<LivingService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return LivingService._(dio);
  }

  Future<LivingThing> createLivingThing(CreateLivingThingRequest req) async {
    try {
      final r = await _dio.post('/living-things', data: req.toJson());
      return LivingThing.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create living thing failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<LivingThing>> listLivingThings(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/living-things', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => LivingThing.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List living things failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<LivingThing> getLivingThing(String id) async {
    try {
      final r = await _dio.get('/living-things/$id');
      return LivingThing.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get living thing failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<LivingThing> updateLivingThing(String id, UpdateLivingThingRequest req) async {
    try {
      final r = await _dio.patch('/living-things/$id', data: req.toJson());
      return LivingThing.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update living thing failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteLivingThing(String id) async {
    try {
      await _dio.delete('/living-things/$id');
    } on DioException catch (e) {
      _logger.e('Delete living thing failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> createCareSchedule(
      String livingThingId, CreateCareScheduleRequest req) async {
    try {
      await _dio.post('/living-things/$livingThingId/care-schedule',
          data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Create care schedule failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> logCare(String livingThingId, LogCareRequest req) async {
    try {
      await _dio.post('/living-things/$livingThingId/care-logs',
          data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Log care failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) {
      return Exception('Network error');
    }
    return Exception('An error occurred');
  }
}
