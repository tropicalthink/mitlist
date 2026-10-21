import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/pinwall_models.dart';
import '../services/pinwall_service.dart';
import '../services/response_cache_interceptor.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';
import 'outbox_error_classifier.dart' show kOutboxMaxAttempts;

class PinwallRepository {
  final AppDatabase _db;
  final PinwallService _remote;
  final Uuid _uuid;

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [noteLocalWrite].
  final void Function()? _onLocalWrite;

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;
  String? _sseGroupId;

  PinwallRepository({
    required AppDatabase db,
    required PinwallService remote,
    Uuid? uuid,
    void Function()? onLocalWrite,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _onLocalWrite = onLocalWrite;

  /// Subscribe to the group's SSE stream so a flatmate pinning or removing a
  /// note repaints every open board. Events carry only an id; we reconcile
  /// against the server (refetch on create) or the cache (remove on delete),
  /// which fires the existing [watchPosts] Drift stream.
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService && _sseGroupId == groupId) return;
    _sseSub?.cancel();
    _sseService = sseService;
    _sseGroupId = groupId;
    sseService.connect(groupId);
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  /// Stop the active SSE subscription without closing the shared service.
  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
    _sseGroupId = null;
  }

  Future<void> _handleSseEvent(SseEvent event) async {
    if (_sseGroupId == null || event.groupId != _sseGroupId) return;
    switch (event.type) {
      case 'pinwall:post_created':
      case 'pinwall:post_moved':
      case 'pinwall:post_updated':
        // The event body is untrusted, so refetch the canonical list — this
        // also carries the new positions so open boards reconcile a move.
        await refreshPosts(event.groupId).catchError((_) {});
      case 'pinwall:post_deleted':
        final id = event.payload['post_id'] as String?;
        if (id != null) {
          await _removeCachedPost(event.groupId, id);
        }
    }
  }

  Stream<List<PinwallPost>> watchPosts(String groupId) {
    return _db.watchPinwallPosts(groupId).map((row) => _decode(row?.postsJson));
  }

  Future<List<PinwallPost>> getPostsOnce(String groupId) async {
    final row = await _db.getPinwallPostsOnce(groupId);
    return _decode(row?.postsJson);
  }

  /// Returns a recently refreshed cache entry, or null when the caller should
  /// contact the server. Home uses this to share its aggregate response with
  /// the pinwall provider without immediately issuing the old duplicate GET.
  Future<List<PinwallPost>?> getFreshPosts(
    String groupId, {
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    final row = await _db.getPinwallPostsOnce(groupId);
    if (row == null || DateTime.now().difference(row.updatedAt) > maxAge) {
      return null;
    }
    return _decode(row.postsJson);
  }

  /// Replaces the cached post list for [groupId] with the server's.
  ///
  /// [limit] matches the server's own default. It must not be lowered per
  /// caller: the cache is a single shared blob, so a smaller refresh doesn't
  /// just fetch less — it overwrites the cache and drops every note past the
  /// limit for the board too.
  Future<void> refreshPosts(String groupId,
      {int limit = 50, int offset = 0}) async {
    // Live only (the service also marks the request): a stale offline body
    // would roll the board back. Offline the refresh fails and the cache
    // stands.
    final posts = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listPosts(groupId, limit: limit, offset: offset));
    final entries = await withPendingWrites(
      _db,
      groupId,
      [for (final p in posts) p.toJson()],
    );
    await _db.upsertPinwallPosts(
      groupId: groupId,
      postsJson: jsonEncode(entries),
    );
  }

  /// Every op type this repository queues, in no particular order.
  static const opTypes = [
    _createOp,
    _deleteOp,
    _updateOp,
    _positionOp,
  ];
  static const _createOp = 'createPinwallPost';
  static const _deleteOp = 'deletePinwallPost';
  static const _updateOp = 'updatePinwallPost';
  static const _positionOp = 'updatePinwallPostPosition';

