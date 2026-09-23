import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_models.dart' as api;
import '../services/finance_service.dart';
import '../storage/app_database.dart';
import '../exceptions.dart';
import 'outbox_drainer.dart';

class FinanceRepository {
  final AppDatabase _db;
  final FinanceService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [_afterLocalWrite].
  final void Function()? _onLocalWrite;

  bool _isDraining = false;

  FinanceRepository({
    required AppDatabase db,
    required FinanceService remote,
    Uuid? uuid,
    bool autoSync = true,
    void Function()? onLocalWrite,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync,
        _onLocalWrite = onLocalWrite;

  // ---------------------------------------------------------------------------
  // Read (cache-first)
  // ---------------------------------------------------------------------------

  Stream<List<api.Expense>> watchExpensesByGroup(String groupId) {
    return _db
        .watchExpensesByGroup(groupId)
        .map((rows) => rows.map(_toExpense).toList());
  }

  Future<List<api.Expense>> getExpensesByGroupOnce(String groupId) async {
    final rows = await _db.getExpensesByGroupOnce(groupId);
    return rows.map(_toExpense).toList();
  }

  Stream<api.FinanceSummary?> watchSummaryByGroup(String groupId) {
    return _db.watchFinanceSummary(groupId).map((row) {
      if (row == null) return null;
      try {
        return api.FinanceSummary.fromJson(
            (jsonDecode(row.summaryJson) as Map).cast<String, dynamic>());
      } catch (_) {
        return null;
      }
    });
  }

  Future<int> refreshGroup(String groupId,
      {int limit = 50, int offset = 0}) async {
    final expenses =
        await _remote.listExpenses(groupId, limit: limit, offset: offset);
    api.FinanceSummary? summary;
    if (offset == 0) {
      summary = await _remote.getFinanceSummary(groupId);
      // A server snapshot must not erase optimistic rows while their outbox
      // operations are still pending. Keep the pre-refresh rows long enough
      // to re-apply queued edits, then replace the snapshot atomically.
      final previous = await _db.getExpensesByGroupOnce(groupId);
      final pending = await _pendingExpenses(
        groupId,
        previous.map(_toExpense).toList(growable: false),
      );
      await _db.transaction(() async {
        await _db.clearExpensesForGroup(groupId);
        await _db.upsertExpensesRows(expenses.map(_toExpensesRow));
        await _db.upsertExpensesRows(pending.map(_toExpensesRow));
      });
    } else {
      await _db.upsertExpensesRows(expenses.map(_toExpensesRow));
    }
    if (summary != null) {
      await _db.upsertFinanceSummary(
          groupId: groupId, summaryJson: summary.toJson());
    }
    return expenses.length;
  }

  Future<List<api.Expense>> _pendingExpenses(
    String groupId,
    List<api.Expense> previous,
  ) async {
    final byId = {for (final expense in previous) expense.id: expense};
    final deleted = <String>{};
    final ops = await _db.getOutboxOpsByType('deleteExpense');
    for (final op in ops) {
      final payload = jsonDecode(op.payloadJson);
      if (payload is Map && payload['expenseId'] is String) {
        deleted.add(payload['expenseId'] as String);
      }
    }
    for (final op in await _db.getOutboxOpsByType('createExpense')) {
      try {
        final payload =
            (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
        final request = (payload['request'] as Map).cast<String, dynamic>();
        if (request['group_id'] != groupId) continue;
        final id = payload['tempId'] as String;
        byId[id] = api.Expense(
          id: id,
          groupId: groupId,
          payerId: request['payer_id'] as String,
          amount: request['amount'] as int,
          baseAmount:
              request['base_amount'] as int? ?? request['amount'] as int,
          fxRate: (request['fx_rate'] as num?)?.toDouble() ?? 1.0,
          description: request['description'] as String,
          category: request['category'] as String? ?? 'other',
          currency: request['currency'] as String? ?? 'USD',
          notes: request['notes'] as String? ?? '',
          date: DateTime.parse(request['date'] as String),
          createdAt: DateTime.now(),
        );
      } catch (_) {}
    }
    for (final op in await _db.getOutboxOpsByType('updateExpense')) {
      try {
        final payload =
            (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
        final id = payload['expenseId'] as String;
        final old = byId[id];
        if (old == null || old.groupId != groupId) continue;
        final patch = (payload['patch'] as Map).cast<String, dynamic>();
        byId[id] = api.Expense(
          id: old.id,
          groupId: old.groupId,
          payerId: patch['payer_id'] as String? ?? old.payerId,
          amount: patch['amount'] as int? ?? old.amount,
          baseAmount: patch['base_amount'] as int? ?? old.baseAmount,
          fxRate: (patch['fx_rate'] as num?)?.toDouble() ?? old.fxRate,
          description: patch['description'] as String? ?? old.description,
          category: patch['category'] as String? ?? old.category,
          currency: patch['currency'] as String? ?? old.currency,
          notes: patch['notes'] as String? ?? old.notes,
          date: patch['date'] == null
              ? old.date
              : DateTime.parse(patch['date'] as String),
          createdAt: old.createdAt,
          updatedAt: old.updatedAt,
        );
      } catch (_) {}
    }
    return byId.values
        .where((expense) =>
            expense.groupId == groupId && !deleted.contains(expense.id))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Settlements
  //
  // Split deliberately by semantics. *Recording* a settlement is a claim about
  // something that already happened in the real world, so it queues like any
  // other write. *Approving* one is not — see `respondToSettlement` on the
  // service, which stays online-only on purpose.
  //
  // A recorded settlement is `pending` until the counterparty confirms, and
  // pending settlements do not move any balance. The optimistic row therefore
  // appears in the settlements list and nowhere else.
  // ---------------------------------------------------------------------------

  Stream<List<api.Settlement>> watchSettlements(String groupId) {
    return _db
        .watchSettlements(groupId)
        .map((row) => _decodeSettlements(row?.settlementsJson));
  }

  Future<List<api.Settlement>> getSettlementsOnce(String groupId) async {
    final row = await _db.getSettlementsOnce(groupId);
    return _decodeSettlements(row?.settlementsJson);
  }

  /// Fetches settlements and persists them, re-splicing any still-queued local
  /// ones. Returns the cache instead of throwing when the network fails, so the
  /// tab keeps rendering offline.
  Future<List<api.Settlement>> loadSettlements(String groupId) async {
    try {
      final fresh = await _remote.listSettlements(groupId);
      final merged = await _withPendingSettlements(groupId, fresh);
      await _db.upsertSettlements(
        groupId: groupId,
        settlementsJson: jsonEncode(merged.map((s) => s.toJson()).toList()),
      );
      return merged;
    } catch (_) {
      return getSettlementsOnce(groupId);
    }
  }

  /// Re-adds queued local settlements onto a server snapshot. Same reasoning as
  /// the chore cache: the blob is overwritten wholesale, so without this a
  /// refresh landing before the drain would erase a settlement the user just
  /// recorded while its op is still in the outbox.
  Future<List<api.Settlement>> _withPendingSettlements(
    String groupId,
    List<api.Settlement> server,
  ) async {
    final ops = await _db.getOutboxOpsByType('createSettlement');
    if (ops.isEmpty) return server;

    final merged = [...server];
    for (final op in ops) {
      try {
        final payload =
            (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
        if (payload['groupId'] != groupId) continue;
        final local = api.Settlement.fromJson(
          (payload['settlement'] as Map).cast<String, dynamic>(),
        );
        if (merged.any((s) => s.id == local.id)) continue;
        merged.add(local);
      } catch (_) {
        // Malformed ops are the drainer's problem.
      }
    }
    return merged;
  }

  /// Queues a settlement and shows it immediately as pending.
  Future<api.Settlement> recordSettlementOfflineFirst({
    required String groupId,
    required api.CreateSettlementRequest req,
    required String createdBy,
  }) async {
    final local = api.Settlement(
      id: 'local-${_uuid.v4()}',
      groupId: groupId,
      fromUserId: req.fromUserId,
      toUserId: req.toUserId,
      amount: req.amount,
      status: api.SettlementStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createSettlement',
      payload: {
        'groupId': groupId,
        'request': req.toJson(),
        'settlement': local.toJson(),
      },
      idempotencyKey: 'createSettlement:${local.id}',
      entityType: 'settlement',
      entityId: local.id,
    );

    final current = await getSettlementsOnce(groupId);
    await _db.upsertSettlements(
      groupId: groupId,
      settlementsJson:
          jsonEncode([...current, local].map((s) => s.toJson()).toList()),
    );
    _afterLocalWrite();
    return local;
  }

  /// Drops a queued settlement that has not synced yet (the offline "cancel").
  ///
  /// Cancelling an unsynced settlement must never POST — there is nothing on
  /// the server to cancel — so this removes the op and the optimistic row.
  Future<void> cancelLocalSettlement(
      String groupId, String settlementId) async {
    for (final op in await _db.getOutboxOpsByType('createSettlement')) {
      if (op.entityId == settlementId) await _db.deleteOutboxOp(op.id);
    }
    final remaining = (await getSettlementsOnce(groupId))
        .where((s) => s.id != settlementId)
        .toList();
    await _db.upsertSettlements(
      groupId: groupId,
      settlementsJson: jsonEncode(remaining.map((s) => s.toJson()).toList()),
    );
  }

  List<api.Settlement> _decodeSettlements(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => api.Settlement.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Writes (offline-first with outbox)
  // ---------------------------------------------------------------------------

  Future<api.Expense> createExpenseOfflineFirst(
      api.CreateExpenseRequest req) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();

    final local = api.Expense(
      id: tempId,
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      baseAmount: req.baseAmount,
      fxRate: req.fxRate,
      description: req.description,
      category: req.category,
      currency: req.currency,
      notes: req.notes,
      date: req.date,
      createdAt: now,
    );

    await _db.transaction(() async {
      await _db.upsertExpensesRows([_toExpensesRow(local)]);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'createExpense',
        payload: {'tempId': tempId, 'request': req.toJson()},
        idempotencyKey: 'createExpense:$tempId',
        entityType: 'expense',
        entityId: tempId,
      );
    });

    _afterLocalWrite();
    return local;
  }

  Future<api.Expense> updateExpenseOfflineFirst(
      String expenseId, api.UpdateExpenseRequest req) async {
    // Optimistic patch from current cached row if present.
    final existingRows = await (_db.select(_db.expensesTable)
          ..where((t) => t.id.equals(expenseId)))
        .get();

    // Optimistic-concurrency base: the server updated_at this edit was based
    // on. Skipped when an edit is already queued for this expense — that chain
    // is all ours, so there is no foreign server base to guard against — and
    // when the row has no known server version (created locally, or cached
    // before the column existed), where the edit falls back to last-write-wins.
    final hasPendingEdit =
        await _db.pendingOpCountForEntity('updateExpense', expenseId) > 0;
    final base = existingRows.isEmpty ? null : existingRows.first.updatedAt;
    final expectedUpdatedAt = hasPendingEdit ? null : base;

    if (existingRows.isNotEmpty) {
      final e = _toExpense(existingRows.first);
      final patched = api.Expense(
        id: e.id,
        groupId: e.groupId,
        payerId: req.payerId ?? e.payerId,
        amount: req.amount ?? e.amount,
        baseAmount: req.baseAmount ?? e.baseAmount,
        fxRate: req.fxRate ?? e.fxRate,
        description: req.description ?? e.description,
        category: req.category ?? e.category,
        currency: req.currency ?? e.currency,
        notes: req.notes ?? e.notes,
        date: req.date ?? e.date,
        createdAt: e.createdAt,
      );
      await _db.transaction(() async {
        await _db.upsertExpensesRows([_toExpensesRow(patched)]);
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'updateExpense',
          payload: {
            'expenseId': expenseId,
            'patch': req.toJson(),
            if (expectedUpdatedAt != null)
              'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
          },
          idempotencyKey:
              'updateExpense:$expenseId:${DateTime.now().toIso8601String()}',
          entityType: 'expense',
          entityId: expenseId,
        );
      });
    } else {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'updateExpense',
        payload: {
          'expenseId': expenseId,
          'patch': req.toJson(),
          if (expectedUpdatedAt != null)
            'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
        },
        idempotencyKey:
            'updateExpense:$expenseId:${DateTime.now().toIso8601String()}',
        entityType: 'expense',
        entityId: expenseId,
      );
    }

    _afterLocalWrite();

    final row = (await (_db.select(_db.expensesTable)
          ..where((t) => t.id.equals(expenseId)))
        .getSingleOrNull());
    return row == null
        ? throw const NotFoundException('Expense not found')
        : _toExpense(row);
  }

  Future<void> deleteExpenseOfflineFirst(String expenseId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.expensesTable)
            ..where((t) => t.id.equals(expenseId)))
          .go();
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteExpense',
        payload: {'expenseId': expenseId},
        idempotencyKey: 'deleteExpense:$expenseId',
        entityType: 'expense',
        entityId: expenseId,
      );
    });

    _afterLocalWrite();
  }

  /// Called after a write has queued an op (always after its transaction).
  /// Production passes [_onLocalWrite], which only opens the sync session;
  /// without it (tests, direct constructions) the op drains right away.
  void _afterLocalWrite() {
    if (!_autoSync) return;
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce());
    }
  }

  Future<void> drainOutboxOnce() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      await OutboxDrainer(_db).drain(
        types: const [
          'createExpense',
          'updateExpense',
          'deleteExpense',
          'createSettlement',
        ],
        handlers: {
          'createExpense': (op, payload) =>
              _syncCreateExpense(op.id, payload, op.idempotencyKey),
          'updateExpense': (op, payload) =>
              _syncUpdateExpense(op.id, payload, op.idempotencyKey),
          'deleteExpense': (op, payload) =>
              _syncDeleteExpense(op.id, payload, op.idempotencyKey),
          'createSettlement': (op, payload) =>
              _syncCreateSettlement(op.id, payload, op.idempotencyKey),
        },
      );
    } finally {
      _isDraining = false;
    }
  }

  /// Sends a queued settlement, then swaps the optimistic row for the server's.
  ///
  /// The server assigns the real id and is the authority on status, so the
  /// local `local-` row is replaced rather than merged — that is also what
  /// makes the counterparty's confirm/decline reachable, since those act on a
  /// server id.
  Future<void> _syncCreateSettlement(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final groupId = payload['groupId'] as String?;
    final requestRaw = payload['request'];
    final localRaw = payload['settlement'];
    if (groupId == null || requestRaw is! Map || localRaw is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final localId = localRaw['id'] as String?;
    final json = requestRaw.cast<String, dynamic>();

    final created = await _remote.createGroupSettlement(
      groupId,
      api.CreateSettlementRequest(
        groupId: groupId,
        fromUserId: json['from_user_id'] as String,
        toUserId: json['to_user_id'] as String,
        amount: (json['amount'] as num).toInt(),
      ),
      idempotencyKey: idempotencyKey,
    );

    final updated = [
      for (final s in await getSettlementsOnce(groupId))
        if (s.id != localId) s,
      created,
    ];
    await _db.upsertSettlements(
      groupId: groupId,
      settlementsJson: jsonEncode(updated.map((s) => s.toJson()).toList()),
    );
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncCreateExpense(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final tempId = payload['tempId'] as String?;
    final requestRaw = payload['request'];
    if (tempId == null || requestRaw is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final req = api.CreateExpenseRequest(
      groupId: requestRaw['group_id'] as String,
      payerId: requestRaw['payer_id'] as String,
      amount: requestRaw['amount'] as int,
      baseAmount: requestRaw['base_amount'] == null
          ? requestRaw['amount'] as int
          : requestRaw['base_amount'] as int,
      fxRate: (requestRaw['base_amount'] == null)
          ? 1.0
          : (requestRaw['fx_rate'] as num?)?.toDouble() ?? 1.0,
      description: requestRaw['description'] as String,
      category: requestRaw['category'] as String? ?? 'other',
      currency: requestRaw['currency'] as String? ?? 'USD',
      notes: requestRaw['notes'] as String? ?? '',
      date: DateTime.parse(requestRaw['date'] as String),
      splitUserIds: ((requestRaw['split_user_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      splitMode: requestRaw['split_mode'] as String? ?? 'equal',
      splits: const [],
    );

    final created =
        await _remote.createExpense(req, idempotencyKey: idempotencyKey);
    await (_db.delete(_db.expensesTable)..where((t) => t.id.equals(tempId)))
        .go();
    await _db.upsertExpensesRows([_toExpensesRow(created)]);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdateExpense(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final expenseId = payload['expenseId'] as String?;
    final patch = payload['patch'];
    if (expenseId == null || patch is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final req = api.UpdateExpenseRequest(
      payerId: patch['payer_id'] as String?,
      amount: patch['amount'] as int?,
      baseAmount: patch['base_amount'] as int?,
      fxRate: (patch['fx_rate'] as num?)?.toDouble(),
      description: patch['description'] as String?,
      category: patch['category'] as String?,
      currency: patch['currency'] as String?,
      notes: patch['notes'] as String?,
      date: patch['date'] == null
          ? null
          : DateTime.parse(patch['date'] as String),
      // Carried on the op, not in the patch: the base belongs to the queued
      // edit, and "keep mine" rewrites it to the server's current value.
      expectedUpdatedAt: payload['expectedUpdatedAt'] == null
          ? null
          : DateTime.parse(payload['expectedUpdatedAt'] as String),
    );

    final updated = await _remote.updateExpense(expenseId, req,
        idempotencyKey: idempotencyKey);
    await _db.upsertExpensesRows([_toExpensesRow(updated)]);
    await _db.deleteOutboxOp(opId);
  }

  // ---------------------------------------------------------------------------
  // Conflict resolution (mirrors ListRepository)
  // ---------------------------------------------------------------------------

  /// "Use theirs": overwrite the local row with the server's version.
  Future<void> resolveConflictAcceptServer(Conflict conflict) async {
    try {
      final server = (jsonDecode(conflict.serverPayloadJson) as Map)
          .cast<String, dynamic>();
      await _db
          .upsertExpensesRows([_toExpensesRow(api.Expense.fromJson(server))]);
    } catch (_) {
      // If the server payload can't be parsed, still clear the conflict.
    }
    await _db.resolveConflict(conflict.id);
  }

  /// "Keep mine": re-apply the local edit on top of the server's version by
  /// re-enqueueing the op with the server's current updated_at as the base, so
  /// it no longer conflicts.
  Future<void> resolveConflictKeepLocal(Conflict conflict) async {
    try {
      if (conflict.entityType == 'updateExpense') {
        final local = (jsonDecode(conflict.localPayloadJson) as Map)
            .cast<String, dynamic>();
        final server = (jsonDecode(conflict.serverPayloadJson) as Map)
            .cast<String, dynamic>();
        local['expectedUpdatedAt'] = server['updated_at'];
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'updateExpense',
          payload: local,
          entityType: 'expense',
          entityId: local['expenseId'] as String?,
        );
      }
    } catch (_) {
      // Best-effort; the conflict is cleared regardless so it doesn't linger.
    }
    await _db.resolveConflict(conflict.id);
    _afterLocalWrite();
  }

  Future<void> _syncDeleteExpense(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final expenseId = payload['expenseId'] as String?;
    if (expenseId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.deleteExpense(expenseId, idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------

  ExpensesTableCompanion _toExpensesRow(api.Expense e) {
    return ExpensesTableCompanion(
      id: Value(e.id),
      groupId: Value(e.groupId),
      payerId: Value(e.payerId),
      amount: Value(e.amount),
      baseAmount: Value(e.baseAmount),
      fxRate: Value(e.fxRate),
      description: Value(e.description),
      category: Value(e.category),
      currency: Value(e.currency),
      notes: Value(e.notes),
      date: Value(e.date),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }

  api.Expense _toExpense(ExpensesTableData row) {
    return api.Expense(
      id: row.id,
      groupId: row.groupId,
      payerId: row.payerId,
      amount: row.amount,
      baseAmount: row.baseAmount,
      fxRate: row.fxRate,
      description: row.description,
      category: row.category,
      currency: row.currency,
      notes: row.notes,
      date: row.date,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
