import 'dart:async';
import 'dart:convert';

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

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;

  PinwallRepository({
    required AppDatabase db,
    required PinwallService remote,
    Uuid? uuid,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid();

  /// Subscribe to the group's SSE stream so a flatmate pinning or removing a
  /// note repaints every open board. Events carry only an id; we reconcile
  /// against the server (refetch on create) or the cache (remove on delete),
  /// which fires the existing [watchPosts] Drift stream.
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService) return;
    _sseSub?.cancel();
    _sseService = sseService;
    sseService.connect(groupId);
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  /// Stop the active SSE subscription without closing the shared service.
  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
  }

  Future<void> _handleSseEvent(SseEvent event) async {
    switch (event.type) {
      case 'pinwall:post_created':
        // The event body is untrusted, so refetch the canonical list.
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

  Future<void> refreshPosts(String groupId,
      {int limit = 20, int offset = 0}) async {
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
    return tempId;
  }

  Future<void> deletePostOfflineFirst(String groupId, String postId) async {
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

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: const ['createPinwallPost', 'deletePinwallPost'],
      handlers: {
        'createPinwallPost': (op, payload) async {
          final remindRaw = payload['remindAt'] as String?;
          await _remote.createPost(
            payload['groupId'] as String,
            content: payload['content'] as String,
            remindAt: remindRaw != null ? DateTime.parse(remindRaw) : null,
          );
          await refreshPosts(payload['groupId'] as String);
          await _db.deleteOutboxOp(op.id);
        },
        'deletePinwallPost': (op, payload) async {
          await _remote.deletePost(
            payload['groupId'] as String,
            payload['postId'] as String,
          );
          await refreshPosts(payload['groupId'] as String);
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
