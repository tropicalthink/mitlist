import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  group('PinwallRepository offline optimistic paths —', () {
    late AppDatabase db;
    late PinwallRepository repo;
    const groupId = 'g1';

    setUp(() {
      db = _memoryDb();
      repo = PinwallRepository(db: db, remote: FakePinwallService());
    });

    tearDown(() => db.close());

    test('create inserts a synthetic pending post into the cache', () async {
      final tempId = await repo.createPostOfflineFirst(
        groupId,
        content: 'Buy milk',
        userId: 'u1',
      );

      expect(tempId, startsWith('local-'));
      final posts = await repo.getPostsOnce(groupId);
      expect(posts, hasLength(1));
      expect(posts.single.id, tempId);
      expect(posts.single.content, 'Buy milk');
      expect(posts.single.userId, 'u1');
      // Queued for the next drain.
      expect(await db.outboxCount(), greaterThan(0));
    });

    test('create prepends most-recent-first', () async {
      await repo.createPostOfflineFirst(groupId,
          content: 'first', userId: 'u1');
      final secondId = await repo.createPostOfflineFirst(groupId,
          content: 'second', userId: 'u1');

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.first.id, secondId);
      expect(posts.map((p) => p.content), ['second', 'first']);
    });

    test('delete removes the post from the cache immediately', () async {
      final id = await repo.createPostOfflineFirst(groupId,
          content: 'temp', userId: 'u1');
      expect(await repo.getPostsOnce(groupId), hasLength(1));

      await repo.deletePostOfflineFirst(groupId, id);

      expect(await repo.getPostsOnce(groupId), isEmpty);
    });

    test('updatePosition patches the cache and queues sync for a synced post',
        () async {
      // Seed a synced (server-id) post directly into the cache.
      final post = PinwallPost(
        id: 'server-1',
        groupId: groupId,
        userId: 'u1',
        content: 'note',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode([post.toJson()]),
      );

      await repo.updatePostPositionOfflineFirst(
          groupId, 'server-1', 120.0, 340.0);

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.posX, 120.0);
      expect(posts.single.posY, 340.0);
      expect(await db.outboxCount(), greaterThan(0));
    });

    test('updatePost patches content/color/size and queues sync', () async {
      final post = PinwallPost(
        id: 'server-1',
        groupId: groupId,
        userId: 'u1',
        content: 'old text',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode([post.toJson()]),
      );

      await repo.updatePostOfflineFirst(
        groupId,
        'server-1',
        content: 'new text',
        color: 'mint',
        size: 'large',
      );

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.content, 'new text');
      expect(posts.single.color, 'mint');
      expect(posts.single.size, 'large');
      expect(await db.outboxCount(), greaterThan(0));
    });

    test('updatePost with empty color/size clears the choice in the cache',
        () async {
      final post = PinwallPost(
        id: 'server-1',
        groupId: groupId,
        userId: 'u1',
        content: 'note',
        createdAt: DateTime.utc(2026, 1, 1),
        color: 'blush',
        size: 'small',
      );
      await db.upsertPinwallPosts(
        groupId: groupId,
        postsJson: jsonEncode([post.toJson()]),
      );

      await repo.updatePostOfflineFirst(
        groupId,
        'server-1',
        content: 'note',
        color: '',
        size: '',
      );

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.color, isNull);
      expect(posts.single.size, isNull);
    });

    test('updatePost for an unsynced local post queues against the temp id',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'temp', userId: 'u1');

      await repo.updatePostOfflineFirst(
        groupId,
        tempId,
        content: 'edited',
        color: 'sky',
        size: 'medium',
      );

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.content, 'edited');
      expect(posts.single.color, 'sky');
      // Queued against the temp id; the create's sync retargets it.
      final ops = await db.getOutboxOpsByType('updatePinwallPost');
      expect(ops.single.entityId, tempId);
    });

    test('updatePosition for an unsynced local post queues against the temp id',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'temp', userId: 'u1');

      await repo.updatePostPositionOfflineFirst(groupId, tempId, 50.0, 60.0);

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.posX, 50.0);
      expect(posts.single.posY, 60.0);
      final ops = await db.getOutboxOpsByType('updatePinwallPostPosition');
      expect(ops.single.entityId, tempId);
    });

    test('create carries a linked entity into the cache and the queued op',
        () async {
      final tempId = await repo.createPostOfflineFirst(
        groupId,
        content: 'see list',
        userId: 'u1',
        linkedEntityType: 'list',
        linkedEntityId: 'local-list-1',
      );

      final post = (await repo.getPostsOnce(groupId)).single;
      expect(post.id, tempId);
      expect(post.linkedEntityType, 'list');
      expect(post.linkedEntityId, 'local-list-1');
      final op = (await db.getOutboxOpsByType('createPinwallPost')).single;
      final payload = jsonDecode(op.payloadJson) as Map;
      expect(payload['linkedEntityType'], 'list');
      expect(payload['linkedEntityId'], 'local-list-1');
      // A list created offline earns its server id first; the global payload
      // rewrite then points the note at it.
      await db.rewriteOutboxPayloadIds(oldId: 'local-list-1', newId: 'list-9');
      final rewritten = jsonDecode(
          (await db.getOutboxOpsByType('createPinwallPost'))
              .single
              .payloadJson) as Map;
      expect(rewritten['linkedEntityId'], 'list-9');
    });

    test('deleting an unsynced post drops its queued ops, sends nothing',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'oops', userId: 'u1');
      await repo.updatePostOfflineFirst(groupId, tempId,
          content: 'oops!', color: '', size: '');
      await repo.updatePostPositionOfflineFirst(groupId, tempId, 1, 2);

      await repo.deletePostOfflineFirst(groupId, tempId);

      expect(await repo.getPostsOnce(groupId), isEmpty);
      expect(await db.outboxCount(), 0);
    });
  });

  group('PinwallRepository refresh keeps queued writes —', () {
    late AppDatabase db;
    late _RecordingPinwallService remote;
    late PinwallRepository repo;
    const groupId = '11111111-1111-1111-1111-111111111111';

    setUp(() {
      db = _memoryDb();
      remote = _RecordingPinwallService();
      // An injected onLocalWrite keeps writes queued until the test drains.
      repo = PinwallRepository(db: db, remote: remote, onLocalWrite: () {});
    });

    tearDown(() => db.close());

    test('a refresh re-applies pending creates, deletes, edits and moves',
        () async {
      remote.posts = [
        _post('s1', groupId, 'keep me'),
        _post('s2', groupId, 'delete me'),
      ];
      await repo.refreshPosts(groupId);

      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'offline note', userId: 'u1');
      await repo.deletePostOfflineFirst(groupId, 's2');
      await repo.updatePostOfflineFirst(groupId, 's1',
          content: 'edited', color: 'mint', size: '');
      await repo.updatePostPositionOfflineFirst(groupId, 's1', 10, 20);

      // The server has not seen any of it yet.
      await repo.refreshPosts(groupId);

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.map((p) => p.id), [tempId, 's1']);
      final s1 = posts.firstWhere((p) => p.id == 's1');
      expect(s1.content, 'edited');
      expect(s1.color, 'mint');
      expect(s1.posX, 10);
      expect(s1.posY, 20);
    });

    test('a temp post whose create was discarded disappears on refresh',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'doomed', userId: 'u1');
      final create = (await db.getOutboxOpsByType('createPinwallPost')).single;
      await db.deleteOutboxOp(create.id);

      await repo.refreshPosts(groupId);

      expect((await repo.getPostsOnce(groupId)).map((p) => p.id),
          isNot(contains(tempId)));
    });

    test('a synced create retargets queued edits and moves at the server id',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'draft', userId: 'u1');
      await repo.updatePostOfflineFirst(groupId, tempId,
          content: 'final', color: 'sky', size: 'large');
      await repo.updatePostPositionOfflineFirst(groupId, tempId, 30, 40);
      remote.createdId = 'server-7';

      await repo.drainOutboxOnce();

      expect(remote.created.single['content'], 'draft');
      expect(remote.updates.single, ('server-7', 'final', 'sky', 'large'));
      expect(remote.moves.single, ('server-7', 30.0, 40.0));
      expect(await db.outboxCount(), 0);
      final post = (await repo.getPostsOnce(groupId)).single;
      expect(post.id, 'server-7');
    });

    test('an edit of a pending note waits for its create, spending nothing',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'draft', userId: 'u1');
      await repo.updatePostOfflineFirst(groupId, tempId,
          content: 'final', color: '', size: '');
      remote.failCreate = true;

      await repo.drainOutboxOnce();

      expect(remote.updates, isEmpty);
      final update = (await db.getOutboxOpsByType('updatePinwallPost')).single;
      expect(update.attemptCount, 0);
    });

    test(
        'a note deleted while its create was in flight is deleted on the '
        'server too', () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'gone soon', userId: 'u1');
      remote.createdId = 'server-8';
      remote.onCreate = () => repo.deletePostOfflineFirst(groupId, tempId);

      await repo.drainOutboxOnce();

      final deletes = await db.getOutboxOpsByType('deletePinwallPost');
      expect(deletes, hasLength(1));
      expect(jsonDecode(deletes.single.payloadJson)['postId'], 'server-8');
      expect(await repo.getPostsOnce(groupId), isEmpty);
    });

    test('deleting a note that is already gone on the server completes',
        () async {
      remote.posts = [_post('s1', groupId, 'note')];
      await repo.refreshPosts(groupId);
      await repo.deletePostOfflineFirst(groupId, 's1');
      remote.deleteStatus = 404;

      await repo.drainOutboxOnce();

      expect(await db.outboxCount(), 0);
    });
  });
}

