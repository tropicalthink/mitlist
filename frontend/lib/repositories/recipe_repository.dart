import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe_models.dart' as api;
import '../services/recipe_service.dart';
import '../storage/app_database.dart';

class RecipeRepository {
  final AppDatabase _db;
  final RecipeService _remote;
  final Uuid _uuid;

  RecipeRepository({
    required AppDatabase db,
    required RecipeService remote,
    Uuid? uuid,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid();

  Stream<List<api.Recipe>> watchRecipes() {
    return _db.watchRecipes().map((rows) => rows.map(_toRecipe).toList());
  }

  Future<List<api.Recipe>> getRecipesOnce() async {
    final rows = await _db.getRecipesOnce();
    return rows.map(_toRecipe).toList();
  }

  Future<int> refreshRecipes({int limit = 50, int offset = 0}) async {
    final remote = await _remote.listRecipes(limit: limit, offset: offset);
    await _db.upsertRecipesRows(remote.map(_toRow));
    return remote.length;
  }

  Future<api.Recipe> createRecipeOfflineFirst(api.CreateRecipeRequest req) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();
    final local = api.Recipe(
      id: tempId,
      title: req.title,
      description: req.description,
      prepTime: req.prepTime,
      cookTime: req.cookTime,
      servings: req.servings,
      imageUrl: req.imageUrl,
      isPublic: req.isPublic,
      createdAt: now,
      updatedAt: now,
    );

    await _db.upsertRecipesRows([_toRow(local)]);
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createRecipe',
      payload: {'tempId': tempId, 'request': req.toJson()},
      idempotencyKey: 'createRecipe:$tempId',
    );

    await drainOutboxOnce();
    return local;
  }

  Future<api.Recipe> updateRecipeOfflineFirst(
    String recipeId,
    api.UpdateRecipeRequest req,
  ) async {
    // Optimistic patch
    final existingRows = await (_db.select(_db.recipesTable)
          ..where((t) => t.id.equals(recipeId)))
        .get();
    if (existingRows.isNotEmpty) {
      final e = _toRecipe(existingRows.first);
      final patched = api.Recipe(
        id: e.id,
        title: req.title ?? e.title,
        description: req.description ?? e.description,
        prepTime: req.prepTime ?? e.prepTime,
        cookTime: req.cookTime ?? e.cookTime,
        servings: req.servings ?? e.servings,
        imageUrl: req.imageUrl ?? e.imageUrl,
        isPublic: req.isPublic ?? e.isPublic,
        createdAt: e.createdAt,
        updatedAt: DateTime.now(),
      );
      await _db.upsertRecipesRows([_toRow(patched)]);
    }

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'updateRecipe',
      payload: {'recipeId': recipeId, 'patch': req.toJson()},
      idempotencyKey: 'updateRecipe:$recipeId:${DateTime.now().toIso8601String()}',
    );

    await drainOutboxOnce();

    final row = await (_db.select(_db.recipesTable)
          ..where((t) => t.id.equals(recipeId)))
        .getSingleOrNull();
    return row == null ? throw Exception('Recipe not found') : _toRecipe(row);
  }

  Future<void> deleteRecipeOfflineFirst(String recipeId) async {
    await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(recipeId)))
        .go();

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'deleteRecipe',
      payload: {'recipeId': recipeId},
      idempotencyKey: 'deleteRecipe:$recipeId',
    );

    await drainOutboxOnce();
  }

  Future<void> drainOutboxOnce() async {
    final batch = await _db.getOutboxBatchByTypes(
      ['createRecipe', 'updateRecipe', 'deleteRecipe'],
      limit: 25,
    );
    if (batch.isEmpty) return;

    for (final op in batch) {
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }

      try {
        switch (op.type) {
          case 'createRecipe':
            await _syncCreate(op.id, payload);
            break;
          case 'updateRecipe':
            await _syncUpdate(op.id, payload);
            break;
          case 'deleteRecipe':
            await _syncDelete(op.id, payload);
            break;
        }
      } catch (e) {
        await _db.markOutboxAttempt(op.id, error: e.toString());
        return;
      }
    }
  }

  Future<void> _syncCreate(String opId, Map<String, dynamic> payload) async {
    final tempId = payload['tempId'] as String?;
    final requestRaw = payload['request'];
    if (tempId == null || requestRaw is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final req = api.CreateRecipeRequest(
      title: requestRaw['title'] as String,
      description: requestRaw['description'] as String? ?? '',
      prepTime: requestRaw['prep_time'] as int? ?? 0,
      cookTime: requestRaw['cook_time'] as int? ?? 0,
      servings: requestRaw['servings'] as int? ?? 1,
      imageUrl: requestRaw['image_url'] as String?,
      isPublic: requestRaw['is_public'] as bool? ?? false,
    );

    final created = await _remote.createRecipe(req);
    await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(tempId))).go();
    await _db.upsertRecipesRows([_toRow(created)]);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdate(String opId, Map<String, dynamic> payload) async {
    final recipeId = payload['recipeId'] as String?;
    final patch = payload['patch'];
    if (recipeId == null || patch is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final req = api.UpdateRecipeRequest(
      title: patch['title'] as String?,
      description: patch['description'] as String?,
      prepTime: patch['prep_time'] as int?,
      cookTime: patch['cook_time'] as int?,
      servings: patch['servings'] as int?,
      imageUrl: patch['image_url'] as String?,
      isPublic: patch['is_public'] as bool?,
    );

    final updated = await _remote.updateRecipe(recipeId, req);
    await _db.upsertRecipesRows([_toRow(updated)]);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDelete(String opId, Map<String, dynamic> payload) async {
    final recipeId = payload['recipeId'] as String?;
    if (recipeId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.deleteRecipe(recipeId);
    await _db.deleteOutboxOp(opId);
  }

  RecipesTableCompanion _toRow(api.Recipe r) {
    return RecipesTableCompanion(
      id: Value(r.id),
      title: Value(r.title),
      description: Value(r.description),
      prepTime: Value(r.prepTime),
      cookTime: Value(r.cookTime),
      servings: Value(r.servings),
      imageUrl: Value(r.imageUrl),
      isPublic: Value(r.isPublic),
      createdAt: Value(r.createdAt),
      updatedAt: Value(r.updatedAt),
    );
  }

  api.Recipe _toRecipe(RecipesTableData row) {
    return api.Recipe(
      id: row.id,
      title: row.title,
      description: row.description,
      prepTime: row.prepTime,
      cookTime: row.cookTime,
      servings: row.servings,
      imageUrl: row.imageUrl,
      isPublic: row.isPublic,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

