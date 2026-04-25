import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/recipe_models.dart';
import 'api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipeService {
  final Dio _dio;
  final Logger _logger = Logger();
  RecipeService._(this._dio);
  static Future<RecipeService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return RecipeService._(dio);
  }

  Future<Recipe> createRecipe(CreateRecipeRequest req) async {
    try {
      final r = await _dio.post('/recipes', data: req.toJson());
      return Recipe.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Create recipe failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<List<Recipe>> listRecipes({int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/recipes', queryParameters: {'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Recipe.fromJson(j)).toList();
    } on DioException catch (e) { _logger.e('List recipes failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<Recipe> getRecipe(String id) async {
    try {
      final r = await _dio.get('/recipes/$id');
      return Recipe.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Get recipe failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<Recipe> updateRecipe(String id, UpdateRecipeRequest req) async {
    try {
      final r = await _dio.patch('/recipes/$id', data: req.toJson());
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteRecipe(String id) async {
    try { await _dio.delete('/recipes/$id'); }
    on DioException catch (e) { _logger.e('Delete recipe failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> shareRecipe(String id, ShareRecipeRequest req) async {
    try {
      await _dio.post('/recipes/$id/share', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Share recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<RecipeCollection>> listCollections({int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/collections', queryParameters: {'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => RecipeCollection.fromJson(j)).toList();
    } on DioException catch (e) { _logger.e('List collections failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<RecipeCollection> createCollection(CreateCollectionRequest req) async {
    try {
      final r = await _dio.post('/collections', data: req.toJson());
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<RecipeCollection> getCollection(String id) async {
    try {
      final r = await _dio.get('/collections/$id');
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<RecipeCollection> updateCollection(String id, UpdateCollectionRequest req) async {
    try {
      final r = await _dio.patch('/collections/$id', data: req.toJson());
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _dio.delete('/collections/$id');
    } on DioException catch (e) {
      _logger.e('Delete collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> addRecipeToCollection(String collectionId, AddRecipeToCollectionRequest req) async {
    try {
      await _dio.post('/collections/$collectionId/recipes', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Add recipe to collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> removeRecipeFromCollection(String collectionId, String recipeId) async {
    try {
      await _dio.delete('/collections/$collectionId/recipes/$recipeId');
    } on DioException catch (e) {
      _logger.e('Remove recipe from collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) return Exception('Network error');
    return Exception('An error occurred');
  }
}
