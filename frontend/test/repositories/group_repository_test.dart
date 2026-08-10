import 'dart:async';

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

    // Plan 006 part 2. Every screen's _resolveGroupId() awaits loadGroups, so
    // a blocking network read here stalls the entire app behind one request.
    group('cache-first resolve —', () {
      test('returns the cache without waiting on the network', () async {
        service.listResult = [_group('g1', 'Home')];
        await repo.loadGroups(); // seed the cache
        final callsAfterSeed = service.listCalls;

        // Network now hangs indefinitely — a blocking read would never return.
        final gate = Completer<List<Group>>();
        service.listOverride = () => gate.future;
        addTearDown(() => gate.complete(const []));

        final groups = await repo.loadGroups().timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw StateError('loadGroups blocked on network'),
            );

        expect(groups.map((g) => g.id), ['g1']);
        expect(service.listCalls, greaterThan(callsAfterSeed),
            reason: 'the background refresh still fires');
      });

      test('background refresh updates the cache for the next read', () async {
        service.listResult = [_group('g1', 'Home')];
        await repo.loadGroups();

        service.listResult = [_group('g1', 'Home'), _group('g2', 'Cabin')];
        await repo.loadGroups(); // returns stale, refreshes behind
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect((await repo.getGroupsOnce()).map((g) => g.id), ['g1', 'g2']);
      });

      test('forceRefresh blocks and returns the new household', () async {
        service.listResult = [_group('g1', 'Home')];
        await repo.loadGroups();

        // The join just happened; the cache cannot know about g2 yet.
        service.listResult = [_group('g1', 'Home'), _group('g2', 'Cabin')];
        final groups = await repo.loadGroups(forceRefresh: true);

        expect(groups.map((g) => g.id), ['g1', 'g2'],
            reason: 'a create/join flow must see the household it just made');
      });

      test('forceRefresh rethrows rather than returning a stale list',
          () async {
        service.listResult = [_group('g1', 'Home')];
        await repo.loadGroups();
        service.throwOnList = Exception('SocketException: offline');

        expect(repo.loadGroups(forceRefresh: true), throwsException,
            reason: '"you joined but we cannot confirm" must not read as '
                'success against the old list');
      });

      test('with no cache the network is awaited', () async {
        service.listResult = [_group('g1', 'Home')];

        expect((await repo.loadGroups()).map((g) => g.id), ['g1'],
            reason: 'nothing to be cache-first with on a cold install');
      });
    });
  });
}
