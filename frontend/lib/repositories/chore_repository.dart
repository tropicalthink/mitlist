import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/chore_models.dart';
import '../services/chore_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

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

  Future<void> completeOfflineFirst(String choreId, {String? groupId}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'completeChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'completeChore:$choreId',
      entityType: 'chore',
      entityId: choreId,
    );
    if (groupId != null) {
      // Optimistic local patch so the Drift stream reflects the completion
      // immediately; the post-drain refresh reconciles with the server.
      await _patchCachedAssignmentStatus(groupId, choreId, 'completed');
      unawaited(_drainAndRefresh(groupId));
    }
  }

  Future<void> skipOfflineFirst(String choreId, {String? reason, String? groupId}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'skipChore',
      payload: {'choreId': choreId, if (reason != null) 'reason': reason},
      idempotencyKey: 'skipChore:$choreId',
      entityType: 'chore',
      entityId: choreId,
    );
    if (groupId != null) {
      unawaited(_drainAndRefresh(groupId));
    }
  }

  Future<void> rescheduleOfflineFirst(String choreId, DateTime dueDate,
      {String? groupId}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'rescheduleChore',
      payload: {
        'choreId': choreId,
        'dueDate': dueDate.toUtc().toIso8601String(),
      },
      idempotencyKey: 'rescheduleChore:$choreId:${dueDate.toIso8601String()}',
      entityType: 'chore',
      entityId: choreId,
    );
    if (groupId != null) {
      unawaited(_drainAndRefresh(groupId));
    }
  }

  Future<void> undoOfflineFirst(String choreId, {String? groupId}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'undoChore',
      payload: {'choreId': choreId},
      idempotencyKey: 'undoChore:$choreId',
      entityType: 'chore',
      entityId: choreId,
    );
    if (groupId != null) {
      await _patchCachedAssignmentStatus(groupId, choreId, 'pending');
      unawaited(_drainAndRefresh(groupId));
    }
  }

  /// Rewrites the cached current-chores blob so [choreId]'s pending assignment
  /// carries [status]. Patches raw JSON in place to avoid round-tripping
  /// through the models.
  Future<void> _patchCachedAssignmentStatus(
    String groupId,
    String choreId,
    String status,
  ) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    final raw = row?.choresJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      var changed = false;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final chore = entry['chore'];
        if (chore is! Map || chore['id'] != choreId) continue;
        final pending = entry['pending_assignment'];
        if (pending is Map) {
          pending['status'] = status;
          pending['completed_at'] = status == 'completed'
              ? DateTime.now().toUtc().toIso8601String()
              : null;
          changed = true;
        }
      }
      if (changed) {
        await _db.upsertCurrentChores(
          groupId: groupId,
          choresJson: jsonEncode(decoded),
        );
      }
    } catch (_) {
      // Cache patch is best-effort; the drain + refresh reconciles.
    }
  }

  /// Best-effort immediate sync: push queued ops, then pull server state.
  /// Failures are swallowed; the cache keeps the optimistic patch offline.
  Future<void> _drainAndRefresh(String groupId) async {
    try {
      await drainOutboxOnce();
      await refreshCurrentChores(groupId);
    } catch (_) {}
  }

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: const ['completeChore', 'skipChore', 'rescheduleChore', 'undoChore'],
      handlers: {
        'completeChore': (op, payload) async {
          await _remote.completeChore(payload['choreId'] as String);
          await _db.deleteOutboxOp(op.id);
        },
        'skipChore': (op, payload) async {
          await _remote.skipChore(
            payload['choreId'] as String,
            skipReason: payload['reason'] as String?,
          );
          await _db.deleteOutboxOp(op.id);
        },
        'rescheduleChore': (op, payload) async {
          await _remote.rescheduleChore(
            payload['choreId'] as String,
            dueDate: DateTime.parse(payload['dueDate'] as String),
          );
          await _db.deleteOutboxOp(op.id);
        },
        'undoChore': (op, payload) async {
          await _remote.undoLastChoreExecution(payload['choreId'] as String);
          await _db.deleteOutboxOp(op.id);
        },
      },
    );
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

