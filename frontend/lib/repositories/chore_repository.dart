import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:uuid/uuid.dart';

import '../models/chore_models.dart';
import '../services/api_error_mapper.dart';
import '../services/chore_service.dart';
import '../services/product_events.dart';
import '../services/response_cache_interceptor.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';
import 'outbox_error_classifier.dart';

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

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [_afterLocalWrite].
  final void Function()? _onLocalWrite;

  /// Groups whose chores were written during the current sync session. The
  /// session's drain refreshes them afterwards, as [_drainAndRefresh] does for
  /// an immediate sync, so server-owned state (rotation, due status) catches up.
  final Set<String> _refreshAfterDrain = {};

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;
  String? _sseGroupId;

  /// Chore ops, all drained in one createdAt-ordered pass and replayed in the
  /// same order over every server snapshot (see [_withPendingOps]).
  static const List<String> _choreOpTypes = [
    'createChore',
    'updateChore',
    'deleteChore',
    'completeChore',
    'skipChore',
    'rescheduleChore',
    'undoChore',
  ];

  static const List<String> _subtaskOpTypes = [
    'createChoreSubtask',
    'updateChoreSubtask',
    'deleteChoreSubtask',
  ];

  /// Prefix of the optimistic assignment a completion or skip gives a chore
  /// the server has not assigned yet (an offline create), so the queue can
  /// settle it like any other chore.
  static const String _localAssignmentPrefix = 'local-assignment-';

  ChoreRepository({
    required AppDatabase db,
    required ChoreService remote,
    Uuid? uuid,
    void Function()? onLocalWrite,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _onLocalWrite = onLocalWrite;

  static bool _isLocalId(String id) => id.startsWith('local-');

  /// Temp id → server id for creates that synced during this run.
  ///
  /// Screens hold on to the id they rendered, so a tap on a chore or subtask
  /// created offline can arrive after its create already synced and its
  /// queued ops were retargeted. Without this the new op would carry the dead
  /// `local-` id, which the server can never resolve.
  final Map<String, String> _idRemap = {};

  String _resolveId(String id) => _idRemap[id] ?? id;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Stream<List<CurrentChore>> watchCurrentChores(String groupId) {
    return _db
        .watchCurrentChores(groupId)
        .map((row) => _decode(row?.choresJson));
  }

  Future<List<CurrentChore>> getCurrentChoresOnce(String groupId) async {
    final row = await _db.getCurrentChoresOnce(groupId);
    return _decode(row?.choresJson);
  }

  /// The cached chore [choreId] in [groupId], queued edits included, or null.
  ///
  /// The detail and edit sheets start from this rather than a fresh fetch, so
  /// both work offline and show an edit made offline instead of the server's
  /// older copy.
  Future<CurrentChore?> getCachedChore(String groupId, String choreId) async {
    final id = _resolveId(choreId);
    for (final c in await getCurrentChoresOnce(groupId)) {
      if (c.chore.id == id) return c;
    }
    return null;
  }

  /// Pulls the server's chores into the cache, queued ops replayed on top.
  ///
  /// Live only: offline this throws instead of being answered from the HTTP
  /// response cache, whose older body would overwrite the cache (see
  /// [ResponseCacheInterceptor.liveOnly]). Callers keep showing the cache.
  Future<void> refreshCurrentChores(String groupId) async {
    final remote = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listCurrentChores(groupId));
    final entries = remote.map((c) => _encodeCurrentChore(c)).toList();
    await _db.upsertCurrentChores(
      groupId: groupId,
      choresJson: jsonEncode(await _withPendingOps(groupId, entries)),
    );
  }

  /// Replays every still-queued chore op onto a server snapshot.
  ///
  /// The cache is one JSON blob, so a refresh is a wholesale overwrite — unlike
  /// the row-backed tables there is no per-entity merge. Without this, any
  /// refresh landing before the drain (an SSE chore event from another member,
  /// the refresh after completing a different chore, or the offline response
  /// cache answering for the network) would undo what the user just did while
  /// its op still sits in the outbox: a created chore vanishes, a completed
  /// one comes back, a deleted one reappears. Ops are dropped as they sync, so
  /// each stops being replayed exactly when the server starts reflecting it.
  Future<List<dynamic>> _withPendingOps(
    String groupId,
    List<dynamic> serverEntries,
  ) async {
    final ops = await _pendingOps(_choreOpTypes);
    for (final op in ops) {
      final payload = _decodePayload(op.payloadJson);
      if (payload == null) continue;
      if (op.type == 'createChore' && payload['groupId'] != groupId) continue;
      try {
        _applyChoreOp(serverEntries, op.type, payload);
      } catch (_) {
        // A malformed op is the drainer's problem, not the cache's.
      }
    }
    return serverEntries;
  }

  /// Queued ops of [types] in the order the drainer sends them. rowid breaks
  /// ties inside one second (createdAt is stored in whole seconds), so a
  /// complete and its undo replay in the order they were made.
  Future<List<OutboxOp>> _pendingOps(List<String> types) {
    return (_db.select(_db.outboxOps)
          ..where((t) => t.type.isIn(types))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt),
            (_) => OrderingTerm(
                  expression: const CustomExpression<int>('rowid'),
                ),
          ]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Chore writes (optimistic cache patch + outbox op)
  // ---------------------------------------------------------------------------

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
    final opId = _uuid.v4();
    final payload = {
      'localId': localId,
      'groupId': req.groupId,
      'request': req.toJson(),
    };
    await _db.transaction(() async {
      await _db.enqueueOutbox(
        id: opId,
        type: 'createChore',
        payload: payload,
        idempotencyKey: 'createChore:$localId',
        entityType: 'chore',
        entityId: localId,
      );
      await _patchCache(
          req.groupId, (e) => _applyChoreOp(e, 'createChore', payload));
    });

    // Product events (plans/048 stage 8): the first thing added in a
    // household created or joined on this install.
    unawaited(ProductEvents.instance.noteItemAdded(req.groupId, 'chore'));

    final local = _localChore(localId, req).chore;
    if (syncWindow == Duration.zero) {
      _afterLocalWrite(req.groupId);
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
    final failure = _failedCreates.remove(localId);
    if (failure != null) {
      // The editor still owns the draft: remove the rejected optimistic copy
      // so retrying from that editor cannot leave a duplicate in the outbox.
      await _db.transaction(() async {
        await _db.deleteOutboxOp(opId);
        await _db.deleteLocalEntity('chore', localId);
      });
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
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
  final Map<String, Object> _failedCreates = {};

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

  /// Saves an edit of [existing] locally and queues the PATCH.
  ///
  /// The backend replaces name, schedule and assignment wholesale, so [req]
  /// must be the full chore (see `ChoreCreationSheet._onSaveEdit`). An edit of
  /// a chore still waiting for its create is queued behind that create and
  /// retargeted to the server id when it lands.
  Future<void> updateOfflineFirst(Chore existing, UpdateChoreRequest req) =>
      _queueChoreOp(
        type: 'updateChore',
        choreId: existing.id,
        groupId: existing.groupId,
        payload: {'groupId': existing.groupId, 'request': req.toJson()},
      );

  /// Removes a chore locally and queues its delete.
  ///
  /// A chore that never reached the server has nothing to delete there: its
  /// queued create and everything queued against it are simply dropped. If
  /// that create is already in flight, the create handler notices its op is
  /// gone and deletes the server copy (see the `createChore` handler).
  Future<void> deleteOfflineFirst(String choreId,
      {required String groupId, String? name}) async {
    final id = _resolveId(choreId);
    if (_isLocalId(id)) {
      final queued = await _pendingOps([..._choreOpTypes, ..._subtaskOpTypes]);
      await _db.transaction(() async {
        for (final op in queued) {
          final payload = _decodePayload(op.payloadJson);
          if (op.entityId == id || payload?['choreId'] == id) {
            await _db.deleteOutboxOp(op.id);
          }
        }
        await _patchCache(groupId, (e) => _removeChore(e, id));
      });
      return;
    }
    await _queueChoreOp(
      type: 'deleteChore',
      choreId: id,
      groupId: groupId,
      payload: {'groupId': groupId, if (name != null) 'name': name},
      // One delete per chore: a retry after a lost response must replay, not
      // turn into a 404.
      idempotencyKey: 'deleteChore:$id',
    );
  }

  Future<void> completeOfflineFirst(String choreId, {String? groupId}) =>
      _queueChoreOp(
        type: 'completeChore',
        choreId: choreId,
        groupId: groupId,
      );

  /// Shows a chore completed outside the app (a home screen widget,
  /// plans/047) in the cache. The completion request is queued separately,
  /// so nothing is enqueued here.
  Future<void> applyExternalCompletion(String groupId, String choreId) =>
      _patchCache(
        groupId,
        (e) => _applyChoreOp(e, 'completeChore', {'choreId': choreId}),
      );

  Future<void> skipOfflineFirst(String choreId,
          {String? reason, String? groupId}) =>
      _queueChoreOp(
        type: 'skipChore',
        choreId: choreId,
        groupId: groupId,
        payload: {if (reason != null) 'reason': reason},
      );

  Future<void> rescheduleOfflineFirst(String choreId, DateTime dueDate,
          {String? groupId}) =>
      _queueChoreOp(
        type: 'rescheduleChore',
        choreId: choreId,
        groupId: groupId,
        payload: {'dueDate': dueDate.toUtc().toIso8601String()},
      );

  Future<void> undoOfflineFirst(String choreId, {String? groupId}) =>
      _queueChoreOp(
        type: 'undoChore',
        choreId: choreId,
        groupId: groupId,
      );

  /// Patches the cached chores of [groupId] with the op and queues it, as one
  /// atomic local change, then opens the sync session.
  ///
  /// Without [groupId] the op is only queued: there is no cache to patch and
  /// nothing to refresh afterwards.
  ///
  /// The idempotency key defaults to one per op. Keying a completion on the
  /// chore alone made the server replay the *first* completion for every
  /// later one within its 7-day window: a daily chore done on Tuesday was
  /// answered with Monday's stored response and never recorded.
  Future<void> _queueChoreOp({
    required String type,
    required String choreId,
    String? groupId,
    Map<String, dynamic> payload = const {},
    String? idempotencyKey,
  }) async {
    final id = _resolveId(choreId);
    final opId = _uuid.v4();
    final full = {...payload, 'choreId': id};
    await _db.transaction(() async {
      if (groupId != null) {
        await _patchCache(groupId, (e) => _applyChoreOp(e, type, full));
      }
      await _db.enqueueOutbox(
        id: opId,
        type: type,
        payload: full,
        idempotencyKey: idempotencyKey ?? '$type:$id:$opId',
        entityType: 'chore',
        entityId: id,
      );
    });
    if (groupId != null) _afterLocalWrite(groupId);
  }

  // ---------------------------------------------------------------------------
  // Cache patching (shared by optimistic writes and replay)
  // ---------------------------------------------------------------------------

  /// Reads the cached chores of [groupId], lets [patch] edit the raw JSON and
  /// writes it back when it reports a change. Patches raw JSON in place to
  /// avoid round-tripping through the models (and so it tolerates partial
  /// entries). Best-effort: the drain + refresh reconciles.
  Future<void> _patchCache(
    String groupId,
    bool Function(List<dynamic> entries) patch,
  ) async {
    try {
      final row = await _db.getCurrentChoresOnce(groupId);
      final raw = row?.choresJson;
      List<dynamic> entries;
      try {
        final decoded = raw == null || raw.isEmpty ? null : jsonDecode(raw);
        entries = decoded is List ? decoded : <dynamic>[];
      } catch (_) {
        entries = <dynamic>[];
      }
      if (!patch(entries)) return;
      await _db.upsertCurrentChores(
        groupId: groupId,
        choresJson: jsonEncode(entries),
      );
    } catch (_) {
      // Cache patch is best-effort; the drain + refresh reconciles.
    }
  }

  /// Applies one queued chore op to the raw cached entries. Returns whether
  /// anything changed.
  bool _applyChoreOp(
    List<dynamic> entries,
    String type,
    Map<String, dynamic> payload,
  ) {
    if (type == 'createChore') {
      final localId = payload['localId'] as String?;
      final rawReq = payload['request'];
      if (localId == null || rawReq is! Map) return false;
      if (_entryFor(entries, localId) != null) return false;
      final req = CreateChoreRequest.fromJson(rawReq.cast<String, dynamic>());
      entries.add(_encodeCurrentChore(_localChore(localId, req)));
      return true;
    }

    final choreId = payload['choreId'];
    if (choreId is! String) return false;
    if (type == 'deleteChore') return _removeChore(entries, choreId);

    final entry = _entryFor(entries, choreId);
    if (entry == null) return false;
    switch (type) {
      case 'updateChore':
        final request = payload['request'];
        final chore = entry['chore'];
        if (request is! Map || chore is! Map) return false;
        _applyChoreEdit(chore, request);
        return true;
      case 'completeChore':
        return _setAssignmentStatus(entry, choreId, 'completed');
      case 'skipChore':
        return _setAssignmentStatus(entry, choreId, 'skipped');
      case 'undoChore':
        return _setAssignmentStatus(entry, choreId, 'pending');
      case 'rescheduleChore':
        final due = DateTime.tryParse(payload['dueDate'] as String? ?? '');
        if (due == null) return false;
        final pending = entry['pending_assignment'];
        if (pending is! Map) return false;
        final local = due.toLocal();
        pending['due_date'] = local.toIso8601String();
        // Re-derive the bucket so overdue/upcoming badges update offline.
        entry['due_status'] = _deriveDueStatus(local);
        return true;
    }
    return false;
  }

  static Map<dynamic, dynamic>? _entryFor(List<dynamic> entries, String id) {
    for (final entry in entries) {
      if (entry is! Map) continue;
      final chore = entry['chore'];
      if (chore is Map && chore['id'] == id) return entry;
    }
    return null;
  }

  static bool _removeChore(List<dynamic> entries, String id) {
    final before = entries.length;
    entries.removeWhere(
        (e) => e is Map && e['chore'] is Map && e['chore']['id'] == id);
    return entries.length != before;
  }

  /// Mirrors the backend's PATCH: every field in the request replaces the
  /// cached one, and description/category are replaced even when absent (the
  /// server clears them), so the offline view matches what will sync.
  static void _applyChoreEdit(Map chore, Map request) {
    const replaced = [
      'name',
      'rotation_type',
      'frequency',
      'period_interval',
      'period_config',
      'start_date',
      'track_date_only',
      'rollover',
      'assignment_type',
      'assignment_config',
      'is_active',
      'supplies',
    ];
    for (final key in replaced) {
      if (request.containsKey(key)) chore[key] = request[key];
    }
    chore['description'] = request['description'];
    chore['category'] = request['category'];
    chore['updated_at'] = DateTime.now().toIso8601String();
  }

  /// Sets the pending assignment's status. A chore the server has not
  /// assigned yet (created offline) gets a placeholder assignment so it
  /// settles out of the queue like any other; undoing removes it again.
  static bool _setAssignmentStatus(Map entry, String choreId, String status) {
    final now = DateTime.now();
    final pending = entry['pending_assignment'];
    if (pending is Map) {
      final id = pending['id'];
      if (status == 'pending' &&
          id is String &&
          id.startsWith(_localAssignmentPrefix)) {
        entry['pending_assignment'] = null;
        return true;
      }
      pending['status'] = status;
      pending['completed_at'] =
          status == 'completed' ? now.toUtc().toIso8601String() : null;
      return true;
    }
    if (status == 'pending') return false;
    entry['pending_assignment'] = {
      'id': '$_localAssignmentPrefix$choreId',
      'chore_id': choreId,
      // Unknown until the server assigns it; the chores screen reads an empty
      // doer on a completed placeholder as "you".
      'user_id': '',
      'status': status,
      'due_date': null,
      'assigned_at': now.toIso8601String(),
      'completed_at':
          status == 'completed' ? now.toUtc().toIso8601String() : null,
    };
    return true;
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

  // ---------------------------------------------------------------------------
  // Subtasks
  // ---------------------------------------------------------------------------

  /// Subtasks are kept per chore in the generic response cache under a key of
  /// their own (not a URL, so the HTTP response cache never collides with it),
  /// with queued edits applied, the same way the current-chores blob is.
  static String _subtasksKey(String choreId) => 'chore_subtasks:$choreId';

  /// The stored subtasks of [choreId], queued edits included.
  Future<List<ChoreSubtask>> getCachedSubtasks(String choreId) async {
    final row = await _db.getResponseCache(_subtasksKey(_resolveId(choreId)));
    return _decodeSubtasks(row?.bodyJson);
  }

  /// Fetches the subtasks of [choreId] and returns them with queued edits
  /// applied; offline, returns the stored copy instead of failing.
  Future<List<ChoreSubtask>> loadSubtasks(String choreId) async {
    final id = _resolveId(choreId);
    if (!_isLocalId(id)) {
      try {
        // Live only: offline the HTTP response cache would answer with an
        // older body and erase edits that already synced.
        final remote = await ResponseCacheInterceptor.liveOnly(
            () => _remote.listSubtasks(id));
        await _storeSubtasks(id, remote);
      } catch (_) {
        // Offline. Seed from the HTTP response cache only when this chore
        // has no stored copy yet (first open since this cache existed).
        if (await _db.getResponseCache(_subtasksKey(id)) == null) {
          try {
            await _storeSubtasks(id, await _remote.listSubtasks(id));
          } catch (_) {}
        }
      }
    }
    return getCachedSubtasks(id);
  }

  Future<void> _storeSubtasks(String choreId, List<ChoreSubtask> server) async {
    final entries = <dynamic>[for (final s in server) _encodeSubtask(s)];
    final ops = await _pendingOps(_subtaskOpTypes);
    for (final op in ops) {
      final payload = _decodePayload(op.payloadJson);
      if (payload == null || payload['choreId'] != choreId) continue;
      _applySubtaskOp(entries, op.type, payload);
    }
    await _writeSubtasks(choreId, entries);
  }

  /// Adds a subtask locally and queues its create. The returned subtask
  /// carries a `local-` id until the create syncs; later edits made with that
  /// id are retargeted.
  Future<ChoreSubtask> addSubtaskOfflineFirst(
      String choreId, String title) async {
    final cid = _resolveId(choreId);
    final localId = 'local-${_uuid.v4()}';
    final payload = {'choreId': cid, 'localId': localId, 'title': title};
    await _db.transaction(() async {
      await _patchSubtasks(
          cid, (e) => _applySubtaskOp(e, 'createChoreSubtask', payload));
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'createChoreSubtask',
        payload: payload,
        idempotencyKey: 'createChoreSubtask:$localId',
        entityType: 'choreSubtask',
        entityId: localId,
      );
    });
    _afterLocalWrite();
    final now = DateTime.now();
    return ChoreSubtask(
      id: localId,
      choreId: cid,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> toggleSubtaskOfflineFirst(
      String choreId, String subtaskId, bool completed) async {
    final cid = _resolveId(choreId);
    final sid = _resolveId(subtaskId);
    final opId = _uuid.v4();
    final payload = {'choreId': cid, 'subtaskId': sid, 'completed': completed};
    await _db.transaction(() async {
      // Each toggle sends the absolute state, so only the newest one queued
      // for this subtask needs to reach the server.
      await _db.deleteOutboxOpsByTypeAndEntity('updateChoreSubtask', sid);
      await _patchSubtasks(
          cid, (e) => _applySubtaskOp(e, 'updateChoreSubtask', payload));
      await _db.enqueueOutbox(
        id: opId,
        type: 'updateChoreSubtask',
        payload: payload,
        idempotencyKey: 'updateChoreSubtask:$opId',
        entityType: 'choreSubtask',
        entityId: sid,
      );
    });
    _afterLocalWrite();
  }

  Future<void> deleteSubtaskOfflineFirst(
      String choreId, String subtaskId) async {
    final cid = _resolveId(choreId);
    final sid = _resolveId(subtaskId);
    final payload = {'choreId': cid, 'subtaskId': sid};
    if (_isLocalId(sid)) {
      // Never reached the server: dropping its queued ops is the delete.
      await _db.transaction(() async {
        await _db.deleteOutboxOpsByTypeAndEntity('createChoreSubtask', sid);
        await _db.deleteOutboxOpsByTypeAndEntity('updateChoreSubtask', sid);
        await _patchSubtasks(
            cid, (e) => _applySubtaskOp(e, 'deleteChoreSubtask', payload));
      });
      return;
    }
    await _db.transaction(() async {
      await _patchSubtasks(
          cid, (e) => _applySubtaskOp(e, 'deleteChoreSubtask', payload));
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteChoreSubtask',
        payload: payload,
        idempotencyKey: 'deleteChoreSubtask:$sid',
        entityType: 'choreSubtask',
        entityId: sid,
      );
    });
    _afterLocalWrite();
  }

  Future<void> _patchSubtasks(
    String choreId,
    bool Function(List<dynamic> entries) patch,
  ) async {
    try {
      final row = await _db.getResponseCache(_subtasksKey(choreId));
      List<dynamic> entries;
      try {
        final decoded = row == null ? null : jsonDecode(row.bodyJson);
        entries = decoded is List ? decoded : <dynamic>[];
      } catch (_) {
        entries = <dynamic>[];
      }
      if (!patch(entries)) return;
      await _writeSubtasks(choreId, entries);
    } catch (_) {
      // Best-effort; the next load reconciles.
    }
  }

  Future<void> _writeSubtasks(String choreId, List<dynamic> entries) {
    return _db.upsertResponseCache(
      cacheKey: _subtasksKey(choreId),
      statusCode: 200,
      bodyJson: jsonEncode(entries),
    );
  }

  static bool _applySubtaskOp(
    List<dynamic> entries,
    String type,
    Map<String, dynamic> payload,
  ) {
    switch (type) {
      case 'createChoreSubtask':
        final localId = payload['localId'];
        if (localId is! String) return false;
        if (entries.any((e) => e is Map && e['id'] == localId)) return false;
        var maxPos = -1;
        for (final e in entries) {
          final pos = e is Map ? e['position'] : null;
          if (pos is int && pos > maxPos) maxPos = pos;
        }
        final now = DateTime.now().toIso8601String();
        entries.add({
          'id': localId,
          'chore_id': payload['choreId'],
          'title': payload['title'],
          'completed': false,
          'position': maxPos + 1,
          'created_at': now,
          'updated_at': now,
        });
        return true;
      case 'updateChoreSubtask':
        final id = payload['subtaskId'];
        var changed = false;
        for (final e in entries) {
          if (e is Map && e['id'] == id) {
            e['completed'] = payload['completed'] == true;
            changed = true;
          }
        }
        return changed;
      case 'deleteChoreSubtask':
        final before = entries.length;
        entries.removeWhere((e) => e is Map && e['id'] == payload['subtaskId']);
        return entries.length != before;
    }
    return false;
  }

  static Map<String, dynamic> _encodeSubtask(ChoreSubtask s) => {
        'id': s.id,
        'chore_id': s.choreId,
        'title': s.title,
        'completed': s.completed,
        'position': s.position,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': s.updatedAt.toIso8601String(),
      };

  static List<ChoreSubtask> _decodeSubtasks(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final subtasks = decoded
          .whereType<Map>()
          .map((m) => ChoreSubtask.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return subtasks;
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Called after a write has queued an op (always after its transaction).
  /// Production passes [_onLocalWrite], which only opens the sync session and
  /// remembers [groupId] for a post-drain refresh; without it (tests, direct
  /// constructions) the op drains and refreshes right away.
  void _afterLocalWrite([String? groupId]) {
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite == null) {
      unawaited(_drainAndRefresh(groupId));
      return;
    }
    if (groupId != null) _refreshAfterDrain.add(groupId);
    onLocalWrite();
  }

  /// Best-effort immediate sync: push queued ops, then pull server state.
  /// Failures are swallowed; the cache keeps the optimistic patch offline.
  Future<void> _drainAndRefresh(String? groupId) async {
    try {
      await drainOutboxOnce();
      if (groupId != null) await refreshCurrentChores(groupId);
    } catch (_) {}
  }

  /// The id a queued op should be sent with, or null when it must not be
  /// sent now.
  ///
  /// A `local-` id is never sent: the server cannot resolve it. It is either
  /// already mapped (its create synced after this op was read), still waiting
  /// for its create (dead-lettered or later in the pass — the op stays queued
  /// and follows the create), or orphaned because its create was discarded
  /// (the op is dropped; there is nothing on the server to change).
  Future<String?> _targetId(OutboxOp op, String id, String createType) async {
    if (!_isLocalId(id)) return id;
    final mapped = _idRemap[id];
    if (mapped != null) return mapped;
    final creates = await _db.getOutboxOpsByType(createType);
    if (creates.any((c) => c.entityId == id)) return null;
    await _db.deleteOutboxOp(op.id);
    return null;
  }

  static bool _isNotFound(Object e) {
    final cause = e is ApiException ? e.cause : e;
    return cause is DioException && cause.response?.statusCode == 404;
  }

  /// The drain in progress, if any. See [drainOutboxOnce].
  Future<void>? _draining;

  /// Sends queued chore and subtask ops, one drain at a time.
  ///
  /// Drains are serialised because more than one caller starts them (the
  /// coordinator, a create waiting out its sync window, a test's direct
  /// write). Two overlapping passes would both send the same create, and the
  /// second would then find its op already gone — exactly how a delete made
  /// while the create was in flight looks, so it would delete the chore the
  /// user just made.
  Future<void> drainOutboxOnce() async {
    while (_draining != null) {
      try {
        await _draining;
      } catch (_) {
        // That pass's caller handles its failure; this one starts fresh.
      }
    }
    final pass = _drainPass();
    _draining = pass;
    try {
      await pass;
    } finally {
      if (identical(_draining, pass)) _draining = null;
    }
  }

  Future<void> _drainPass() async {
    await OutboxDrainer(_db).drain(
      // Every chore and subtask op shares this pass deliberately. The drainer
      // re-reads each op fresh inside one createdAt-ordered batch, so
      // rewriting the temp id after a create lands means a completeChore (or
      // a subtask) queued against `local-x` sees the server id when its turn
      // comes. A separate pass would break that ordering.
      types: const [..._choreOpTypes, ..._subtaskOpTypes],
      handlers: {
        'createChore': (op, payload) async {
          final localId = payload['localId'] as String?;
          final rawReq = payload['request'];
          if (localId == null || rawReq is! Map) {
            await _db.deleteOutboxOp(op.id);
            return;
          }
          final Chore created;
          try {
            created = await _remote.createChore(
              CreateChoreRequest.fromJson(rawReq.cast<String, dynamic>()),
              idempotencyKey: op.idempotencyKey,
            );
          } catch (e) {
            if (_awaitingSync.contains(localId) &&
                classifyOutboxError(e) == OutboxErrorDisposition.permanent) {
              _failedCreates[localId] = e;
            }
            rethrow;
          }
          final groupId = payload['groupId'] as String?;
          _idRemap[localId] = created.id;
          await _db.rewriteOutboxPayloadIds(oldId: localId, newId: created.id);
          // Deleted on this device while the request was in flight: the
          // delete dropped the op, so the server copy is the only one left.
          final deletedMeanwhile = await _db.getOutboxOpById(op.id) == null;
          await _db.deleteOutboxOp(op.id);
          if (deletedMeanwhile) {
            await _db.enqueueOutbox(
              id: _uuid.v4(),
              type: 'deleteChore',
              payload: {'choreId': created.id, 'groupId': groupId},
              idempotencyKey: 'deleteChore:${created.id}',
              entityType: 'chore',
              entityId: created.id,
            );
            return;
          }
          if (groupId != null) {
            // Swap the id in place, so a tap between now and the next
            // refresh already targets the server chore.
            await _patchCache(groupId, (entries) {
              final entry = _entryFor(entries, localId);
              if (entry == null) return false;
              (entry['chore'] as Map)['id'] = created.id;
              return true;
            });
          }
          await _moveSubtasks(localId, created.id);
          if (_awaitingSync.contains(localId)) {
            _syncedCreates[localId] = created.id;
          }
        },
        'updateChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          final request = payload['request'];
          if (id == null) return;
          if (request is! Map) {
            await _db.deleteOutboxOp(op.id);
            return;
          }
          await _remote.updateChoreBody(id, request.cast<String, dynamic>(),
              idempotencyKey: op.idempotencyKey);
          await _db.deleteOutboxOp(op.id);
        },
        'deleteChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (id == null) return;
          try {
            await _remote.deleteChore(id, idempotencyKey: op.idempotencyKey);
          } catch (e) {
            // Already gone (another member deleted it): that is the outcome
            // the user asked for.
            if (!_isNotFound(e)) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
        },
        'completeChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (id == null) return;
          await _remote.completeChore(id, idempotencyKey: op.idempotencyKey);
          await _db.deleteOutboxOp(op.id);
        },
        'skipChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (id == null) return;
          await _remote.skipChore(
            id,
            skipReason: payload['reason'] as String?,
            idempotencyKey: op.idempotencyKey,
          );
          await _db.deleteOutboxOp(op.id);
        },
        'rescheduleChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (id == null) return;
          await _remote.rescheduleChore(
            id,
            dueDate: DateTime.parse(payload['dueDate'] as String),
            idempotencyKey: op.idempotencyKey,
          );
          await _db.deleteOutboxOp(op.id);
        },
        'undoChore': (op, payload) async {
          final id =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (id == null) return;
          await _remote.undoLastChoreExecution(id,
              idempotencyKey: op.idempotencyKey);
          await _db.deleteOutboxOp(op.id);
        },
        'createChoreSubtask': (op, payload) async {
          final localId = payload['localId'] as String?;
          final title = payload['title'] as String?;
          if (localId == null || title == null) {
            await _db.deleteOutboxOp(op.id);
            return;
          }
          final choreId =
              await _targetId(op, payload['choreId'] as String, 'createChore');
          if (choreId == null) return;
          final created = await _remote.createSubtask(choreId, title,
              idempotencyKey: op.idempotencyKey);
          _idRemap[localId] = created.id;
          await _db.rewriteOutboxPayloadIds(oldId: localId, newId: created.id);
          final deletedMeanwhile = await _db.getOutboxOpById(op.id) == null;
          await _db.deleteOutboxOp(op.id);
          if (deletedMeanwhile) {
            await _db.enqueueOutbox(
              id: _uuid.v4(),
              type: 'deleteChoreSubtask',
              payload: {'choreId': choreId, 'subtaskId': created.id},
              idempotencyKey: 'deleteChoreSubtask:${created.id}',
              entityType: 'choreSubtask',
              entityId: created.id,
            );
            return;
          }
          await _patchSubtasks(choreId, (entries) {
            var changed = false;
            for (final e in entries) {
              if (e is Map && e['id'] == localId) {
                e['id'] = created.id;
                changed = true;
              }
            }
            return changed;
          });
        },
        'updateChoreSubtask': (op, payload) async {
          final id = await _targetId(
              op, payload['subtaskId'] as String, 'createChoreSubtask');
          if (id == null) return;
          try {
            await _remote.updateSubtask(id,
                completed: payload['completed'] == true,
                idempotencyKey: op.idempotencyKey);
          } catch (e) {
            // Deleted elsewhere meanwhile; there is nothing left to tick.
            if (!_isNotFound(e)) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
        },
        'deleteChoreSubtask': (op, payload) async {
          final id = await _targetId(
              op, payload['subtaskId'] as String, 'createChoreSubtask');
          if (id == null) return;
          try {
            await _remote.deleteSubtask(id, idempotencyKey: op.idempotencyKey);
          } catch (e) {
            if (!_isNotFound(e)) rethrow;
          }
          await _db.deleteOutboxOp(op.id);
        },
      },
    );
    if (_refreshAfterDrain.isEmpty) return;
    final groups = _refreshAfterDrain.toList();
    _refreshAfterDrain.clear();
    for (final groupId in groups) {
      try {
        await refreshCurrentChores(groupId);
      } catch (_) {
        // Best-effort; SSE or the next screen open reconciles.
      }
    }
  }

  /// Re-keys the stored subtasks of a chore created offline to its server id,
  /// so subtasks added before the chore synced stay visible under it.
  Future<void> _moveSubtasks(String localChoreId, String serverChoreId) async {
    try {
      final key = _subtasksKey(localChoreId);
      final row = await _db.getResponseCache(key);
      if (row == null) return;
      await _db.upsertResponseCache(
        cacheKey: _subtasksKey(serverChoreId),
        statusCode: row.statusCode,
        bodyJson: row.bodyJson.replaceAll(localChoreId, serverChoreId),
      );
      await (_db.delete(_db.responseCaches)
            ..where((t) => t.cacheKey.equals(key)))
          .go();
    } catch (_) {}
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
    if (_sseGroupId == null || event.groupId != _sseGroupId) return;
    switch (event.type) {
      case 'chore:completed':
      case 'chore:skipped':
      case 'chore:rescheduled':
        await refreshCurrentChores(_sseGroupId!);
    }
  }

  static Map<String, dynamic>? _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
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
        'next_assignee_user_id': c.nextAssigneeUserId,
      };
}