PinwallPost _post(String id, String groupId, String content) => PinwallPost(
      id: id,
      groupId: groupId,
      userId: 'u2',
      content: content,
      createdAt: DateTime.utc(2026, 1, 1),
    );

class _RecordingPinwallService implements PinwallService {
  List<PinwallPost> posts = [];
  String createdId = 'server-1';
  bool failCreate = false;
  int? deleteStatus;
  Future<void> Function()? onCreate;
  final created = <Map<String, Object?>>[];
  final updates = <(String, String?, String?, String?)>[];
  final moves = <(String, double, double)>[];

  @override
  Future<List<PinwallPost>> listPosts(String groupId,
          {int limit = 50, int offset = 0}) async =>
      List.of(posts);

  @override
  Future<PinwallPost> createPost(
    String groupId, {
    required String content,
    DateTime? remindAt,
    String? linkedEntityType,
    String? linkedEntityId,
    String? idempotencyKey,
  }) async {
    if (failCreate) {
      throw DioException(
        requestOptions: RequestOptions(path: '/pinwall/posts'),
        type: DioExceptionType.connectionError,
      );
    }
    await onCreate?.call();
    created.add({'content': content, 'linkedEntityId': linkedEntityId});
    final post = PinwallPost(
      id: createdId,
      groupId: groupId,
      userId: 'u1',
      content: content,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    posts = [post, ...posts];
    return post;
  }

  @override
  Future<PinwallPost> updatePost(
    String groupId,
    String postId, {
    String? content,
    String? color,
    String? size,
    String? idempotencyKey,
  }) async {
    updates.add((postId, content, color, size));
    return posts.firstWhere((p) => p.id == postId);
  }

  @override
  Future<PinwallPost> updatePostPosition(
    String groupId,
    String postId, {
    required double x,
    required double y,
    String? idempotencyKey,
  }) async {
    moves.add((postId, x, y));
    return posts.firstWhere((p) => p.id == postId);
  }

  @override
  Future<void> deletePost(String groupId, String postId,
      {String? idempotencyKey}) async {
    final status = deleteStatus;
    if (status != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/pinwall/posts/$postId'),
        response: Response(
          requestOptions: RequestOptions(path: '/pinwall/posts/$postId'),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    posts = posts.where((p) => p.id != postId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