  /// Re-applies still-queued pinwall writes onto a server snapshot of
  /// [groupId]'s posts, in the order they were made.
  ///
  /// The cache is one JSON blob, so every refresh (this repository's, the
  /// Home aggregate's, an SSE nudge from a flatmate) is a wholesale
  /// overwrite. Without this, a refresh that lands before the drain would
  /// erase a note pinned offline, resurrect one deleted offline and undo
  /// offline edits and moves, until the outbox finally caught up. Each step
  /// sets an absolute value, so running it over a cache that already shows
  /// the writes is a no-op; an op stops being re-applied exactly when it
  /// syncs and leaves the outbox.
  static Future<List<Map<String, dynamic>>> withPendingWrites(
    AppDatabase db,
    String groupId,
    List<Map<String, dynamic>> serverEntries,
  ) async {
    final ops = <OutboxOp>[
      for (final type in opTypes) ...await db.getOutboxOpsByType(type),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final queuedCreates = {
      for (final op in ops)
        if (op.type == _createOp && op.entityId != null) op.entityId!,
    };

    // A temp post whose create is gone (it was discarded after failing) is a
    // ghost the server will never have: drop it rather than keep it forever.
    final entries = [
      for (final e in serverEntries)
        if (!(e['id'] is String &&
            _isLocalId(e['id'] as String) &&
            !queuedCreates.contains(e['id'])))
          e,
    ];
    if (ops.isEmpty) return entries;
    void patch(String? postId, void Function(Map<String, dynamic> e) apply) {
      if (postId == null) return;
      for (final e in entries) {
        if (e['id'] == postId) apply(e);
      }
    }

    for (final op in ops) {
      final Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        continue; // A malformed op is the drainer's problem, not the cache's.
      }
      if (payload['groupId'] != groupId) continue;
      final postId = payload['postId'] as String?;
      switch (op.type) {
        case _createOp:
          final tempId = payload['tempId'] as String?;
          if (tempId == null || entries.any((e) => e['id'] == tempId)) {
            continue;
          }
          entries.insert(0, _pendingPost(op, payload, tempId).toJson());
        case _deleteOp:
          entries.removeWhere((e) => e['id'] == postId);
        case _updateOp:
          patch(postId, (e) {
            e['content'] = payload['content'];
            _setOrClear(e, 'color', payload['color'] as String?);
            _setOrClear(e, 'size', payload['size'] as String?);
          });
        case _positionOp:
          patch(postId, (e) {
            e['pos_x'] = payload['x'];
            e['pos_y'] = payload['y'];
          });
      }
    }
    return entries;
  }

  /// The synthetic post a queued create stands for. Ops queued by older
  /// builds carry neither author nor timestamp; the op's own time is the
  /// closest truth, and an empty author renders as "someone".
  static PinwallPost _pendingPost(
    OutboxOp op,
    Map<String, dynamic> payload,
    String tempId,
  ) {
    final remindRaw = payload['remindAt'] as String?;
    final createdRaw = payload['createdAt'] as String?;
    return PinwallPost(
      id: tempId,
      groupId: payload['groupId'] as String,
      userId: payload['userId'] as String? ?? '',
      content: payload['content'] as String? ?? '',
      createdAt: (createdRaw == null ? null : DateTime.tryParse(createdRaw)) ??
          op.createdAt,
      remindAt: remindRaw == null ? null : DateTime.tryParse(remindRaw),
      linkedEntityType: payload['linkedEntityType'] as String?,
      linkedEntityId: payload['linkedEntityId'] as String?,
    );
  }

  static void _setOrClear(Map<String, dynamic> e, String key, String? value) {
    if (value == null || value.isEmpty) {
      e.remove(key);
    } else {
      e[key] = value;
    }
  }

