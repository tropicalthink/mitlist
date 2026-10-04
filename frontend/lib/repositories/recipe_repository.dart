import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe_models.dart' as api;
import '../services/recipe_service.dart';
import '../storage/app_database.dart';
import '../exceptions.dart';
import 'outbox_drainer.dart';

class RecipeRepository {
  final AppDatabase _db;
  final RecipeService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [_afterLocalWrite].
  final void Function()? _onLocalWrite;

  bool _isDraining = false;

  RecipeRepository({
    required AppDatabase db,
    required RecipeService remote,
    Uuid? uuid,
    bool autoSync = true,
    void Function()? onLocalWrite,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync,
        _onLocalWrite = onLocalWrite;

  Stream<List<api.Recipe>> watchRecipes() {
    return _db.watchRecipes().map((rows) => rows.map(_toRecipe).toList());
  }

  Future<List<api.Recipe>> getRecipesOnce() async {
    final rows = await _db.getRecipesOnce();
    return rows.map(_toRecipe).toList();
  }

  Future<api.Recipe?> getRecipeOnce(String recipeId) async {
    final row = await (_db.select(_db.recipesTable)
          ..where((table) => table.id.equals(recipeId)))
        .getSingleOrNull();
    return row == null ? null : _toRecipe(row);
  }

  Future<void> cacheRecipes(Iterable<api.Recipe> recipes) async {
    await _db.upsertRecipesRows(recipes.map(_toRow));
  }

  Future<int> refreshRecipes({int limit = 50, int offset = 0}) async {
    final remote = await _remote.listRecipes(limit: limit, offset: offset);
    await _db.upsertRecipesRows(remote.map(_toRow));
    return remote.length;
  }

  Future<api.Recipe> createRecipeOfflineFirst(
      api.CreateRecipeRequest req) async {
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
      tags: req.tags,
      visibility: req.visibility,
      groupId: req.groupId,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db.upsertRecipesRows([_toRow(local)]);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'createRecipe',
        payload: {'tempId': tempId, 'request': req.toJson()},
        idempotencyKey: 'createRecipe:$tempId',
        entityType: 'recipe',
        entityId: tempId,
      );
    });

    _afterLocalWrite();
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
        tags: req.tags ?? e.tags,
        visibility: req.visibility ?? e.visibility,
        // A patch that only names a visibility of 'private' clears the group;
        // otherwise keep whichever household the recipe already had.
        groupId: req.visibility == api.RecipeVisibility.private
            ? null
            : (req.groupId ?? e.groupId),
        createdAt: e.createdAt,
        updatedAt: DateTime.now(),
      );
      await _db.transaction(() async {
        await _db.upsertRecipesRows([_toRow(patched)]);
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'updateRecipe',
          payload: {'recipeId': recipeId, 'patch': req.toJson()},
          idempotencyKey:
              'updateRecipe:$recipeId:${DateTime.now().toIso8601String()}',
          entityType: 'recipe',
          entityId: recipeId,
        );
      });
    } else {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'updateRecipe',
        payload: {'recipeId': recipeId, 'patch': req.toJson()},
        idempotencyKey:
            'updateRecipe:$recipeId:${DateTime.now().toIso8601String()}',
        entityType: 'recipe',
        entityId: recipeId,
      );
    }

    _afterLocalWrite();

    final row = await (_db.select(_db.recipesTable)
          ..where((t) => t.id.equals(recipeId)))
        .getSingleOrNull();
    return row == null
        ? throw const NotFoundException('Recipe not found')
        : _toRecipe(row);
  }

  Future<void> deleteRecipeOfflineFirst(String recipeId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(recipeId)))
          .go();
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteRecipe',
        payload: {'recipeId': recipeId},
        idempotencyKey: 'deleteRecipe:$recipeId',
        entityType: 'recipe',
        entityId: recipeId,
      );
    });

    _afterLocalWrite();
  }

  /// Called after a write has queued an op (always after its transaction).
  /// Production passes [_onLocalWrite], which only opens the sync session;
  /// without it (tests, direct constructions) the op drains right away.
  void _afterLocalWrite() {
    if (!_autoSync) return;
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce());
    }
  }

  Future<void> drainOutboxOnce() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      await OutboxDrainer(_db).drain(
        types: const ['createRecipe', 'updateRecipe', 'deleteRecipe'],
        handlers: {
          'createRecipe': (op, payload) =>
              _syncCreate(op.id, payload, op.idempotencyKey),
          'updateRecipe': (op, payload) =>
              _syncUpdate(op.id, payload, op.idempotencyKey),
          'deleteRecipe': (op, payload) =>
              _syncDelete(op.id, payload, op.idempotencyKey),
        },
      );
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _syncCreate(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
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
      tags: (requestRaw['tags'] is List)
          ? (requestRaw['tags'] as List).whereType<String>().toList()
          : const [],
      visibility:
          requestRaw['visibility'] as String? ?? api.RecipeVisibility.private,
      groupId: requestRaw['group_id'] as String?,
    );

    final created =
        await _remote.createRecipe(req, idempotencyKey: idempotencyKey);
    await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(tempId)))
        .go();
    await _db.upsertRecipesRows([_toRow(created)]);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdate(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
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
      tags: (patch['tags'] is List)
          ? (patch['tags'] as List).whereType<String>().toList()
          : null,
      visibility: patch['visibility'] as String?,
      groupId: patch['group_id'] as String?,
    );

    final updated = await _remote.updateRecipe(recipeId, req,
        idempotencyKey: idempotencyKey);
    await _db.upsertRecipesRows([_toRow(updated)]);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDelete(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final recipeId = payload['recipeId'] as String?;
    if (recipeId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.deleteRecipe(recipeId, idempotencyKey: idempotencyKey);
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
      visibility: Value(r.visibility),
      groupId: Value(r.groupId),
      tagsJson: Value(jsonEncode(r.tags)),
      createdAt: Value(r.createdAt),
      updatedAt: Value(r.updatedAt),
    );
  }

  /// Tags round-trip through the cache as a JSON array. A row written before
  /// schema 15 decodes to empty rather than throwing.
  static List<String> _decodeTags(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {
      // Corrupt cache entry: treat as untagged, the next sync repairs it.
    }
    return const [];
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
      visibility: row.visibility,
      groupId: row.groupId,
      tags: _decodeTags(row.tagsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
