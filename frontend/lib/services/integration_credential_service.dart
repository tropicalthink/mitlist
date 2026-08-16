import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/integration_credential_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

class IntegrationCredentialService {
  IntegrationCredentialService(this._dio);

  final Dio _dio;

  static Future<IntegrationCredentialService> build([Ref? ref]) async {
    return IntegrationCredentialService(resolveDio(ref));
  }

  Future<List<IntegrationCredential>> list() async {
    try {
      final response = await _dio.get('/auth/integration-credentials');
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(IntegrationCredential.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw apiException(error);
    }
  }

  Future<CreatedIntegrationCredential> create({
    required String name,
    required List<String> groupIds,
    required List<String> scopes,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/integration-credentials',
        data: {
          'name': name,
          'group_ids': groupIds,
          'scopes': scopes,
        },
      );
      return CreatedIntegrationCredential.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw apiException(error);
    }
  }

  Future<void> revoke(String id) async {
    try {
      await _dio.delete('/auth/integration-credentials/$id');
    } on DioException catch (error) {
      throw apiException(error);
    }
  }
}
