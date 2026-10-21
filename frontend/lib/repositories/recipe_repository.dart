import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe_models.dart' as api;
import '../services/api_error_mapper.dart';
import '../services/recipe_service.dart';
import '../services/response_cache_interceptor.dart';
import '../storage/app_database.dart';
import '../exceptions.dart';
import 'outbox_drainer.dart';

/// One page of the kitchen as [RecipeRepository.loadRecipesPage] returns it.
class RecipePage {
  final List<api.Recipe> recipes;

  /// Whether another page may exist. Always false for a page served from the
  /// local cache: offline there is nothing further to fetch.
  final bool hasMore;

  /// True when the server could not be reached and [recipes] came from the
  /// Drift cache instead.
  final bool fromCache;

  const RecipePage({
    required this.recipes,
    required this.hasMore,
    this.fromCache = false,
  });
}

/// Queued recipe ops, decoded once per read so the overlays below agree on
/// what is still pending.
class _PendingRecipes {
  /// Temp id → the queued create request, oldest first.
  final Map<String, Map<String, dynamic>> creates;

  /// Ids with a queued delete.
  final Set<String> deleted;

  /// Ids with any queued op. Their local row is newer than the server's.
  final Set<String> touched;

  const _PendingRecipes(this.creates, this.deleted, this.touched);
}

class RecipeRepository {
  final AppDatabase _db;
  final RecipeService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [_afterLocalWrite].
  final void Function()? _onLocalWrite;

  bool _isDraining = false;

  static const recipeOpTypes = ['createRecipe', 'updateRecipe', 'deleteRecipe'];

  /// Cookbook (collection) ops. They share the recipe drain pass so a
  /// cookbook filing that names a recipe created offline sees its server id:
  /// the create's [AppDatabase.rewriteOutboxPayloadIds] lands first.
  static const collectionOpTypes = [
    'createCollection',
    'updateCollection',
    'deleteCollection',
    'addRecipeToCollection',
    'removeRecipeFromCollection',
  ];

  /// Prefix of a cookbook that exists only on this device so far.
  static const localCollectionPrefix = 'local-';

  /// Temp id → server id for recipes and cookbooks whose create synced this
  /// session. A screen opened on the temp id (the detail page of a recipe
  /// made offline) keeps that id after the sync replaced the row; every read
  /// and write here resolves through these first. Static because the
  /// repository is rebuilt with its provider, while the screens outlive that.
  static final Map<String, String> _syncedRecipeIds = {};
  static final Map<String, String> _syncedCollectionIds = {};

  /// The id [recipeId] now has on the server, if its create has synced.
  String resolveRecipeId(String recipeId) =>
      _syncedRecipeIds[recipeId] ?? recipeId;

  /// The id [collectionId] now has on the server, if its create has synced.
  String resolveCollectionId(String collectionId) =>
      _syncedCollectionIds[collectionId] ?? collectionId;

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

  /// Writes server recipes into the cache, except ones with a queued local
  /// change: their row holds the user's unsynced edit, which a server copy
  /// fetched before the drain must not overwrite.
  Future<void> cacheRecipes(Iterable<api.Recipe> recipes) async {
    await _cacheSkippingPending(recipes, await _pending());
  }

