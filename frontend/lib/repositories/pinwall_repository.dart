import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/pinwall_models.dart';
import '../services/pinwall_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

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
    final posts =
        await _remote.listPosts(groupId, limit: limit, offset: offset);
    await _db.upsertPinwallPosts(
      groupId: groupId,
      postsJson: jsonEncode(posts.map((p) => p.toJson()).toList()),
    );
  }

  /// Queues a post creation and inserts a synthetic "pending" post into the
  /// cache so it appears immediately offline. Text-only — media attachments
  /// require the network and are handled by the online path. The post-drain
  /// [refreshPosts] replaces the temp post with the server's canonical row.
  /// Returns the temporary local id.
  Future<String> createPostOfflineFirst(
    String groupId, {
    required String content,
    required String userId,
    DateTime? remindAt,
  }) async {
    final tempId = 'local-${_uuid.v4()}';
    await _db.transaction(() async {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'createPinwallPost',
        payload: {
          'groupId': groupId,
          'content': content,
          'tempId': tempId,
          if (remindAt != null) 'remindAt': remindAt.toUtc().toIso8601String(),
        },
        idempotencyKey: 'createPinwallPost:$groupId:$tempId',
        entityType: 'pinwallPost',
        entityId: tempId,
      );
      await _insertCachedPost(PinwallPost(
        id: tempId,
        groupId: groupId,
        userId: userId,
        content: content,
        createdAt: DateTime.now(),
        remindAt: remindAt,
      ));
    });
    return tempId;
  }

  Future<void> deletePostOfflineFirst(String groupId, String postId) async {
    await _db.transaction(() async {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deletePinwallPost',
        payload: {'groupId': groupId, 'postId': postId},
        idempotencyKey: 'deletePinwallPost:$postId',
        entityType: 'pinwallPost',
        entityId: postId,
      );
      // Optimistic removal so the note disappears immediately offline.
      await _removeCachedPost(groupId, postId);
    });
  }

  /// Persists a note's placement on the shared cork board. Patches the cached
  /// blob so the move sticks immediately/offline, then queues the server sync
  /// (which broadcasts to other members via SSE). Positions for not-yet-synced
  /// local posts are cached only — they can't sync until the create resolves
  /// and the note earns a server id; the user can nudge it again after.
  Future<void> updatePostPositionOfflineFirst(
    String groupId,
    String postId,
    double x,
    double y,
  ) async {
    await _db.transaction(() async {
      await _patchCachedPostPosition(groupId, postId, x, y);
      if (postId.startsWith('local-')) return;
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
  /// Edits to not-yet-synced local posts are cached only, like positions:
  /// they can't sync until the create resolves and the note earns a server id.
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
      if (postId.startsWith('local-')) return;
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
      types: const [
        'createPinwallPost',
        'deletePinwallPost',
        'updatePinwallPost',
        'updatePinwallPostPosition',
      ],
      handlers: {
        'createPinwallPost': (op, payload) async {
          final remindRaw = payload['remindAt'] as String?;
          await _remote.createPost(
            payload['groupId'] as String,
            content: payload['content'] as String,
            remindAt: remindRaw != null ? DateTime.parse(remindRaw) : null,
            idempotencyKey: op.idempotencyKey,
          );
          await refreshPosts(payload['groupId'] as String);
          await _db.deleteOutboxOp(op.id);
        },
        'deletePinwallPost': (op, payload) async {
          await _remote.deletePost(
            payload['groupId'] as String,
            payload['postId'] as String,
            idempotencyKey: op.idempotencyKey,
          );
          await refreshPosts(payload['groupId'] as String);
          await _db.deleteOutboxOp(op.id);
        },
        'updatePinwallPost': (op, payload) async {
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
        'updatePinwallPostPosition': (op, payload) async {
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
