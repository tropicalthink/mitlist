import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/chore_models.dart';
import '../services/chore_service.dart';
import '../storage/app_database.dart';

class ChoreRepository {
  final AppDatabase _db;
  final ChoreService _remote;
  final Uuid _uuid;

  ChoreRepository({
    required AppDatabase db,
    required ChoreService remote,
    Uuid? uuid,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid();

  Stream<List<CurrentChore>> watchCurrentChores(String groupId) {
    return _db.watchCurrentChores(groupId).map((row) => _decode(row?.choresJson));
  }

  Future<List<CurrentChore>> getCurrentChoresOnce(String groupId) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    return _decode(row?.choresJson);
  }

  Future<void> refreshCurrentChores(String groupId) async {
    final remote = await _remote.listCurrentChores(groupId);
    await _db.upsertCurrentChores(
      groupId: groupId,
      choresJson: jsonEncode(remote.map((c) => _encodeCurrentChore(c)).toList()),
    );
  }

  Future<void> completeOfflineFirst(String choreId) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'completeChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'completeChore:$choreId',
    );
    try {
      await _remote.completeChore(choreId);
      // Best-effort: outbox entry will be cleared by a global drainer later.
    } catch (_) {}
  }

  Future<void> skipOfflineFirst(String choreId) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'skipChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'skipChore:$choreId',
    );
    try {
      await _remote.skipChore(choreId);
    } catch (_) {}
  }

  Future<void> rescheduleOfflineFirst(String choreId, DateTime dueDate) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'rescheduleChore',
      payload: {
        'choreId': choreId,
        'dueDate': dueDate.toUtc().toIso8601String(),
      },
      idempotencyKey: 'rescheduleChore:$choreId:${dueDate.toIso8601String()}',
    );
    try {
      await _remote.rescheduleChore(choreId, dueDate: dueDate);
    } catch (_) {}
  }

  Future<void> undoOfflineFirst(String choreId) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'undoChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'undoChore:$choreId',
    );
    try {
      await _remote.undoLastChoreExecution(choreId);
    } catch (_) {}
  }

  List<CurrentChore> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => CurrentChore.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _encodeCurrentChore(CurrentChore c) => {
        'chore': c.chore.toJson(),
        'pending_assignment': c.pendingAssignment == null
            ? null
            : {
                'id': c.pendingAssignment!.id,
                'chore_id': c.pendingAssignment!.choreId,
                'user_id': c.pendingAssignment!.userId,
                'status': c.pendingAssignment!.status,
                'due_date': c.pendingAssignment!.dueDate?.toIso8601String(),
                'assigned_at': c.pendingAssignment!.assignedAt.toIso8601String(),
                'completed_at':
                    c.pendingAssignment!.completedAt?.toIso8601String(),
              },
        'last_assignment': c.lastAssignment == null
            ? null
            : {
                'id': c.lastAssignment!.id,
                'chore_id': c.lastAssignment!.choreId,
                'user_id': c.lastAssignment!.userId,
                'status': c.lastAssignment!.status,
                'due_date': c.lastAssignment!.dueDate?.toIso8601String(),
                'assigned_at': c.lastAssignment!.assignedAt.toIso8601String(),
                'completed_at': c.lastAssignment!.completedAt?.toIso8601String(),
              },
        'due_status': c.dueStatus,
        'assigned_to_me': c.assignedToMe,
      };
}

