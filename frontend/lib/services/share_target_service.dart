import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'api_client.dart';

class ShareTargetService {
  final Dio _dio;
  final Logger _logger = Logger();

  ShareTargetService._(this._dio);

  static Future<ShareTargetService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return ShareTargetService._(dio);
  }

  Future<Map<String, dynamic>> createListFromShare({
    required String groupId,
    required String text,
  }) async {
    try {
      final r = await _dio.post(
        '/share-target/lists',
        data: {'group_id': groupId, 'text': text},
      );
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      _logger.e('ShareTarget lists failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRecipeFromShare({
    required String text,
  }) async {
    try {
      final r = await _dio.post(
        '/share-target/recipes',
        data: {'text': text},
      );
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      _logger.e('ShareTarget recipes failed: ${e.response?.data}');
      rethrow;
    }
  }
}

