import 'dart:convert';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/services/api_error_mapper.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Seeds the current-chores cache with one chore that has a pending assignment.
Future<void> _seedChore(
  AppDatabase db,
  String groupId,
  String choreId, {
  required String status,
  String? dueDate,
  String dueStatus = 'overdue',
}) async {
  final blob = [
    {
      'chore': {'id': choreId, 'name': 'Dishes', 'is_active': true},
      'pending_assignment': {
        'id': 'a1',
        'chore_id': choreId,
        'status': status,
        'due_date': dueDate,
      },
      'due_status': dueStatus,
    }
  ];
  await db.upsertCurrentChores(groupId: groupId, choresJson: jsonEncode(blob));
}

Map<String, dynamic> _firstAssignment(String choresJson) {
  final list = jsonDecode(choresJson) as List;
  return (list.first as Map)['pending_assignment'] as Map<String, dynamic>;
}

String _firstDueStatus(String choresJson) {
  final list = jsonDecode(choresJson) as List;
  return (list.first as Map)['due_status'] as String;
}

void main() {
  test('wrapped connection failure stays queued and succeeds on retry',
      () async {
    final db = _memoryDb();
    final remote = _FailingCreateService(apiException(DioException(
      requestOptions: RequestOptions(path: '/chores'),
      type: DioExceptionType.connectionError,
    )));
    final repo = ChoreRepository(db: db, remote: remote);
    final result = await repo.createOfflineFirst(
      const CreateChoreRequest(groupId: 'g1', name: 'Dishes'),
      syncWindow: const Duration(seconds: 1),
    );
    expect(result.synced, isFalse);
    final op = (await db.getOutboxOpsByType('createChore')).single;
    expect(op.attemptCount, 0);
    remote.failure = null;
    remote.createdChoreId = 'server-1';
    await db.resetFailedOutboxOps(id: op.id);
    await repo.drainOutboxOnce();
    expect(await db.getOutboxOpsByType('createChore'), isEmpty);
    await db.close();
  });

  test('rejected creation reports failure and removes the optimistic duplicate',
      () async {
    final db = _memoryDb();
    final error = apiException(fakeDioException(statusCode: 403));
    final repo = ChoreRepository(db: db, remote: _FailingCreateService(error));
    await expectLater(
        repo.createOfflineFirst(
          const CreateChoreRequest(groupId: 'g1', name: 'Dishes'),
          syncWindow: const Duration(seconds: 1),
        ),
        throwsA(same(error)));
    expect(await db.getOutboxOpsByType('createChore'), isEmpty);
    expect(await repo.getCurrentChoresOnce('g1'), isEmpty);
    await db.close();
  });
  group('ChoreRepository offline optimistic patches —', () {
    late AppDatabase db;
    late ChoreRepository repo;
    const groupId = 'g1';
    const choreId = 'c1';

    setUp(() {
      db = _memoryDb();
      repo = ChoreRepository(db: db, remote: FakeChoreService());
    });

    tearDown(() => db.close());

    test('skip patches cached assignment status to skipped', () async {
      await _seedChore(db, groupId, choreId, status: 'pending');

      await repo.skipOfflineFirst(choreId, groupId: groupId);

      final row = await db.getCurrentChoresOnce(groupId);
      expect(_firstAssignment(row!.choresJson)['status'], 'skipped');
      // The op was queued for the eventual drain.
      expect(await db.outboxCount(), greaterThan(0));
    });

    test('reschedule patches due date and re-derives due_status', () async {
      await _seedChore(
        db,
        groupId,
        choreId,
        status: 'pending',
        dueDate: '2020-01-01T00:00:00.000',
        dueStatus: 'overdue',
      );

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await repo.rescheduleOfflineFirst(choreId, tomorrow, groupId: groupId);

      final row = await db.getCurrentChoresOnce(groupId);
      final assignment = _firstAssignment(row!.choresJson);
      expect(
          DateTime.parse(assignment['due_date'] as String).day, tomorrow.day);
      // Tomorrow is no longer overdue.
      expect(_firstDueStatus(row.choresJson), isNot('overdue'));
    });
  });

  group('ChoreRepository offline create —', () {
    late AppDatabase db;
    late FakeChoreService remote;
    late ChoreRepository repo;
    const groupId = 'g1';

    setUp(() {
      db = _memoryDb();
      remote = FakeChoreService();
      repo = ChoreRepository(db: db, remote: remote);
    });

    tearDown(() => db.close());

    CreateChoreRequest req([String name = 'Water plants']) =>
        CreateChoreRequest(groupId: groupId, name: name, frequency: 'weekly');

    test('shows the chore immediately and queues it', () async {
      final result = await repo.createOfflineFirst(req());

      expect(result.synced, isFalse);
      expect(result.chore.id, startsWith('local-'),
          reason: 'unsynced chore keeps its local id');

      final entries = jsonDecode(
        (await db.getCurrentChoresOnce(groupId))!.choresJson,
      ) as List;
      expect(entries, hasLength(1));
      expect((entries.single as Map)['chore']['name'], 'Water plants');
      expect((entries.single as Map)['pending_assignment'], isNull,
          reason: 'the server owns rotation; offline there is no assignee');
      expect(await db.outboxCount(), equals(1));
    });

    // THE regression test for this pass. A refresh is a wholesale blob
    // overwrite, so without the re-splice an SSE event or a sibling refresh
    // landing before the drain makes the new chore visibly disappear.
    test('a server refresh does not erase a still-queued create', () async {
      await repo.createOfflineFirst(req());
      // Server knows nothing about it yet.
      remote.currentChores = const [];

      await repo.refreshCurrentChores(groupId);

      final entries = jsonDecode(
        (await db.getCurrentChoresOnce(groupId))!.choresJson,
      ) as List;
      expect(entries, hasLength(1),
          reason: 'the queued chore must survive a server snapshot');
      expect((entries.single as Map)['chore']['name'], 'Water plants');
    });

    test('the re-splice stops once the server returns the chore', () async {
      final result = await repo.createOfflineFirst(req());
      final localId = result.chore.id;

      // Drain it: the op is consumed and ids are rewritten.
      remote.createdChoreId = 'server-1';
      await repo.drainOutboxOnce();
      expect(await db.outboxCount(), equals(0));

      remote.currentChores = [
        CurrentChore(
          chore: Chore(
            id: 'server-1',
            groupId: groupId,
            name: 'Water plants',
            rotationType: 'none',
            frequency: 'weekly',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          dueStatus: 'later',
          assignedToMe: false,
        ),
      ];
      await repo.refreshCurrentChores(groupId);

      final entries = jsonDecode(
        (await db.getCurrentChoresOnce(groupId))!.choresJson,
      ) as List;
      expect(entries, hasLength(1),
          reason: 'no duplicate after the create syncs');
      expect((entries.single as Map)['chore']['id'], 'server-1');
      expect(entries.map((e) => (e as Map)['chore']['id']),
          isNot(contains(localId)));
    });

    test('a complete queued against the local id retargets the server id',
        () async {
      final result = await repo.createOfflineFirst(req());
      final localId = result.chore.id;

      // User completes the chore before the create has synced.
      await repo.completeOfflineFirst(localId);

      remote.createdChoreId = 'server-1';
      await repo.drainOutboxOnce();

      // The create is gone; the complete now points at the server id.
      final remaining = await db.getOutboxOpsByType('completeChore');
      expect(remaining, hasLength(1));
      final payload =
          jsonDecode(remaining.single.payloadJson) as Map<String, dynamic>;
      expect(payload['choreId'], 'server-1',
          reason: 'rewriteOutboxPayloadIds must retarget the queued complete');
    });

    test('discarding a dead-lettered create removes the phantom chore',
        () async {
      final result = await repo.createOfflineFirst(req());
      final localId = result.chore.id;

      await db.deleteLocalEntity('chore', localId);

      final entries = jsonDecode(
        (await db.getCurrentChoresOnce(groupId))!.choresJson,
      ) as List;
      expect(entries, isEmpty,
          reason: 'blob-backed creates must be spliced out, not left behind');
    });
  });
}

class _FailingCreateService extends FakeChoreService {
  Object? failure;
  _FailingCreateService(this.failure);

  @override
  Future<Chore> createChore(CreateChoreRequest req, {String? idempotencyKey}) {
    if (failure != null) return Future.error(failure!);
    return super.createChore(req, idempotencyKey: idempotencyKey);
  }
}
