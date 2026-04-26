import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/pinwall_models.dart';
import '../services/pinwall_service.dart';
import '../storage/app_database.dart';

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
    final opId = _uuid.v4();
    await _db.enqueueOutbox(
      id: opId,
      type: 'createPinwallPost',
      payload: {'groupId': groupId, 'content': content},
      idempotencyKey: 'createPinwallPost:$groupId:$opId',
    );
    try {
      await _remote.createPost(groupId, content: content);
      await refreshPosts(groupId);
      await _db.deleteOutboxOp(opId);
    } catch (_) {}
  }

  Future<void> deletePostOfflineFirst(String groupId, String postId) async {
    final opId = _uuid.v4();
    await _db.enqueueOutbox(
      id: opId,
      type: 'deletePinwallPost',
      payload: {'groupId': groupId, 'postId': postId},
      idempotencyKey: 'deletePinwallPost:$postId',
    );
    try {
      await _remote.deletePost(groupId, postId);
      await refreshPosts(groupId);
      await _db.deleteOutboxOp(opId);
    } catch (_) {}
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

