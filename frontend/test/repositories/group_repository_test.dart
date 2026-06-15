import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/repositories/group_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Group _group(String id, String name) => Group(
      id: id,
      name: name,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('GroupRepository —', () {
    late AppDatabase db;
    late FakeGroupService service;
    late GroupRepository repo;

    setUp(() {
      db = _memoryDb();
      service = FakeGroupService();
      repo = GroupRepository(db: db, groups: service);
    });

    tearDown(() => db.close());

    test('loadGroups caches the network result to Drift', () async {
      service.listResult = [_group('g1', 'Home'), _group('g2', 'Lake House')];

      final result = await repo.loadGroups();

      expect(result.map((g) => g.id), ['g1', 'g2']);
      // Persisted for offline reads.
      final cached = await repo.getGroupsOnce();
      expect(cached.map((g) => g.id), ['g1', 'g2']);
    });

    test('loadGroups returns cache (no throw) when offline with a prior cache',
        () async {
      // First, an online load populates the cache.
      service.listResult = [_group('g1', 'Home')];
      await repo.loadGroups();

      // Now go offline.
      service.throwOnList = Exception('SocketException: offline');
      final result = await repo.loadGroups();

      expect(result.map((g) => g.id), ['g1']);
      expect(service.listCalls, 2);
    });

    test('loadGroups rethrows when offline and nothing is cached', () async {
      service.throwOnList = Exception('SocketException: offline');

      expect(repo.loadGroups(), throwsException);
    });

    test('watchGroups emits cache updates', () async {
      service.listResult = [_group('g1', 'Home')];

      final emissions = <List<Group>>[];
      final sub = repo.watchGroups().listen(emissions.add);
      addTearDown(sub.cancel);

      await repo.loadGroups();
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((g) => g.id), ['g1']);
    });
  });
}