  Future<int> refreshRecipes({int limit = 50, int offset = 0}) async {
    // Live only: this persists what it gets, and a stale cached body would
    // write old copies over newer rows.
    final remote = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listRecipes(limit: limit, offset: offset));
    await cacheRecipes(remote);
    return remote.length;
  }

  // ---------------------------------------------------------------------------
  // Reads with offline fallback
  // ---------------------------------------------------------------------------

  /// One page of the kitchen: the server's answer with this device's queued
  /// changes laid over it, or the cache when the server cannot be reached.
  ///
  /// The server page alone misses a recipe created offline (it has not synced
  /// yet) and still lists one deleted offline, so both are reconciled here
  /// rather than in every screen. Offline, page one comes from the cache —
  /// filtered the way the server would have — and a later page rethrows, since
  /// the cache has no notion of the server's paging.
  Future<RecipePage> loadRecipesPage({
    int limit = 50,
    int offset = 0,
    String? groupId,
    List<String> tags = const [],
  }) async {
    try {
      // Live only, since the answer is persisted; offline the Drift copy
      // below is the fallback, kept current by every live answer.
      final remote = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listRecipes(
          limit: limit,
          offset: offset,
          groupId: groupId,
          tags: tags,
        ),
      );
      final pending = await _pending();
      await _cacheSkippingPending(remote, pending);

      final merged = <api.Recipe>[];
      if (offset == 0) {
        // Newest first, matching where the server will put them once synced.
        for (final tempId in pending.creates.keys.toList().reversed) {
          if (remote.any((r) => r.id == tempId)) continue;
          final local = await loadRecipeLocal(tempId);
          if (local != null && _visible(local, groupId, tags)) {
            merged.add(local);
          }
        }
      }
      for (final r in remote) {
        if (pending.deleted.contains(r.id)) continue;
        if (pending.touched.contains(r.id)) {
          final local = await getRecipeOnce(r.id);
          merged.add(local == null ? r : _withLocalFields(r, local));
        } else {
          merged.add(r);
        }
      }
      return RecipePage(recipes: merged, hasMore: remote.length == limit);
    } catch (_) {
      if (offset > 0) rethrow;
      final pending = await _pending();
      final all = await getRecipesOnce();
      // Never fetched and nothing made here: an error, not an empty kitchen.
      // (A tag filter matching none of the cache is an ordinary empty page.)
      if (all.isEmpty) rethrow;
      final cached = <api.Recipe>[];
      for (final r in all) {
        if (pending.deleted.contains(r.id) || !_visible(r, groupId, tags)) {
          continue;
        }
        cached.add(pending.creates.containsKey(r.id)
            ? (await loadRecipeLocal(r.id) ?? r)
            : r);
      }
      return RecipePage(recipes: cached, hasMore: false, fromCache: true);
    }
  }

  /// A recipe for the detail and cook screens: the server's copy when it can
  /// be had, the local one when the recipe was created offline (the server
  /// has never heard of it) or the network is gone.
  Future<api.Recipe> loadRecipe(String recipeId) async {
    recipeId = resolveRecipeId(recipeId);
    final pending = await _pending();
    if (pending.deleted.contains(recipeId)) {
      throw const NotFoundException('Recipe not found');
    }
    if (pending.creates.containsKey(recipeId)) {
      final local = await loadRecipeLocal(recipeId);
      if (local != null) return local;
    }
    try {
      // Not persisted: this may be the response cache's copy, which is fine
      // to show (it has the detail fields the Drift row lacks) but must not
      // overwrite a newer row.
      final remote = await _remote.getRecipe(recipeId);
      if (pending.touched.contains(recipeId)) {
        final local = await getRecipeOnce(recipeId);
        if (local != null) return _withLocalFields(remote, local);
      }
      return remote;
    } catch (_) {
      final local = await getRecipeOnce(recipeId);
      if (local != null) return local;
      rethrow;
    }
  }

  /// The cached recipe, enriched from its queued create request when it was
  /// made offline (the cache table has no column for the clipped metadata).
  Future<api.Recipe?> loadRecipeLocal(String recipeId) async {
    recipeId = resolveRecipeId(recipeId);
    final row = await getRecipeOnce(recipeId);
    final request = await _pendingCreateRequest(recipeId);
    if (request == null) return row;
    final now = DateTime.now();
    try {
      return api.Recipe.fromJson({
        ...request,
        'id': recipeId,
        'created_at': (row?.createdAt ?? now).toIso8601String(),
        'updated_at': (row?.updatedAt ?? now).toIso8601String(),
      });
    } catch (_) {
      return row;
    }
  }

  /// Ingredients for [recipeId]. A recipe created offline answers from its
  /// queued request; anything else goes to the server, whose GET the response
  /// cache answers offline when it was seen before.
  Future<List<api.RecipeIngredient>> loadIngredients(String recipeId) async {
    recipeId = resolveRecipeId(recipeId);
    final request = await _pendingCreateRequest(recipeId);
    if (request != null) {
      final raw = request['ingredients'];
      if (raw is! List) return const [];
      final out = <api.RecipeIngredient>[];
      for (var i = 0; i < raw.length; i++) {
        final ing = raw[i];
        if (ing is! Map) continue;
        out.add(api.RecipeIngredient.fromJson({
          'id': '$recipeId-ingredient-$i',
          'recipe_id': recipeId,
          'name': ing['name'] ?? '',
          'quantity': ing['quantity'],
          'unit': ing['unit'] ?? '',
          'raw_text': ing['raw_text'] ?? '',
          'position': i,
        }));
      }
      return out;
    }
    return _remote.getRecipeIngredients(recipeId);
  }

  /// Steps for [recipeId]; same sourcing as [loadIngredients].
  Future<List<api.RecipeStep>> loadSteps(String recipeId) async {
    recipeId = resolveRecipeId(recipeId);
    final request = await _pendingCreateRequest(recipeId);
    if (request != null) {
      final raw = request['steps'];
      if (raw is! List) return const [];
      final out = <api.RecipeStep>[];
      for (var i = 0; i < raw.length; i++) {
        final step = raw[i];
        if (step is! Map) continue;
        out.add(api.RecipeStep(
          id: '$recipeId-step-$i',
          recipeId: recipeId,
          name: step['name'] as String? ?? '',
          description: step['description'] as String? ?? '',
          position: i,
        ));
      }
      return out;
    }
    return _remote.getRecipeSteps(recipeId);
  }

  /// Whether [recipeId] was created on this device and has not synced yet.
  /// Server-side actions on it (share links, server-side list adds) cannot
  /// work until it has.
  Future<bool> isPendingCreate(String recipeId) async =>
      (await _pendingCreateRequest(resolveRecipeId(recipeId))) != null;

  // ---------------------------------------------------------------------------
  // Recipe writes
  // ---------------------------------------------------------------------------

  Future<api.Recipe> createRecipeOfflineFirst(
      api.CreateRecipeRequest req) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();
    final local = api.Recipe(
      id: tempId,
      title: req.title,
      description: req.description,
      descriptionShort: req.descriptionShort,
      author: req.author,
      ratingValue: req.ratingValue,
      ratingCount: req.ratingCount,
      videoUrl: req.videoUrl,
      sourceUrl: req.sourceUrl,
      prepTime: req.prepTime,
      cookTime: req.cookTime,
      servings: req.servings,
      imageUrl: req.imageUrl,
      imageOptions: req.imageOptions,
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
        // The full request — ingredients, steps, clipped metadata — is what
        // the drain replays; the cache row only holds the list-card subset.
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
    recipeId = resolveRecipeId(recipeId);
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
    recipeId = resolveRecipeId(recipeId);
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

  // ---------------------------------------------------------------------------
  // Cookbooks (collections)
  //
  // There is no cookbook table, and the schema is frozen, so cookbooks keep
  // reading through the service (the response cache answers those GETs
  // offline) and queued changes are laid over whatever comes back. An op
  // drops out of the overlay exactly when it syncs, which is when the server
  // starts reporting the change itself.
  // ---------------------------------------------------------------------------

  static bool isLocalCollectionId(String id) =>
      id.startsWith(localCollectionPrefix);

  Future<List<api.RecipeCollection>> loadCollections({
    int limit = 100,
    String? groupId,
  }) async {
    List<api.RecipeCollection> base;
    try {
      base = await _remote.listCollections(limit: limit, groupId: groupId);
    } catch (_) {
      final overlaid = await _overlayCollections(const [], groupId: groupId);
      if (overlaid.isEmpty) rethrow;
      return overlaid;
    }
    return _overlayCollections(base, groupId: groupId);
  }

  /// One cookbook's header. A cookbook made offline answers from its op.
  Future<api.RecipeCollection> loadCollection(String collectionId) async {
    collectionId = resolveCollectionId(collectionId);
    if (isLocalCollectionId(collectionId)) {
      final overlaid = await _overlayCollections(const [], allGroups: true);
      return overlaid.firstWhere(
        (c) => c.id == collectionId,
        orElse: () => throw const NotFoundException('Cookbook not found'),
      );
    }
    final remote = await _remote.getCollection(collectionId);
    final overlaid = await _overlayCollections([remote], allGroups: true);
    return overlaid.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => throw const NotFoundException('Cookbook not found'),
    );
  }

  Future<List<api.Recipe>> loadCollectionRecipes(String collectionId,
      {int limit = 200}) async {
    collectionId = resolveCollectionId(collectionId);
    final base = isLocalCollectionId(collectionId)
        ? const <api.Recipe>[]
        : await _remote.getCollectionRecipes(collectionId, limit: limit);
    final out = [...base];
    for (final op in await _opsOfTypes(const [
      'addRecipeToCollection',
      'removeRecipeFromCollection',
      'deleteRecipe',
    ])) {
      final payload = _decode(op.payloadJson);
      if (payload == null) continue;
      final recipeId = payload['recipeId'] as String?;
      if (recipeId == null) continue;
      if (op.type == 'deleteRecipe') {
        out.removeWhere((r) => r.id == recipeId);
        continue;
      }
      if (payload['collectionId'] != collectionId) continue;
      out.removeWhere((r) => r.id == recipeId);
      if (op.type == 'addRecipeToCollection') {
        final recipe = await loadRecipeLocal(recipeId) ??
            _recipeFromJson(payload['recipe']);
        if (recipe != null) out.insert(0, recipe);
      }
    }
    return out;
  }

  Future<api.RecipeCollection> createCollectionOfflineFirst(
      api.CreateCollectionRequest req) async {
    final localId = '$localCollectionPrefix${_uuid.v4()}';
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createCollection',
      payload: {
        'localId': localId,
        'name': req.name,
        'request': req.toJson(),
        'createdAt': now.toIso8601String(),
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: 'createCollection:$localId',
      entityType: 'cookbook',
      entityId: localId,
    );
    _afterLocalWrite();
    return api.RecipeCollection(
      id: localId,
      name: req.name,
      recipeCount: 0,
      groupId: req.groupId,
      createdAt: now,
    );
  }

  Future<void> updateCollectionOfflineFirst(
      String collectionId, api.UpdateCollectionRequest req) async {
    collectionId = resolveCollectionId(collectionId);
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'updateCollection',
      payload: {
        'collectionId': collectionId,
        if (req.name != null) 'name': req.name,
        'patch': req.toJson(),
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey:
          'updateCollection:$collectionId:${now.microsecondsSinceEpoch}',
      entityType: 'cookbook',
      entityId: collectionId,
    );
    _afterLocalWrite();
  }

  Future<void> deleteCollectionOfflineFirst(String collectionId) async {
    collectionId = resolveCollectionId(collectionId);
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'deleteCollection',
      payload: {
        'collectionId': collectionId,
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: 'deleteCollection:$collectionId',
      entityType: 'cookbook',
      entityId: collectionId,
    );
    _afterLocalWrite();
  }

  /// Files [recipeId] in a cookbook. [recipe] (or the cached row) is kept in
  /// the op so the cookbook can show it before the filing syncs.
  Future<void> addRecipeToCollectionOfflineFirst(
    String collectionId,
    String recipeId, {
    api.Recipe? recipe,
  }) async {
    collectionId = resolveCollectionId(collectionId);
    recipeId = resolveRecipeId(recipeId);
    final snapshot = recipe ?? await loadRecipeLocal(recipeId);
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'addRecipeToCollection',
      payload: {
        'collectionId': collectionId,
        'recipeId': recipeId,
        if (snapshot != null) 'title': snapshot.title,
        if (snapshot != null) 'recipe': snapshot.toJson(),
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: 'addRecipeToCollection:$collectionId:$recipeId:'
          '${now.microsecondsSinceEpoch}',
      entityType: 'cookbook',
      entityId: collectionId,
    );
    _afterLocalWrite();
  }

  Future<void> removeRecipeFromCollectionOfflineFirst(
      String collectionId, String recipeId) async {
    collectionId = resolveCollectionId(collectionId);
    recipeId = resolveRecipeId(recipeId);
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'removeRecipeFromCollection',
      payload: {
        'collectionId': collectionId,
        'recipeId': recipeId,
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: 'removeRecipeFromCollection:$collectionId:$recipeId:'
          '${now.microsecondsSinceEpoch}',
      entityType: 'cookbook',
      entityId: collectionId,
    );
    _afterLocalWrite();
  }

  /// Lays queued cookbook ops over [base]. [groupId] scopes which offline
  /// creates belong in a household's listing; [allGroups] skips that check
  /// for single-cookbook lookups.
  Future<List<api.RecipeCollection>> _overlayCollections(
    List<api.RecipeCollection> base, {
    String? groupId,
    bool allGroups = false,
  }) async {
    final out = [...base];
    for (final op in await _opsOfTypes(collectionOpTypes)) {
      final payload = _decode(op.payloadJson);
      if (payload == null) continue;
      switch (op.type) {
        case 'createCollection':
          final localId = payload['localId'] as String?;
          final request = payload['request'];
          if (localId == null || request is! Map) continue;
          if (out.any((c) => c.id == localId)) continue;
          final gid = request['group_id'] as String?;
          if (!allGroups && gid != null && gid != groupId) continue;
          out.add(api.RecipeCollection(
            id: localId,
            name: request['name'] as String? ?? '',
            recipeCount: 0,
            groupId: gid,
            createdAt:
                DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
                    op.createdAt,
          ));
        case 'updateCollection':
          final id = payload['collectionId'] as String?;
          final patch = payload['patch'];
          final i = out.indexWhere((c) => c.id == id);
          if (i < 0 || patch is! Map) continue;
          final c = out[i];
          out[i] = api.RecipeCollection(
            id: c.id,
            name: patch['name'] as String? ?? c.name,
            recipeCount: c.recipeCount,
            groupId: patch['make_private'] == true
                ? null
                : (patch['group_id'] as String? ?? c.groupId),
            createdAt: c.createdAt,
          );
        case 'deleteCollection':
          out.removeWhere((c) => c.id == payload['collectionId']);
        case 'addRecipeToCollection':
        case 'removeRecipeFromCollection':
          final i = out.indexWhere((c) => c.id == payload['collectionId']);
          if (i < 0) continue;
          final c = out[i];
          final count = c.recipeCount;
          if (count == null) continue;
          final next =
              op.type == 'addRecipeToCollection' ? count + 1 : count - 1;
          out[i] = api.RecipeCollection(
            id: c.id,
            name: c.name,
            recipeCount: next < 0 ? 0 : next,
            groupId: c.groupId,
            createdAt: c.createdAt,
          );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

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
        types: const [...recipeOpTypes, ...collectionOpTypes],
        handlers: {
          'createRecipe': (op, payload) =>
              _syncCreate(op.id, payload, op.idempotencyKey),
          'updateRecipe': (op, payload) =>
              _syncUpdate(op.id, payload, op.idempotencyKey),
          'deleteRecipe': (op, payload) =>
              _syncDelete(op.id, payload, op.idempotencyKey),
          'createCollection': (op, payload) async {
            final localId = payload['localId'] as String?;
            final request = payload['request'];
            if (localId == null || request is! Map) {
              await _db.deleteOutboxOp(op.id);
              return;
            }
            final created = await _remote.createCollectionRaw(
              request.cast<String, dynamic>(),
              idempotencyKey: op.idempotencyKey,
            );
            _syncedCollectionIds[localId] = created.id;
            await _db.rewriteOutboxPayloadIds(
                oldId: localId, newId: created.id);
            await _db.deleteOutboxOp(op.id);
          },
          'updateCollection': (op, payload) async {
            final id = payload['collectionId'] as String?;
            final patch = payload['patch'];
            if (id == null || patch is! Map) {
              await _db.deleteOutboxOp(op.id);
              return;
            }
            await _remote.updateCollectionRaw(id, patch.cast<String, dynamic>(),
                idempotencyKey: op.idempotencyKey);
            await _db.deleteOutboxOp(op.id);
          },
          'deleteCollection': (op, payload) async {
            final id = payload['collectionId'] as String?;
            if (id != null) {
              await _ignoringNotFound(() => _remote.deleteCollectionRaw(id,
                  idempotencyKey: op.idempotencyKey));
            }
            await _db.deleteOutboxOp(op.id);
          },
          'addRecipeToCollection': (op, payload) async {
            final id = payload['collectionId'] as String?;
            final recipeId = payload['recipeId'] as String?;
            if (id != null && recipeId != null) {
              await _remote.addRecipeToCollectionRaw(id, recipeId,
                  idempotencyKey: op.idempotencyKey);
            }
            await _db.deleteOutboxOp(op.id);
          },
          'removeRecipeFromCollection': (op, payload) async {
            final id = payload['collectionId'] as String?;
            final recipeId = payload['recipeId'] as String?;
            if (id != null && recipeId != null) {
              await _ignoringNotFound(() =>
                  _remote.removeRecipeFromCollectionRaw(id, recipeId,
                      idempotencyKey: op.idempotencyKey));
            }
            await _db.deleteOutboxOp(op.id);
          },
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

    // Replay the stored body verbatim. Rebuilding a request from a subset of
    // its fields silently dropped the ingredients and steps of every recipe
    // that went through the outbox.
    final created = await _remote.createRecipeRaw(
      requestRaw.cast<String, dynamic>(),
      idempotencyKey: idempotencyKey,
    );
    // Deleted again before it synced: the queued delete (rewritten to the
    // server id below) removes it server-side; do not resurrect the row.
    final deletedMeanwhile = (await _pending()).deleted.contains(tempId);
    await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(tempId)))
        .go();
    if (!deletedMeanwhile) await _db.upsertRecipesRows([_toRow(created)]);
    _syncedRecipeIds[tempId] = created.id;
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
    // Already gone (deleted from another device, or this op's first attempt
    // landed but its response did not) is the outcome we wanted.
    await _ignoringNotFound(
        () => _remote.deleteRecipe(recipeId, idempotencyKey: idempotencyKey));
    await (_db.delete(_db.recipesTable)..where((t) => t.id.equals(recipeId)))
        .go();
    await _db.deleteOutboxOp(opId);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _ignoringNotFound(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      final cause =
          e is ApiException ? e.cause : (e is DioException ? e : null);
      if (cause?.response?.statusCode != 404) rethrow;
    }
  }

  Future<void> _cacheSkippingPending(
      Iterable<api.Recipe> recipes, _PendingRecipes pending) async {
    final rows = [
      for (final r in recipes)
        if (!pending.touched.contains(r.id)) _toRow(r),
    ];
    if (rows.isEmpty) return;
    await _db.upsertRecipesRows(rows);
  }

  /// Queued ops of [types], oldest first. Ops queued within the same second
  /// share a `createdAt` (Drift stores whole seconds), so the payload's `seq`
  /// breaks the tie where present.
  Future<List<OutboxOp>> _opsOfTypes(List<String> types) async {
    final ops = <OutboxOp>[
      for (final type in types) ...await _db.getOutboxOpsByType(type),
    ];
    int seq(OutboxOp op) => (_decode(op.payloadJson)?['seq'] as int?) ?? 0;
    ops.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : seq(a).compareTo(seq(b));
    });
    return ops;
  }

  Future<_PendingRecipes> _pending() async {
    final creates = <String, Map<String, dynamic>>{};
    final deleted = <String>{};
    final touched = <String>{};
    for (final op in await _opsOfTypes(recipeOpTypes)) {
      final payload = _decode(op.payloadJson);
      if (payload == null) continue;
      // Payload ids, not the entity_id column: a sync rewrites the former to
      // the server id but leaves the column on the temp id.
      switch (op.type) {
        case 'createRecipe':
          final tempId = payload['tempId'] as String?;
          final request = payload['request'];
          if (tempId == null || request is! Map) continue;
          creates[tempId] = request.cast<String, dynamic>();
          touched.add(tempId);
        case 'updateRecipe':
          final id = payload['recipeId'] as String?;
          if (id != null) touched.add(id);
        case 'deleteRecipe':
          final id = payload['recipeId'] as String?;
          if (id == null) continue;
          deleted.add(id);
          touched.add(id);
      }
    }
    return _PendingRecipes(creates, deleted, touched);
  }

  Future<Map<String, dynamic>?> _pendingCreateRequest(String recipeId) async {
    for (final op in await _db.getOutboxOpsByType('createRecipe')) {
      final payload = _decode(op.payloadJson);
      if (payload?['tempId'] != recipeId) continue;
      final request = payload!['request'];
      if (request is Map) return request.cast<String, dynamic>();
    }
    return null;
  }

  static Map<String, dynamic>? _decode(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // Malformed ops are the drainer's problem, not the overlay's.
    }
    return null;
  }

  static api.Recipe? _recipeFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return api.Recipe.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// Whether the server would list [r] for this household and tag filter.
  /// Private recipes are the caller's own; a household recipe shows only in
  /// its own household.
  static bool _visible(api.Recipe r, String? groupId, List<String> tags) {
    if (groupId != null && r.groupId != null && r.groupId != groupId) {
      return false;
    }
    return tags.every(r.tags.contains);
  }

  /// [remote] with the fields the cache row can hold taken from [local],
  /// which carries a queued edit the server has not applied yet.
  static api.Recipe _withLocalFields(api.Recipe remote, api.Recipe local) {
    return api.Recipe(
      id: remote.id,
      title: local.title,
      description: local.description,
      descriptionShort: remote.descriptionShort,
      author: remote.author,
      ratingValue: remote.ratingValue,
      ratingCount: remote.ratingCount,
      nutritionJson: remote.nutritionJson,
      videoUrl: remote.videoUrl,
      equipmentJson: remote.equipmentJson,
      sourceUrl: remote.sourceUrl,
      prepTime: local.prepTime,
      cookTime: local.cookTime,
      servings: local.servings,
      imageUrl: local.imageUrl,
      imageOptions: remote.imageOptions,
      tags: local.tags,
      visibility: local.visibility,
      groupId: local.groupId,
      createdAt: remote.createdAt,
      updatedAt: local.updatedAt,
    );
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
