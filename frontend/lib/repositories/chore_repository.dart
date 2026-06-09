import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/chore_models.dart';
import '../services/chore_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';

class ChoreRepository {
  final AppDatabase _db;
  final ChoreService _remote;
  final Uuid _uuid;

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;
  String? _sseGroupId;

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
  }

  Future<void> skipOfflineFirst(String choreId, {String? reason}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'skipChore',
      payload: {'choreId': choreId, if (reason != null) 'reason': reason},
      idempotencyKey: 'skipChore:$choreId',
    );
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
  }

  Future<void> undoOfflineFirst(String choreId) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'undoChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'undoChore:$choreId',
    );
  }

  Future<void> drainOutboxOnce() async {
    final batch = await _db.getOutboxBatchByTypes(
      ['completeChore', 'skipChore', 'rescheduleChore', 'undoChore'],
      limit: 25,
    );
    if (batch.isEmpty) return;

    for (final op in batch) {
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }

      try {
        switch (op.type) {
          case 'completeChore':
            await _remote.completeChore(payload['choreId'] as String);
            await _db.deleteOutboxOp(op.id);
            break;
          case 'skipChore':
            final reason = payload['reason'] as String?;
            await _remote.skipChore(
              payload['choreId'] as String,
              skipReason: reason,
            );
            await _db.deleteOutboxOp(op.id);
            break;
          case 'rescheduleChore':
            await _remote.rescheduleChore(
              payload['choreId'] as String,
              dueDate: DateTime.parse(payload['dueDate'] as String),
            );
            await _db.deleteOutboxOp(op.id);
            break;
          case 'undoChore':
            await _remote.undoLastChoreExecution(payload['choreId'] as String);
            await _db.deleteOutboxOp(op.id);
            break;
        }
      } catch (e) {
        await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SSE real-time sync
  // ---------------------------------------------------------------------------

  /// Start receiving real-time updates for [groupId] via SSE.
  ///
  /// On any chore mutation event the local cache is refreshed, which causes
  /// the existing [watchCurrentChores] Drift stream to fire.
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService && _sseGroupId == groupId) return;
    _sseSub?.cancel();
    _sseService = sseService;
    _sseGroupId = groupId;
    // SSE connection is shared with ListRepository; connect is idempotent.
    sseService.connect(groupId);
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
    _sseGroupId = null;
  }

  Future<void> _handleSseEvent(SseEvent event) async {
    if (_sseGroupId == null) return;
    switch (event.type) {
      case 'chore:completed':
      case 'chore:skipped':
      case 'chore:rescheduled':
        await refreshCurrentChores(_sseGroupId!);
    }
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

