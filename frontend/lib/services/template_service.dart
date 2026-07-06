import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/template_models.dart';
import 'api_client.dart';
import 'group_id_validator.dart';

class TemplateService {
  final Dio _dio;
  final Logger _logger = Logger();

  TemplateService._(this._dio);

  static Future<TemplateService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return TemplateService._(dio);
  }

  Future<TemplateModel> createTemplate(CreateTemplateRequest req) async {
    try {
      final r = await _dio.post('/templates', data: req.toJson());
      return TemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create template failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<List<TemplateModel>> listTemplates(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    final r = await _dio.get('/templates', queryParameters: {
      'group_id': groupId,
      'limit': limit,
      'offset': offset
    });
    final data = r.data;
    if (data is! List) return [];
    return data
        .map((e) => TemplateModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<TemplateModel> getTemplate(String id) async {
    final r = await _dio.get('/templates/$id');
    return TemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<TemplateModel> updateTemplate(
      String id, UpdateTemplateRequest req) async {
    final r = await _dio.patch('/templates/$id', data: req.toJson());
    return TemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteTemplate(String id) async {
    await _dio.delete('/templates/$id');
  }

  Future<Map<String, dynamic>> applyTemplate(
      String id, ApplyTemplateRequest req) async {
    final r = await _dio.post('/templates/$id/apply', data: req.toJson());
    return (r.data as Map).cast<String, dynamic>();
  }

  // Chore templates
  Future<ChoreTemplateModel> createChoreTemplate(
      CreateChoreTemplateRequest req) async {
    final r = await _dio.post('/chore-templates', data: req.toJson());
    return ChoreTemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<ChoreTemplateModel>> listChoreTemplates(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    final r = await _dio.get('/chore-templates', queryParameters: {
      'group_id': groupId,
      'limit': limit,
      'offset': offset
    });
    final data = r.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            ChoreTemplateModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ChoreTemplateModel> getChoreTemplate(String id) async {
    final r = await _dio.get('/chore-templates/$id');
    return ChoreTemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<ChoreTemplateModel> updateChoreTemplate(
      String id, UpdateChoreTemplateRequest req) async {
    final r = await _dio.patch('/chore-templates/$id', data: req.toJson());
    return ChoreTemplateModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteChoreTemplate(String id) async {
    await _dio.delete('/chore-templates/$id');
  }
}
