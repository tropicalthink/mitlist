import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/pinwall_media_models.dart';
import '../models/pinwall_models.dart';
import 'api_client.dart';
import 'group_id_validator.dart';

class PinwallService {
  final Dio _dio;
  final Logger _logger = Logger();

  PinwallService._(this._dio);

  static Future<PinwallService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return PinwallService._(dio);
  }

  Future<List<PinwallPost>> listPosts(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get(
        '/pinwall/posts',
        queryParameters: {
          'group_id': groupId,
          'limit': limit,
          'offset': offset
        },
      );
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((e) => PinwallPost.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List pinwall posts failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<PinwallPost> createPost(
    String groupId, {
    required String content,
    DateTime? remindAt,
    String? linkedEntityType,
    String? linkedEntityId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.post(
        '/pinwall/posts',
        data: {
          'group_id': groupId,
          'content': content,
          if (remindAt != null) 'remind_at': remindAt.toUtc().toIso8601String(),
          if (linkedEntityType != null) 'linked_entity_type': linkedEntityType,
          if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
        },
      );
      return PinwallPost.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create pinwall post failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<void> deletePost(String groupId, String postId) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.delete(
        '/pinwall/posts/$postId',
        queryParameters: {'group_id': groupId},
      );
    } on DioException catch (e) {
      _logger.e('Delete pinwall post failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<void> attachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.post(
        '/pinwall/posts/$postId/attachments',
        data: {
          'group_id': groupId,
          'attachment_id': attachmentId,
        },
      );
    } on DioException catch (e) {
      _logger.e('Attach pinwall media failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<List<PinwallMediaItem>> listPostAttachments({
    required String groupId,
    required String postId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get(
        '/pinwall/posts/$postId/attachments',
        queryParameters: {'group_id': groupId},
      );
      final data = r.data;
      if (data is! List) return const [];
      return data
          .map((e) =>
              PinwallMediaItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List pinwall media failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<void> detachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.delete(
        '/pinwall/posts/$postId/attachments/$attachmentId',
        queryParameters: {'group_id': groupId},
      );
    } on DioException catch (e) {
      _logger.e('Detach pinwall media failed: ${e.response?.data}');
      rethrow;
    }
  }
}
