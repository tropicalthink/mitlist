import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/services/api_error_mapper.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

const _groupId = 'g1';

Chore _chore(String id, {String name = 'Dishes', String? category}) => Chore(
      id: id,
      groupId: _groupId,
      name: name,
      rotationType: 'none',
      frequency: 'weekly',
      isActive: true,
      category: category,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

CurrentChore _current(String id, {String status = 'pending'}) => CurrentChore(
      chore: _chore(id),
      pendingAssignment: ChoreAssignment(
        id: 'a-$id',
        choreId: id,
        userId: 'u1',
        status: status,
        dueDate: DateTime.now(),
        assignedAt: DateTime(2026, 1, 1),
        completedAt: null,
      ),
      dueStatus: 'due_today',
      assignedToMe: true,
    );

/// A fake server that records every write and can be switched offline.
class _RecordingChoreService extends FakeChoreService {
  bool offline = false;
  Exception? deleteError;
  final List<String> calls = [];
  final List<String?> idempotencyKeys = [];
  final List<ChoreSubtask> serverSubtasks = [];
  int _subtaskSeq = 0;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<List<CurrentChore>> listCurrentChores(
    String groupId, {
    int limit = 100,
    int offset = 0,
    int dueSoonDays = 7,
  }) async {
    _check();
    return super.listCurrentChores(groupId);
  }

  @override
  Future<Chore> createChore(CreateChoreRequest req,
      {String? idempotencyKey}) async {
    _check();
    calls.add('create');
    return super.createChore(req, idempotencyKey: idempotencyKey);
  }

  @override
  Future<Chore> updateChoreBody(String id, Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    _check();
    calls.add('update:$id:${body['name']}');
    return _chore(id, name: body['name'] as String);
  }

  @override
  Future<void> deleteChore(String id, {String? idempotencyKey}) async {
    _check();
    calls.add('delete:$id');
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> completeChore(String id,
      {String? notes, String? idempotencyKey}) async {
    _check();
    calls.add('complete:$id');
    idempotencyKeys.add(idempotencyKey);
  }

  @override
  Future<void> skipChore(String id,
      {String? skipReason, String? idempotencyKey}) async {
    _check();
    calls.add('skip:$id:$skipReason');
  }

  @override
  Future<List<ChoreSubtask>> listSubtasks(String choreId) async {
    _check();
    return [...serverSubtasks.where((s) => s.choreId == choreId)];
  }

  @override
  Future<ChoreSubtask> createSubtask(String choreId, String title,
      {String? idempotencyKey}) async {
    _check();
    calls.add('createSubtask:$choreId:$title');
    final s = ChoreSubtask(
      id: 'st-${++_subtaskSeq}',
      choreId: choreId,
      title: title,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    serverSubtasks.add(s);
    return s;
  }

  @override
  Future<ChoreSubtask> updateSubtask(String subtaskId,
      {String? title,
      bool? completed,
      int? position,
      String? idempotencyKey}) async {
    _check();
    calls.add('updateSubtask:$subtaskId:$completed');
    final i = serverSubtasks.indexWhere((s) => s.id == subtaskId);
    serverSubtasks[i] = serverSubtasks[i].copyWith(completed: completed);
    return serverSubtasks[i];
  }

  @override
  Future<void> deleteSubtask(String subtaskId, {String? idempotencyKey}) async {
    _check();
    calls.add('deleteSubtask:$subtaskId');
    serverSubtasks.removeWhere((s) => s.id == subtaskId);
  }
}

void main() {
  late AppDatabase db;
  late _RecordingChoreService remote;
  late ChoreRepository repo;

  setUp(() {
    db = _memoryDb();
    remote = _RecordingChoreService();
    // A no-op session hook: writes only queue, so each test drains
    // explicitly, like the coordinator does once back online.
    repo = ChoreRepository(db: db, remote: remote, onLocalWrite: () {});
  });

  tearDown(() => db.close());

  Future<void> seedServer(List<CurrentChore> chores) async {
    remote.currentChores = chores;
    await repo.refreshCurrentChores(_groupId);
  }

  Future<List<CurrentChore>> cached() => repo.getCurrentChoresOnce(_groupId);

  group('edit offline —', () {
    test('patches the cache, survives a refresh and syncs on drain', () async {
      await seedServer([_current('c1')]);
      remote.offline = true;

      await repo.updateOfflineFirst(
        _chore('c1', category: 'Kitchen'),
        const UpdateChoreRequest(name: 'Dishes & pans', frequency: 'daily'),
      );

      var chore = (await cached()).single.chore;
      expect(chore.name, 'Dishes & pans');
      expect(chore.frequency, 'daily');
      // The server clears an omitted category; the offline view matches.
      expect(chore.category, isNull);

      // A refresh landing before the drain must not revert the edit.
      remote.offline = false;
      await repo.refreshCurrentChores(_groupId);
      expect((await cached()).single.chore.name, 'Dishes & pans');

      await repo.drainOutboxOnce();
      expect(remote.calls, ['update:c1:Dishes & pans']);
      expect(await db.outboxCount(), 0);
    });

    test('an edit of an unsynced chore follows its create to the server id',
        () async {
      remote.offline = true;
      final created = await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      final local = (await cached()).single.chore;
      await repo.updateOfflineFirst(
          local, const UpdateChoreRequest(name: 'Bins out'));
      expect((await cached()).single.chore.name, 'Bins out');

      remote.offline = false;
      remote.createdChoreId = 'server-1';
      await repo.drainOutboxOnce();

      expect(created.chore.id, startsWith('local-'));
      expect(remote.calls, ['create', 'update:server-1:Bins out'],
          reason: 'the local id is never sent');
      // The cached row already carries the server id.
      expect((await cached()).single.chore.id, 'server-1');
    });
  });

  group('delete offline —', () {
    test('removes the chore, keeps it gone across a refresh, deletes on drain',
        () async {
      await seedServer([_current('c1'), _current('c2')]);
      remote.offline = true;

      await repo.deleteOfflineFirst('c1', groupId: _groupId, name: 'Dishes');
      expect((await cached()).map((c) => c.chore.id), ['c2']);

      remote.offline = false;
      await repo.refreshCurrentChores(_groupId);
      expect((await cached()).map((c) => c.chore.id), ['c2'],
          reason: 'a queued delete is replayed over the server snapshot');

      await repo.drainOutboxOnce();
      expect(remote.calls, ['delete:c1']);
      expect(await db.outboxCount(), 0);
    });

    test('a chore already deleted on the server counts as deleted', () async {
      await seedServer([_current('c1')]);
      remote.deleteError = apiException(fakeDioException(statusCode: 404));

      await repo.deleteOfflineFirst('c1', groupId: _groupId);
      await repo.drainOutboxOnce();

      expect(await db.outboxCount(), 0, reason: 'a 404 is not a failure');
    });

    test('deleting an unsynced chore drops its queued ops without a request',
        () async {
      remote.offline = true;
      final created = await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      final id = created.chore.id;
      await repo.completeOfflineFirst(id, groupId: _groupId);
      await repo.addSubtaskOfflineFirst(id, 'Kitchen bin');
      expect(await db.outboxCount(), 3);

      await repo.deleteOfflineFirst(id, groupId: _groupId);

      expect(await cached(), isEmpty);
      expect(await db.outboxCount(), 0);
      remote.offline = false;
      await repo.drainOutboxOnce();
      expect(remote.calls, isEmpty);
    });
  });

  group('complete / skip / undo —', () {
    test('every completion gets its own idempotency key', () async {
      // Keyed on the chore alone, the server replayed the first completion
      // of a recurring chore for every later one within its 7-day window.
      await seedServer([_current('c1')]);
      await repo.completeOfflineFirst('c1', groupId: _groupId);
      await repo.undoOfflineFirst('c1', groupId: _groupId);
      await repo.completeOfflineFirst('c1', groupId: _groupId);

      final keys = [
        for (final op in await db.getOutboxOpsByType('completeChore'))
          op.idempotencyKey,
      ];
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(2));
    });

    test('a queued completion survives a refresh that predates the drain',
        () async {
      await seedServer([_current('c1')]);
      await repo.completeOfflineFirst('c1', groupId: _groupId);

      // The server has not seen the completion yet.
      await repo.refreshCurrentChores(_groupId);
      expect((await cached()).single.pendingAssignment?.status, 'completed');
    });

    test('skip with a reason is queued (no direct request)', () async {
      await seedServer([_current('c1')]);
      remote.offline = true;
      await repo.skipOfflineFirst('c1', reason: 'Away', groupId: _groupId);
      expect((await cached()).single.pendingAssignment?.status, 'skipped');

      remote.offline = false;
      await repo.drainOutboxOnce();
      expect(remote.calls, ['skip:c1:Away']);
    });

    test('completing an unsynced chore settles it; undo puts it back',
        () async {
      remote.offline = true;
      final created = await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      final id = created.chore.id;

      await repo.completeOfflineFirst(id, groupId: _groupId);
      final done = (await cached()).single.pendingAssignment;
      expect(done?.status, 'completed');
      expect(done?.completedAt, isNotNull);

      await repo.undoOfflineFirst(id, groupId: _groupId);
      expect((await cached()).single.pendingAssignment, isNull);
    });

    test('an op whose create was discarded is dropped, never sent', () async {
      remote.offline = true;
      final created = await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      final id = created.chore.id;
      await repo.completeOfflineFirst(id);
      // The failed-changes sheet discards the create.
      final create = (await db.getOutboxOpsByType('createChore')).single;
      await db.deleteOutboxOp(create.id);

      remote.offline = false;
      await repo.drainOutboxOnce();

      expect(remote.calls, isEmpty);
      expect(await db.outboxCount(), 0);
    });

    test('a create deleted while in flight deletes the server copy', () async {
      remote.offline = true;
      await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      final create = (await db.getOutboxOpsByType('createChore')).single;
      remote.offline = false;
      remote.createdChoreId = 'server-1';
      // Simulate the delete landing while the POST is on the wire.
      final racing = _DeleteDuringCreate(db, create.id, remote);
      final racingRepo =
          ChoreRepository(db: db, remote: racing, onLocalWrite: () {});

      await racingRepo.drainOutboxOnce();
      // The delete is queued behind the pass that discovered it.
      await racingRepo.drainOutboxOnce();

      expect(racing.calls, ['create', 'delete:server-1']);
      expect(await db.outboxCount(), 0);
    });
  });

  group('subtasks offline —', () {
    test('add, toggle and delete work offline and sync in order', () async {
      await seedServer([_current('c1')]);
      remote.offline = true;

      final a = await repo.addSubtaskOfflineFirst('c1', 'Sponge');
      final b = await repo.addSubtaskOfflineFirst('c1', 'Soap');
      await repo.toggleSubtaskOfflineFirst('c1', a.id, true);
      await repo.deleteSubtaskOfflineFirst('c1', b.id);

      final offline = await repo.loadSubtasks('c1');
      expect(offline.map((s) => s.title), ['Sponge']);
      expect(offline.single.completed, isTrue);
      expect(offline.single.id, startsWith('local-'));
      // Deleting the never-synced subtask dropped its create.
      expect(await db.outboxCount(), 2);

      remote.offline = false;
      await repo.drainOutboxOnce();
      expect(
          remote.calls, ['createSubtask:c1:Sponge', 'updateSubtask:st-1:true']);

      final online = await repo.loadSubtasks('c1');
      expect(online.single.id, 'st-1');
      expect(online.single.completed, isTrue);
    });

    test(
        'a toggle made with the local id after the create synced is retargeted',
        () async {
      await seedServer([_current('c1')]);
      final a = await repo.addSubtaskOfflineFirst('c1', 'Sponge');
      await repo.drainOutboxOnce();

      // The open detail sheet still holds the local id.
      await repo.toggleSubtaskOfflineFirst('c1', a.id, true);
      await repo.drainOutboxOnce();

      expect(remote.calls.last, 'updateSubtask:st-1:true');
    });

    test('subtasks of an unsynced chore follow it to the server id', () async {
      remote.offline = true;
      final created = await repo.createOfflineFirst(
          const CreateChoreRequest(groupId: _groupId, name: 'Bins'));
      await repo.addSubtaskOfflineFirst(created.chore.id, 'Kitchen bin');

      remote.offline = false;
      remote.createdChoreId = 'server-1';
      await repo.drainOutboxOnce();

      expect(remote.calls, ['create', 'createSubtask:server-1:Kitchen bin']);
      final stored = await repo.getCachedSubtasks('server-1');
      expect(stored.single.title, 'Kitchen bin');
      expect(stored.single.choreId, 'server-1');
    });

    test('a refresh before the drain keeps queued subtask edits', () async {
      await seedServer([_current('c1')]);
      await repo.addSubtaskOfflineFirst('c1', 'Sponge');

      // Server has nothing yet.
      final loaded = await repo.loadSubtasks('c1');
      expect(loaded.map((s) => s.title), ['Sponge']);
    });
  });

  test('a far reschedule re-buckets the cached chore as later', () async {
    await seedServer([_current('c1')]);
    await repo.rescheduleOfflineFirst(
        'c1', DateTime.now().add(const Duration(days: 5)),
        groupId: _groupId);
    final raw =
        jsonDecode((await db.getCurrentChoresOnce(_groupId))!.choresJson)
            as List;
    expect((raw.single as Map)['due_status'], 'later');
  });
}

/// Deletes the queued create (as `deleteOfflineFirst` would) while its POST
/// is in flight.
class _DeleteDuringCreate extends _RecordingChoreService {
  _DeleteDuringCreate(this._db, this._opId, _RecordingChoreService base) {
    createdChoreId = base.createdChoreId;
  }

  final AppDatabase _db;
  final String _opId;

  @override
  Future<Chore> createChore(CreateChoreRequest req,
      {String? idempotencyKey}) async {
    final created =
        await super.createChore(req, idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(_opId);
    return created;
  }
}
