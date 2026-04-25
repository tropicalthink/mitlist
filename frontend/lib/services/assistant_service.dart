import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/assistant_models.dart';
import 'api_client.dart';

class AssistantService {
  final Dio _dio;
  final Logger _logger = Logger();

  AssistantService._(this._dio);

  static Future<AssistantService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return AssistantService._(dio);
  }

  Future<ChatSessionModel> createSession(CreateSessionRequest req) async {
    try {
      final r = await _dio.post('/assistant/sessions', data: req.toJson());
      return ChatSessionModel.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create session failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<List<ChatSessionModel>> listSessions({int limit = 50, int offset = 0}) async {
    final r = await _dio.get('/assistant/sessions', queryParameters: {'limit': limit, 'offset': offset});
    final data = r.data;
    if (data is! List) return [];
    return data.map((e) => ChatSessionModel.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<ChatSessionModel> getSession(String id) async {
    final r = await _dio.get('/assistant/sessions/$id');
    return ChatSessionModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<ChatSessionModel> updateSession(String id, UpdateSessionRequest req) async {
    final r = await _dio.patch('/assistant/sessions/$id', data: req.toJson());
    return ChatSessionModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteSession(String id) async {
    await _dio.delete('/assistant/sessions/$id');
  }

  Future<ChatMessageModel> sendMessage(String sessionId, SendMessageRequest req) async {
    final r = await _dio.post('/assistant/sessions/$sessionId/messages', data: req.toJson());
    return ChatMessageModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<ChatMessageModel>> listMessages(String sessionId, {int limit = 50, int offset = 0}) async {
    final r = await _dio.get('/assistant/sessions/$sessionId/messages', queryParameters: {'limit': limit, 'offset': offset});
    final data = r.data;
    if (data is! List) return [];
    return data.map((e) => ChatMessageModel.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}

