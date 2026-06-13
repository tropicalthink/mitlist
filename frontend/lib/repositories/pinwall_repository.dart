import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/pinwall_models.dart';
import '../services/pinwall_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

class PinwallRepository {
  final AppDatabase _db;
  final PinwallService _remote;
  final Uuid _uuid;

  PinwallRepository({
    required AppDatabase db,
    required PinwallService remote,
    Uuid? uuid,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid();

  Stream<List<PinwallPost>> watchPosts(String groupId) {
    return _db.watchPinwallPosts(groupId).map((row) => _decode(row?.postsJson));
  }

  Future<List<PinwallPost>> getPostsOnce(String groupId) async {
    final row = await _db.getPinwallPostsOnce(groupId);
    return _decode(row?.postsJson);
  }

  Future<void> refreshPosts(String groupId, {int limit = 20, int offset = 0}) async {
    final posts = await _remote.listPosts(groupId, limit: limit, offset: offset);
    await _db.upsertPinwallPosts(
      groupId: groupId,
      postsJson: jsonEncode(posts.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> createPostOfflineFirst(String groupId, {required String content}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createPinwallPost',
      payload: {'groupId': groupId, 'content': content},
      idempotencyKey: 'createPinwallPost:$groupId:${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> deletePostOfflineFirst(String groupId, String postId) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'deletePinwallPost',
      payload: {'groupId': groupId, 'postId': postId},
      idempotencyKey: 'deletePinwallPost:$postId',
    );
  }

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: const ['createPinwallPost', 'deletePinwallPost'],
      handlers: {
        'createPinwallPost': (op, payload) async {
          await _remote.createPost(
            payload['groupId'] as String,
            content: payload['content'] as String,
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

