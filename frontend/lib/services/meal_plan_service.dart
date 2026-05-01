import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/meal_plan_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'group_id_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MealPlanService {
  final Dio _dio;
  final Logger _logger = Logger();
  MealPlanService._(this._dio);
  static Future<MealPlanService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return MealPlanService._(dio);
  }

  Future<MealPlan> createMealPlan(CreateMealPlanRequest req) async {
    try {
      final r = await _dio.post('/meal-plans', data: req.toJson());
      return MealPlan.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create meal plan failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<MealPlan>> listMealPlans(
    String groupId, {
    required String from,
    required String to,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/meal-plans', queryParameters: {
        'group_id': groupId,
        'from': from,
        'to': to,
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => MealPlan.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List meal plans failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<MealPlan> getMealPlan(String id) async {
    try {
      final r = await _dio.get('/meal-plans/$id');
      return MealPlan.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get meal plan failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<MealPlan> updateMealPlan(String id, UpdateMealPlanRequest req) async {
    try {
      final r = await _dio.patch('/meal-plans/$id', data: req.toJson());
      return MealPlan.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update meal plan failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteMealPlan(String id) async {
    try {
      await _dio.delete('/meal-plans/$id');
    } on DioException catch (e) {
      _logger.e('Delete meal plan failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> generateShoppingList(
    String groupId, {
    required String from,
    required String to,
    String? listId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final data = <String, dynamic>{
        'group_id': groupId,
        'from': from,
        'to': to,
      };
      if (listId != null) data['list_id'] = listId;
      final r = await _dio.post('/meal-plans/generate-shopping-list', data: data);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      _logger.e('Generate shopping list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    return Exception(ApiErrorMapper.fromDio(e));
  }
}
