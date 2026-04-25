import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/vault_models.dart';
import 'api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VaultService {
  final Dio _dio;
  final Logger _logger = Logger();
  VaultService._(this._dio);
  static Future<VaultService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return VaultService._(dio);
  }

  Future<VaultItem> createVaultItem(CreateVaultItemRequest req) async {
    try {
      final r = await _dio.post('/vault', data: req.toJson());
      return VaultItem.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Create vault item failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<List<VaultItem>> listVaultItems(String groupId, {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/vault', queryParameters: {'group_id': groupId, 'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => VaultItem.fromJson(j)).toList();
    } on DioException catch (e) { _logger.e('List vault items failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<VaultItem> getVaultItem(String id) async {
    try {
      final r = await _dio.get('/vault/$id');
      return VaultItem.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Get vault item failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> deleteVaultItem(String id) async {
    try { await _dio.delete('/vault/$id'); }
    on DioException catch (e) { _logger.e('Delete vault item failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) return Exception('Network error');
    return Exception('An error occurred');
  }
}
