import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/chore_models.dart';
import '../services/chore_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

/// Outcome of an offline-first chore create.
///
/// [synced] distinguishes "the server has this and assigned it" from "queued
/// locally", which is the difference between naming the next assignee and
/// staying quiet about it.
class ChoreCreateResult {
  final Chore chore;
  final bool synced;
  const ChoreCreateResult({required this.chore, required this.synced});
}

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
    return _db
        .watchCurrentChores(groupId)
        .map((row) => _decode(row?.choresJson));
  }

  Future<List<CurrentChore>> getCurrentChoresOnce(String groupId) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    return _decode(row?.choresJson);
  }

  Future<void> refreshCurrentChores(String groupId) async {
    final remote = await _remote.listCurrentChores(groupId);
    final entries = remote.map((c) => _encodeCurrentChore(c)).toList();
    await _db.upsertCurrentChores(
      groupId: groupId,
      choresJson: jsonEncode(await _withPendingCreates(groupId, entries)),
    );
  }

  /// Re-splices still-queued offline creates onto a server snapshot.
  ///
  /// The cache is one JSON blob, so a refresh is a wholesale overwrite — unlike
  /// the row-backed tables there is no per-entity merge. Without this, any
  /// refresh landing before the drain (an SSE chore event from another member,
  /// the refresh after completing a different chore) would erase a chore the
  /// user created moments ago while its op still sits in the outbox: the chore
  /// visibly vanishes and then reappears. Ops are dropped as they sync, so an
  /// entry stops being re-added exactly when the server starts returning it.
  Future<List<dynamic>> _withPendingCreates(
    String groupId,
    List<dynamic> serverEntries,
  ) async {
    final ops = await _db.getOutboxOpsByType('createChore');
    if (ops.isEmpty) return serverEntries;

    final present = <String>{
      for (final e in serverEntries)
        if (e is Map && e['chore'] is Map) e['chore']['id'] as String,
    };

    for (final op in ops) {
      try {
        final payload =
            (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
        if (payload['groupId'] != groupId) continue;
        final localId = payload['localId'] as String?;
        if (localId == null || present.contains(localId)) continue;
        final req = CreateChoreRequest.fromJson(
          (payload['request'] as Map).cast<String, dynamic>(),
        );
        serverEntries.add(_encodeCurrentChore(_localChore(localId, req)));
      } catch (_) {
        // A malformed op is the drainer's problem, not the cache's.
      }
    }
    return serverEntries;
  }

  /// Queues a chore for creation and shows it immediately.
  ///
  /// The server owns rotation, so offline we cannot know who the chore lands
  /// on: the optimistic entry carries a null `pending_assignment`, which
  /// `chores_screen` already renders as an unassigned queue row.
  ///
  /// [syncWindow] lets a caller wait briefly for the create to reach the
  /// server, so an online creation can still report who the chore landed on.
  /// Expiring is not a failure — the op stays queued either way; the result
  /// just reports [ChoreCreateResult.synced] as false so the caller can avoid
  /// promising an assignee it does not know.
  Future<ChoreCreateResult> createOfflineFirst(
    CreateChoreRequest req, {
    Duration syncWindow = Duration.zero,
  }) async {
    final localId = 'local-${_uuid.v4()}';
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createChore',
      payload: {
        'localId': localId,
        'groupId': req.groupId,
        'request': req.toJson(),
      },
      idempotencyKey: 'createChore:$localId',
      entityType: 'chore',
      entityId: localId,
    );
    await _spliceLocalChore(req.groupId, localId, req);

    final local = _localChore(localId, req).chore;
    if (syncWindow == Duration.zero) {
      unawaited(_drainAndRefresh(req.groupId));
      return ChoreCreateResult(chore: local, synced: false);
    }

    // Register interest *before* draining: the drain handler only records a
    // mapping when someone is waiting for it, so creates that sync later via
    // the coordinator don't accumulate entries nobody ever reads.
    _awaitingSync.add(localId);
    try {
      await _drainAndRefresh(req.groupId).timeout(syncWindow);
    } on TimeoutException {
      // Still queued; the coordinator finishes it.
    } catch (_) {}

    _awaitingSync.remove(localId);
    final serverId = _syncedCreates.remove(localId);
    return ChoreCreateResult(
      chore: serverId == null ? local : _withId(local, serverId),
      synced: serverId != null,
    );
  }

  /// Local ids whose creator is currently blocked on [createOfflineFirst]'s
  /// sync window. Gates [_syncedCreates] so the map stays empty in the common
  /// case (a create that syncs later, via the coordinator, with no one
  /// waiting) instead of growing for the repository's whole lifetime.
  final Set<String> _awaitingSync = {};

  /// Local id → server id, recorded only for ids in [_awaitingSync] and
  /// removed as soon as the waiter reads it.
  final Map<String, String> _syncedCreates = {};

  Chore _withId(Chore c, String id) => Chore(
        id: id,
        groupId: c.groupId,
        name: c.name,
        description: c.description,
        rotationType: c.rotationType,
        frequency: c.frequency,
        periodInterval: c.periodInterval,
        periodConfig: c.periodConfig,
        startDate: c.startDate,
        trackDateOnly: c.trackDateOnly,
        rollover: c.rollover,
        assignmentType: c.assignmentType,
        assignmentConfig: c.assignmentConfig,
        isActive: c.isActive,
        supplies: c.supplies,
        category: c.category,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  /// The optimistic shape of a not-yet-created chore.
  CurrentChore _localChore(String localId, CreateChoreRequest req) {
    final now = DateTime.now();
    return CurrentChore(
      chore: Chore(
        id: localId,
        groupId: req.groupId,
        name: req.name,
        description: req.description,
        rotationType: req.rotationType,
        frequency: req.frequency,
        periodInterval: req.periodInterval,
        periodConfig: req.periodConfig,
        startDate: req.startDate,
        trackDateOnly: req.trackDateOnly,
        rollover: req.rollover,
        assignmentType: req.assignmentType,
        assignmentConfig: req.assignmentConfig,
        isActive: req.isActive,
        supplies: req.supplies,
        category: req.category,
        createdAt: now,
        updatedAt: now,
      ),
      pendingAssignment: null,
      lastAssignment: null,
      dueStatus: _deriveDueStatus(req.startDate ?? now),
      assignedToMe: false,
    );
  }

  Future<void> _spliceLocalChore(
    String groupId,
    String localId,
    CreateChoreRequest req,
  ) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    final raw = row?.choresJson;
    List<dynamic> entries;
    try {
      final decoded = raw == null || raw.isEmpty ? null : jsonDecode(raw);
      entries = decoded is List ? decoded : <dynamic>[];
    } catch (_) {
      entries = <dynamic>[];
    }
    entries.add(_encodeCurrentChore(_localChore(localId, req)));
    await _db.upsertCurrentChores(
      groupId: groupId,
      choresJson: jsonEncode(entries),
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

  Future<void> skipOfflineFirst(String choreId,
      {String? reason, String? groupId}) async {
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'skipChore',
      payload: {'choreId': choreId, if (reason != null) 'reason': reason},
      idempotencyKey: 'skipChore:$choreId',
      entityType: 'chore',
      entityId: choreId,
    );
    if (groupId != null) {
      // Optimistic local patch so the Drift stream resolves the chore
      // immediately; the post-drain refresh reconciles with the server.
      await _patchCachedAssignmentStatus(groupId, choreId, 'skipped');
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
      // Optimistic local patch so the new due date (and derived due-status)
      // shows immediately; the post-drain refresh reconciles with the server.
      await _patchCachedAssignmentDueDate(groupId, choreId, dueDate);
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

  /// Rewrites the cached current-chores blob so [choreId]'s pending assignment
  /// carries [dueDate], recomputing the derived `due_status` so overdue/upcoming
  /// badges update offline. Best-effort; the drain + refresh reconciles.
  Future<void> _patchCachedAssignmentDueDate(
    String groupId,
    String choreId,
    DateTime dueDate,
  ) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    final raw = row?.choresJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      var changed = false;
      final iso = dueDate.toIso8601String();
      final dueStatus = _deriveDueStatus(dueDate);
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final chore = entry['chore'];
        if (chore is! Map || chore['id'] != choreId) continue;
        final pending = entry['pending_assignment'];
        if (pending is Map) {
          pending['due_date'] = iso;
          entry['due_status'] = dueStatus;
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

  /// Mirrors the server's `due_status` buckets for an optimistic reschedule.
  static String _deriveDueStatus(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;
    if (days < 0) return 'overdue';
    if (days == 0) return 'due_today';
    if (days <= 2) return 'due_soon';
    return 'later';
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
      // createChore shares this pass deliberately. The drainer re-reads each op
      // fresh inside one createdAt-ordered batch, so rewriting the temp id
      // after the create lands means a completeChore queued against `local-x`
      // sees the server id when its turn comes. A separate pass would break
      // that ordering.
      types: const [
        'createChore',
        'completeChore',
        'skipChore',
        'rescheduleChore',
        'undoChore'
      ],
      handlers: {
        'createChore': (op, payload) async {
          final localId = payload['localId'] as String?;
          final rawReq = payload['request'];
          if (localId == null || rawReq is! Map) {
            await _db.deleteOutboxOp(op.id);
            return;
          }
          final created = await _remote.createChore(
            CreateChoreRequest.fromJson(rawReq.cast<String, dynamic>()),
          );
          await _db.rewriteOutboxPayloadIds(oldId: localId, newId: created.id);
          await _db.deleteOutboxOp(op.id);
          if (_awaitingSync.contains(localId)) {
            _syncedCreates[localId] = created.id;
          }
        },
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
                'assigned_at':
                    c.pendingAssignment!.assignedAt.toIso8601String(),
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
                'completed_at':
                    c.lastAssignment!.completedAt?.toIso8601String(),
              },
        'due_status': c.dueStatus,
        'assigned_to_me': c.assignedToMe,
      };
}
