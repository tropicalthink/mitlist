import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/recipe_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'outbox_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipeService {
  final Dio _dio;
  final Logger _logger = Logger();
  RecipeService._(this._dio);
  static Future<RecipeService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return RecipeService._(dio);
  }

  Future<Recipe> createRecipe(CreateRecipeRequest req,
      {String? idempotencyKey}) async {
    try {
      final r = await _dio.post('/recipes',
          data: req.toJson(), options: outboxOptions(idempotencyKey));
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Lists the caller's recipes, plus everything shared with [groupId] when
  /// one is given.
  ///
  /// [tags] and [search] filter server-side, so they narrow the whole library
  /// rather than whichever page happens to be loaded.
  Future<List<Recipe>> listRecipes({
    int limit = 50,
    int offset = 0,
    String? groupId,
    List<String> tags = const [],
    String? search,
  }) async {
    try {
      final r = await _dio.get('/recipes', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (groupId != null) 'group_id': groupId,
        if (tags.isNotEmpty) 'tag': tags,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Recipe.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List recipes failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// The tags in use across everything the caller can see, most-used first.
  Future<List<RecipeTagCount>> listRecipeTags({
    String? groupId,
    int limit = 30,
  }) async {
    try {
      final r = await _dio.get('/recipes/tags', queryParameters: {
        'limit': limit,
        if (groupId != null) 'group_id': groupId,
      });
      final data = r.data;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((j) => RecipeTagCount.fromJson(j.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List recipe tags failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Recipe> getRecipe(String id) async {
    try {
      final r = await _dio.get('/recipes/$id');
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Recipe> updateRecipe(String id, UpdateRecipeRequest req,
      {String? idempotencyKey}) async {
    try {
      final r = await _dio.patch('/recipes/$id',
          data: req.toJson(), options: outboxOptions(idempotencyKey));
      return Recipe.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteRecipe(String id, {String? idempotencyKey}) async {
    try {
      await _dio.delete('/recipes/$id', options: outboxOptions(idempotencyKey));
    } on DioException catch (e) {
      _logger.e('Delete recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> shareRecipe(String id, ShareRecipeRequest req) async {
    try {
      await _dio.post('/recipes/$id/share', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Share recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<RecipeCollection>> listCollections(
      {int limit = 50, int offset = 0, String? groupId}) async {
    try {
      final r = await _dio.get('/collections', queryParameters: {
        'limit': limit,
        'offset': offset,
        if (groupId != null) 'group_id': groupId,
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => RecipeCollection.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List collections failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecipeCollection> createCollection(CreateCollectionRequest req) async {
    try {
      final r = await _dio.post('/collections', data: req.toJson());
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Recipe>> getCollectionRecipes(String collectionId,
      {int limit = 100, int offset = 0}) async {
    try {
      final r = await _dio.get('/collections/$collectionId/recipes',
          queryParameters: {'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Recipe.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List collection recipes failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecipeCollection> getCollection(String id) async {
    try {
      final r = await _dio.get('/collections/$id');
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecipeCollection> updateCollection(
      String id, UpdateCollectionRequest req) async {
    try {
      final r = await _dio.patch('/collections/$id', data: req.toJson());
      return RecipeCollection.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _dio.delete('/collections/$id');
    } on DioException catch (e) {
      _logger.e('Delete collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> addRecipeToCollection(
      String collectionId, AddRecipeToCollectionRequest req) async {
    try {
      await _dio.post('/collections/$collectionId/recipes', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Add recipe to collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> removeRecipeFromCollection(
      String collectionId, String recipeId) async {
    try {
      await _dio.delete('/collections/$collectionId/recipes/$recipeId');
    } on DioException catch (e) {
      _logger.e('Remove recipe from collection failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Returns the recipe's share link, minting one on first call.
  ///
  /// Idempotent server-side, so tapping Share repeatedly hands out the same
  /// URL rather than leaving extra live links behind.
  Future<RecipeShareLink> createShareLink(String recipeId) async {
    try {
      final r = await _dio.post('/recipes/$recipeId/share-link');
      return RecipeShareLink.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create share link failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Invalidates every share link already handed out for this recipe.
  Future<void> revokeShareLink(String recipeId) async {
    try {
      await _dio.delete('/recipes/$recipeId/share-link');
    } on DioException catch (e) {
      _logger.e('Revoke share link failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Resolves a share link. Unauthenticated on the server — the token is the
  /// credential — so this works before the recipient has signed in.
  Future<SharedRecipe> getSharedRecipe(String token) async {
    try {
      final r = await _dio.get('/shared-recipes/$token');
      return SharedRecipe.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get shared recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Copies a shared recipe into the caller's library. Pass a [groupId] with
  /// [RecipeVisibility.household] to save it for the whole household.
  Future<Recipe> saveSharedRecipe(
    String token, {
    String visibility = RecipeVisibility.private,
    String? groupId,
  }) async {
    try {
      final r = await _dio.post('/shared-recipes/$token/save', data: {
        'visibility': visibility,
        if (groupId != null) 'group_id': groupId,
      });
      return Recipe.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Save shared recipe failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecipeClipResponse> clipRecipeFromUrl(String url) async {
    try {
      final r = await _dio.post('/recipes/clip', data: {'url': url});
      return RecipeClipResponse.fromJson(
          (r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Clip recipe failed: ${e.response?.data}');
      throw apiException(e);
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
      throw apiException(e);
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
      throw apiException(e);
    }
  }

  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    try {
      final r = await _dio.get('/recipes/$recipeId/ingredients');
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) =>
              RecipeIngredient.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('Get recipe ingredients failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<RecipeStep>> getRecipeSteps(String recipeId) async {
    try {
      final r = await _dio.get('/recipes/$recipeId/steps');
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) => RecipeStep.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('Get recipe steps failed: ${e.response?.data}');
      throw apiException(e);
    }
  }
}