  /// Queues a post creation and inserts a synthetic "pending" post into the
  /// cache so it appears immediately offline. Text, reminder and a linked
  /// chore/list/expense all queue; media attachments require the network and
  /// are handled by the online path. When the create syncs, the temp post is
  /// swapped for the server's row and every op queued against the temp id
  /// (edits, moves) is retargeted at the server id. A linked entity that was
  /// itself created offline is retargeted the same way when it syncs first
  /// (the coordinator drains lists, money and chores before the pinwall).
  /// Returns the temporary local id.
  Future<String> createPostOfflineFirst(
    String groupId, {
    required String content,
    required String userId,
    DateTime? remindAt,
    String? linkedEntityType,
    String? linkedEntityId,
  }) async {
    final tempId = 'local-${_uuid.v4()}';
    final createdAt = DateTime.now();
    final hasLink = linkedEntityType != null &&
        linkedEntityId != null &&
        linkedEntityId.isNotEmpty;
    await _db.transaction(() async {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: _createOp,
        payload: {
          'groupId': groupId,
          'content': content,
          'tempId': tempId,
          'userId': userId,
          'createdAt': createdAt.toUtc().toIso8601String(),
          if (remindAt != null) 'remindAt': remindAt.toUtc().toIso8601String(),
          if (hasLink) 'linkedEntityType': linkedEntityType,
          if (hasLink) 'linkedEntityId': linkedEntityId,
        },
        idempotencyKey: '$_createOp:$groupId:$tempId',
        entityType: 'pinwallPost',
        entityId: tempId,
      );
      await _insertCachedPost(PinwallPost(
        id: tempId,
        groupId: groupId,
        userId: userId,
        content: content,
        createdAt: createdAt,
        remindAt: remindAt,
        linkedEntityType: hasLink ? linkedEntityType : null,
        linkedEntityId: hasLink ? linkedEntityId : null,
      ));
    });
    return tempId;
  }

  /// Removes a note now and queues the server delete.
  ///
  /// A note that never reached the server has nothing to delete there: its
  /// queued create, edits and moves are simply dropped, so a note pinned and
  /// unpinned on a plane never touches the network. Edits and moves still
  /// queued for a synced note are dropped too; they would only be sent to a
  /// note that is about to be gone.
  Future<void> deletePostOfflineFirst(String groupId, String postId) async {
    await _db.transaction(() async {
      await _db.deleteOutboxOpsByTypeAndEntity(_updateOp, postId);
      await _db.deleteOutboxOpsByTypeAndEntity(_positionOp, postId);
      if (_isLocalId(postId)) {
        await _db.deleteOutboxOpsByTypeAndEntity(_createOp, postId);
      } else {
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: _deleteOp,
          payload: {'groupId': groupId, 'postId': postId},
          idempotencyKey: '$_deleteOp:$postId',
          entityType: 'pinwallPost',
          entityId: postId,
        );
      }
      // Optimistic removal so the note disappears immediately offline.
      await _removeCachedPost(groupId, postId);
    });
  }

  static bool _isLocalId(String id) => id.startsWith('local-');

  /// Persists a note's placement on the shared cork board. Patches the cached
  /// blob so the move sticks immediately/offline, then queues the server sync
  /// (which broadcasts to other members via SSE). A move of a note that is
  /// still waiting for its create queues against the temp id and is
  /// retargeted at the server id when the create syncs.
  Future<void> updatePostPositionOfflineFirst(
    String groupId,
    String postId,
    double x,
    double y,
  ) async {
    await _db.transaction(() async {
      await _patchCachedPostPosition(groupId, postId, x, y);
      // Positions are last-write-wins, so only the newest queued move for this
      // note needs to reach the server.
      await _db.deleteOutboxOpsByTypeAndEntity(
          'updatePinwallPostPosition', postId);
      // The idempotency key must be unique per *move*, not per post: the
      // server remembers a key together with its body hash for 7 days and
      // answers a reused key with a different x/y with a plain 409.
      final opId = _uuid.v4();
      await _db.enqueueOutbox(
        id: opId,
        type: 'updatePinwallPostPosition',
        payload: {'groupId': groupId, 'postId': postId, 'x': x, 'y': y},
        idempotencyKey: 'updatePinwallPostPosition:$postId:$opId',
        entityType: 'pinwallPost',
        entityId: postId,
      );
    });
  }

  /// Edits a note's content and presentation (color/size). Patches the cached
  /// blob so the edit shows immediately/offline, then queues the server sync
  /// (which broadcasts pinwall:post_updated via SSE). Callers pass the full
  /// desired state — content plus color/size ('' clears a choice) — so a
  /// newer queued edit for the same note can simply replace an older one.
  /// Edits to a note still waiting for its create queue against the temp id
  /// and are retargeted at the server id when the create syncs, like moves.
  Future<void> updatePostOfflineFirst(
    String groupId,
    String postId, {
    required String content,
    required String color,
    required String size,
  }) async {
    await _db.transaction(() async {
      await _patchCachedPost(groupId, postId, (e) {
        e['content'] = content;
        if (color.isEmpty) {
          e.remove('color');
        } else {
          e['color'] = color;
        }
        if (size.isEmpty) {
          e.remove('size');
        } else {
          e['size'] = size;
        }
      });
      // The edit sheet always submits the complete state, so only the newest
      // queued edit for this note needs to reach the server.
      await _db.deleteOutboxOpsByTypeAndEntity('updatePinwallPost', postId);
      // Unique per *edit*, not per post: the server remembers a key with its
      // body hash for 7 days and answers a reused key with a new body as 409.
      final opId = _uuid.v4();
      await _db.enqueueOutbox(
        id: opId,
        type: 'updatePinwallPost',
        payload: {
          'groupId': groupId,
          'postId': postId,
          'content': content,
          'color': color,
          'size': size,
        },
        idempotencyKey: 'updatePinwallPost:$postId:$opId',
        entityType: 'pinwallPost',
        entityId: postId,
      );
    });
  }

  /// Applies [patch] to the cached JSON entry for [postId], best-effort.
  Future<void> _patchCachedPost(
    String groupId,
    String postId,
    void Function(Map<dynamic, dynamic> entry) patch,
  ) async {
    final row = await _db.getPinwallPostsOnce(groupId);
    final raw = row?.postsJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      var changed = false;
      for (final e in decoded) {
        if (e is Map && e['id'] == postId) {
          patch(e);
          changed = true;
          break;
        }
      }
      if (!changed) return;
      await _db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode(decoded),
      );
    } catch (_) {
      // Best-effort; a later refresh reconciles from the server.
    }
  }

  Future<void> _patchCachedPostPosition(
      String groupId, String postId, double x, double y) {
    return _patchCachedPost(groupId, postId, (e) {
      e['pos_x'] = x;
      e['pos_y'] = y;
    });
  }

  /// Prepends [post] to the cached posts blob (most-recent-first).
  Future<void> _insertCachedPost(PinwallPost post) async {
    final row = await _db.getPinwallPostsOnce(post.groupId);
    final raw = row?.postsJson;
    List<dynamic> list;
    if (raw == null || raw.isEmpty) {
      list = [];
    } else {
      final decoded = jsonDecode(raw);
      list = decoded is List ? decoded : [];
    }
    list.insert(0, post.toJson());
    await _db.upsertPinwallPosts(
      groupId: post.groupId,
      postsJson: jsonEncode(list),
    );
  }

  Future<void> _removeCachedPost(String groupId, String postId) async {
    final row = await _db.getPinwallPostsOnce(groupId);
    final raw = row?.postsJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      decoded.removeWhere((e) => e is Map && e['id'] == postId);
      await _db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode(decoded),
      );
    } catch (_) {
      // Best-effort; the drain + refresh reconciles.
    }
  }

  /// Tells the sync session that a pinwall write queued an op. The board,
  /// composer and editor call this after an `*OfflineFirst` write (the writes
  /// themselves stay side-effect free so callers pick the moment). Production
  /// passes [_onLocalWrite], which only opens the session; without it (tests,
  /// direct constructions) the op drains right away.
  void noteLocalWrite() {
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce().catchError((_) {}));
    }
  }

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: opTypes,
      handlers: {
        _createOp: (op, payload) async {
          final groupId = payload['groupId'] as String;
          final tempId = payload['tempId'] as String?;
          final remindRaw = payload['remindAt'] as String?;
          final created = await _remote.createPost(
            groupId,
            content: payload['content'] as String,
            remindAt: remindRaw != null ? DateTime.parse(remindRaw) : null,
            linkedEntityType: payload['linkedEntityType'] as String?,
            linkedEntityId: payload['linkedEntityId'] as String?,
            idempotencyKey: op.idempotencyKey,
          );
          await _onCreateSynced(op, groupId, tempId, created);
          // Best-effort: the cache already holds the server's row.
          await refreshPosts(groupId).catchError((_) {});
        },
        _deleteOp: (op, payload) async {
          final groupId = payload['groupId'] as String;
          try {
            await _remote.deletePost(
              groupId,
              payload['postId'] as String,
              idempotencyKey: op.idempotencyKey,
            );
          } on DioException catch (e) {
            // Already gone (a flatmate deleted it first): the goal is met.
            if (e.response?.statusCode != 404) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
          await refreshPosts(groupId).catchError((_) {});
        },
        _updateOp: (op, payload) async {
          if (await _waitsForCreate(op, payload)) return;
          // The cache already holds the edited note; no refetch needed on the
          // origin device. Other members reconcile via pinwall:post_updated.
          try {
            await _remote.updatePost(
              payload['groupId'] as String,
              payload['postId'] as String,
              content: payload['content'] as String,
              color: payload['color'] as String? ?? '',
              size: payload['size'] as String? ?? '',
              idempotencyKey: op.idempotencyKey,
            );
          } on DioException catch (e) {
            // Edits are last-write-wins; a 409 means an idempotency-key clash,
            // not a conflict to resolve. Drop the op and let refresh/SSE
            // reconcile rather than dead-lettering it.
            if (e.response?.statusCode != 409) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
        },
        _positionOp: (op, payload) async {
          if (await _waitsForCreate(op, payload)) return;
          // The cache already holds the new position; no refetch needed on the
          // origin device. Other members reconcile via the pinwall:post_moved
          // SSE broadcast the server emits.
          try {
            await _remote.updatePostPosition(
              payload['groupId'] as String,
              payload['postId'] as String,
              x: (payload['x'] as num).toDouble(),
              y: (payload['y'] as num).toDouble(),
              idempotencyKey: op.idempotencyKey,
            );
          } on DioException catch (e) {
            // Ops queued by older builds reused one idempotency key per post,
            // which the server answers with a bare 409 on the next move.
            // Position is last-write-wins, so drop the move instead of
            // dead-lettering it and let refresh/SSE reconcile.
            if (e.response?.statusCode != 409) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
        },
      },
    );
  }

  /// Bookkeeping once the server accepted a queued create: ops still queued
  /// against the temp id (edits, moves) now target the server id, and the
  /// cached temp post becomes the server's row with those edits on top.
  ///
  /// When the op is gone by now, the user deleted the pending note while
  /// the request was in flight: the server copy is deleted in turn instead
  /// of resurfacing a note the user already threw away.
  Future<void> _onCreateSynced(
    OutboxOp op,
    String groupId,
    String? tempId,
    PinwallPost created,
  ) async {
    await _db.transaction(() async {
      final stillWanted = await _db.getOutboxOpById(op.id) != null;
      await _db.deleteOutboxOp(op.id);
      if (tempId != null) {
        await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
        await _db.rewriteOutboxEntityIds(oldId: tempId, newId: created.id);
      }
      if (!stillWanted) {
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: _deleteOp,
          payload: {'groupId': groupId, 'postId': created.id},
          idempotencyKey: '$_deleteOp:${created.id}',
          entityType: 'pinwallPost',
          entityId: created.id,
        );
        await _removeCachedPost(groupId, created.id);
        return;
      }
      final row = await _db.getPinwallPostsOnce(groupId);
      final current = _decodeEntries(row?.postsJson);
      final index = current.indexWhere((e) => e['id'] == tempId);
      final serverEntry = created.toJson();
      if (index >= 0) {
        current[index] = serverEntry;
      } else if (!current.any((e) => e['id'] == created.id)) {
        current.insert(0, serverEntry);
      }
      await _db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode(await withPendingWrites(_db, groupId, current)),
      );
    });
  }

  /// Whether an edit or move targets a note whose create has not synced yet.
  /// It stays queued (without spending an attempt) until the create lands
  /// and retargets it. When the create failed for good, the op is parked
  /// with it, so "Retry" re-sends both in order; with no create left at all
  /// (it was discarded), the op can never be sent and is dropped.
  Future<bool> _waitsForCreate(
    OutboxOp op,
    Map<String, dynamic> payload,
  ) async {
    final postId = payload['postId'] as String?;
    if (postId == null || !_isLocalId(postId)) return false;
    final creates = (await _db.getOutboxOpsByType(_createOp))
        .where((c) => c.entityId == postId)
        .toList();
    if (creates.isEmpty) {
      await _db.deleteOutboxOp(op.id);
    } else if (creates.every((c) => c.attemptCount >= kOutboxMaxAttempts)) {
      await _db.markOutboxPermanentFailure(
        op.id,
        error: creates.first.lastError,
        threshold: kOutboxMaxAttempts,
      );
    }
    return true;
  }

  static List<Map<String, dynamic>> _decodeEntries(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) e.cast<String, dynamic>(),
      ];
    } catch (_) {
      return [];
    }
  }

  List<PinwallPost> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => PinwallPost.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
