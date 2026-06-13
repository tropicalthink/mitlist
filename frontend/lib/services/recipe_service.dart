import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/recipe_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipeService {
  final Dio _dio;
  final Logger _logger = Logger();
  RecipeService._(this._dio);
  static Future<RecipeService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return RecipeService._(dio);
  }

  Future<Recipe> createRecipe(CreateRecipeRequest req) async {
    try {
      final r = await _dio.post('/recipes', data: req.toJson());
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<Recipe>> listRecipes({int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio
          .get('/recipes', queryParameters: {'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Recipe.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List recipes failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<Recipe> getRecipe(String id) async {
    try {
      final r = await _dio.get('/recipes/$id');
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
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
    try {
      await _dio.delete('/recipes/$id');
    } on DioException catch (e) {
      _logger.e('Delete recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> shareRecipe(String id, ShareRecipeRequest req) async {
    try {
      await _dio.post('/recipes/$id/share', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Share recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<RecipeCollection>> listCollections(
      {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/collections',
          queryParameters: {'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => RecipeCollection.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List collections failed: ${e.response?.data}');
      throw _handleError(e);
    }
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

  Future<RecipeCollection> updateCollection(
      String id, UpdateCollectionRequest req) async {
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

  Future<void> addRecipeToCollection(
      String collectionId, AddRecipeToCollectionRequest req) async {
    try {
      await _dio.post('/collections/$collectionId/recipes', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Add recipe to collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> removeRecipeFromCollection(
      String collectionId, String recipeId) async {
    try {
      await _dio.delete('/collections/$collectionId/recipes/$recipeId');
    } on DioException catch (e) {
      _logger.e('Remove recipe from collection failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<RecipeClipResponse> clipRecipeFromUrl(String url) async {
    try {
      final r = await _dio.post('/recipes/clip', data: {'url': url});
      return RecipeClipResponse.fromJson(
          (r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Clip recipe failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addToList(
    String recipeId,
    String listId, {
    int? servings,
    List<String>? ingredientIds,
  }) async {
    try {
      final data = <String, dynamic>{'list_id': listId};
      if (servings != null) data['servings'] = servings;
      if (ingredientIds != null && ingredientIds.isNotEmpty) {
        data['ingredient_ids'] = ingredientIds;
      }
      final r = await _dio.post('/recipes/$recipeId/add-to-list', data: data);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      _logger.e('Add recipe to list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addMissingToList(
      String recipeId, String listId) async {
    try {
      final r = await _dio.post(
        '/recipes/$recipeId/add-missing-to-list',
        data: {'list_id': listId},
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      _logger.e('Add recipe missing products failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    try {
      final r = await _dio.get('/recipes/$recipeId/ingredients');
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => RecipeIngredient.fromJson((j as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      _logger.e('Get recipe ingredients failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<RecipeStep>> getRecipeSteps(String recipeId) async {
    try {
      final r = await _dio.get('/recipes/$recipeId/steps');
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => RecipeStep.fromJson((j as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      _logger.e('Get recipe steps failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    return ApiException(ApiErrorMapper.fromDio(e));
  }
}
