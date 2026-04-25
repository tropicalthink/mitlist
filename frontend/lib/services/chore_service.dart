import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/chore_models.dart';
import 'api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChoreService {
  final Dio _dio;
  final Logger _logger = Logger();
  ChoreService._(this._dio);
  static Future<ChoreService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return ChoreService._(dio);
  }

  Future<Chore> createChore(CreateChoreRequest req) async {
    try {
      final r = await _dio.post('/chores', data: req.toJson());
      return Chore.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Create chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<List<Chore>> listChores(String groupId, {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/chores', queryParameters: {'group_id': groupId, 'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Chore.fromJson(j)).toList();
    } on DioException catch (e) { _logger.e('List chores failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<Chore> getChore(String id) async {
    try {
      final r = await _dio.get('/chores/$id');
      return Chore.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Get chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> deleteChore(String id) async {
    try { await _dio.delete('/chores/$id'); }
    on DioException catch (e) { _logger.e('Delete chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> completeChore(String id, {String? notes}) async {
    try { await _dio.post('/chores/$id/complete', data: {'notes': notes}); }
    on DioException catch (e) { _logger.e('Complete chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> rotateChore(String id) async {
    try { await _dio.post('/chores/$id/rotate'); }
    on DioException catch (e) { _logger.e('Rotate chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> skipChore(String id) async {
    try { await _dio.post('/chores/$id/skip'); }
    on DioException catch (e) { _logger.e('Skip chore failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) return Exception('Network error');
    return Exception('An error occurred');
  }
}
