import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
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

    test('updatePosition for an unsynced local post caches only, no outbox op',
        () async {
      final tempId = await repo.createPostOfflineFirst(groupId,
          content: 'temp', userId: 'u1');
      final beforeCount = await db.outboxCount(); // just the create op

      await repo.updatePostPositionOfflineFirst(groupId, tempId, 50.0, 60.0);

      final posts = await repo.getPostsOnce(groupId);
      expect(posts.single.posX, 50.0);
      expect(posts.single.posY, 60.0);
      // No sync op enqueued for a temp id — it can't target a server row yet.
      expect(await db.outboxCount(), beforeCount);
    });
  });
}
