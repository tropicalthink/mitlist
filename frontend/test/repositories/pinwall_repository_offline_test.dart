import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

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
      await repo.createPostOfflineFirst(groupId, content: 'first', userId: 'u1');
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
  });
}
