import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_receipt_models.dart';
import '../models/finance_models.dart' as api;
import '../services/api_error_mapper.dart';
import '../services/finance_service.dart';
import '../services/response_cache_interceptor.dart';
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

  /// The drain pass in flight, so a caller that needs its result (the
  /// receipt upload waiting for a server id) can await it instead of being
  /// turned away while another pass is already running.
  Future<void>? _draining;

  /// Temp id → server id for creates that synced during this session. A
  /// screen or sheet opened before the sync still holds the temp id; every
  /// follow-up write resolves through this so it targets the real row instead
  /// of queueing an op against an id the server has never heard of.
  final Map<String, String> _syncedIds = {};

  /// Households whose balances a drained op changed during the current pass.
  /// Their summary is re-fetched once at the end of the pass, so the balance
  /// card catches up with expenses recorded offline without a manual refresh.
  final Set<String> _summaryDirty = {};

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

  /// The server id [id] ended up with if it was a temp id that has synced,
  /// otherwise [id] itself.
  String resolveId(String id) => _syncedIds[id] ?? id;

  /// True while [expenseId] exists only on this device (its create is still
  /// queued). Such an expense has no server-side splits or receipts yet.
  Future<bool> isPendingExpense(String expenseId) async =>
      await _db.pendingOpCountForEntity('createExpense', resolveId(expenseId)) >
      0;

  /// One-shot read of the cached balances (no stream subscription to manage).
  Future<api.FinanceSummary?> getSummaryOnce(String groupId) async {
    final row = await (_db.select(_db.financeSummaries)
          ..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return api.FinanceSummary.fromJson(
          (jsonDecode(row.summaryJson) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<int> refreshGroup(String groupId,
      {int limit = 50, int offset = 0}) async {
    // Live only: the Drift table *is* the offline copy, so a stale cached body
    // must never replace it (it would drop expenses synced since).
    final expenses = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listExpenses(groupId, limit: limit, offset: offset));
    api.FinanceSummary? summary;
    if (offset == 0) {
      summary = await _remote.getFinanceSummary(groupId);
      // A server snapshot must not erase optimistic rows while their outbox
      // operations are still pending, nor resurrect rows the user deleted
      // offline. The merge reads only local state, so it runs inside the
      // transaction: a write queued mid-refresh can't fall between the read
      // and the replace.
      await _db.transaction(() async {
        final previous = await _db.getExpensesByGroupOnce(groupId);
        final merged = await _mergePending(
          groupId,
          server: expenses,
          previous: previous.map(_toExpense).toList(growable: false),
        );
        await _db.clearExpensesForGroup(groupId);
        await _db.upsertExpensesRows(merged.map(_toExpensesRow));
      });
    } else {
      final previous = await _db.getExpensesByGroupOnce(groupId);
      final merged = await _mergePending(
        groupId,
        server: expenses,
        previous: previous.map(_toExpense).toList(growable: false),
      );
      await _db.upsertExpensesRows(merged.map(_toExpensesRow));
    }
    if (summary != null) {
      await _db.upsertFinanceSummary(
          groupId: groupId, summaryJson: summary.toJson());
    }
    return expenses.length;
  }

  /// Server rows with the still-queued local writes laid back over them:
  /// queued creates are added, queued edits re-applied (on the fresh server
  /// version where there is one), and queued deletes filtered out.
  ///
  /// Only rows a pending op touches survive from [previous]; everything else
  /// comes from the server, so other members' edits and deletions land.
  Future<List<api.Expense>> _mergePending(
    String groupId, {
    required List<api.Expense> server,
    required List<api.Expense> previous,
  }) async {
    final byId = {for (final expense in server) expense.id: expense};
    final previousById = {for (final expense in previous) expense.id: expense};
    final deleted = <String>{};
    for (final op in await _db.getOutboxOpsByType('deleteExpense')) {
      final payload = _decode(op.payloadJson);
      final id = payload?['expenseId'];
      if (id is String) deleted.add(id);
    }
    for (final op in await _db.getOutboxOpsByType('createExpense')) {
      final payload = _decode(op.payloadJson);
      final request = payload?['request'];
      final id = payload?['tempId'];
      if (request is! Map || id is! String) continue;
      if (request['group_id'] != groupId) continue;
      try {
        byId[id] = _expenseFromCreate(
          id,
          request.cast<String, dynamic>(),
          createdAt: previousById[id]?.createdAt ?? op.createdAt,
        );
      } catch (_) {
        // Malformed ops are the drainer's problem.
      }
    }
    for (final op in await _db.getOutboxOpsByType('updateExpense')) {
      final payload = _decode(op.payloadJson);
      final id = payload?['expenseId'];
      final patch = payload?['patch'];
      if (id is! String || patch is! Map) continue;
      final old = byId[id] ?? previousById[id];
      if (old == null || old.groupId != groupId) continue;
      try {
        byId[id] = _applyExpensePatch(old, patch.cast<String, dynamic>());
      } catch (_) {}
    }
    return byId.values
        .where((expense) =>
            expense.groupId == groupId && !deleted.contains(expense.id))
        .toList(growable: false);
  }

  /// [expense] with every still-queued edit for it applied, oldest first.
  Future<api.Expense> _withQueuedEdits(api.Expense expense) async {
    var result = expense;
    for (final op in await _db.getOutboxOpsByType('updateExpense')) {
      final payload = _decode(op.payloadJson);
      final patch = payload?['patch'];
      if (payload?['expenseId'] != expense.id || patch is! Map) continue;
      try {
        result = _applyExpensePatch(result, patch.cast<String, dynamic>());
      } catch (_) {}
    }
    return result;
  }

  api.Expense _expenseFromCreate(
    String id,
    Map<String, dynamic> request, {
    required DateTime createdAt,
  }) {
    final amount = (request['amount'] as num).toInt();
    return api.Expense(
      id: id,
      groupId: request['group_id'] as String,
      payerId: request['payer_id'] as String,
      amount: amount,
      baseAmount: (request['base_amount'] as num?)?.toInt() ?? amount,
      fxRate: (request['fx_rate'] as num?)?.toDouble() ?? 1.0,
      description: request['description'] as String,
      category: request['category'] as String? ?? 'other',
      currency: request['currency'] as String? ?? 'USD',
      notes: request['notes'] as String? ?? '',
      date: DateTime.parse(request['date'] as String),
      createdAt: createdAt,
    );
  }

  api.Expense _applyExpensePatch(api.Expense old, Map<String, dynamic> patch) {
    return api.Expense(
      id: old.id,
      groupId: old.groupId,
      payerId: patch['payer_id'] as String? ?? old.payerId,
      amount: (patch['amount'] as num?)?.toInt() ?? old.amount,
      baseAmount: (patch['base_amount'] as num?)?.toInt() ?? old.baseAmount,
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
  }

  // ---------------------------------------------------------------------------
  // Expense detail (splits, receipts)
  // ---------------------------------------------------------------------------

  /// Splits for the detail sheet. An expense whose create is still queued has
  /// none on the server yet (`GET /expenses/{temp}/splits` would 404, or fail
  /// offline), so they are computed from the queued request with the same
  /// arithmetic the server will use.
  Future<List<api.Split>> loadExpenseSplits(String expenseId) async {
    final id = resolveId(expenseId);
    final create = await _pendingCreateOp('createExpense', id);
    if (create == null) return _remote.listExpenseSplits(id);
    final request = _decode(create.payloadJson)?['request'];
    if (request is! Map) return const [];
    return localExpenseSplits(
      expenseId: id,
      request: request.cast<String, dynamic>(),
      createdAt: create.createdAt,
    );
  }

  /// Receipts for the detail sheet. An unsynced expense cannot carry one yet.
  Future<List<ExpenseReceipt>> loadExpenseReceipts({
    required String groupId,
    required String expenseId,
  }) async {
    final id = resolveId(expenseId);
    if (await _pendingCreateOp('createExpense', id) != null) return const [];
    return _remote.listExpenseReceipts(groupId: groupId, expenseId: id);
  }

  /// Pushes queued money writes now and returns the server id [expenseId]
  /// ended up with, or null while it is still only on this device.
  ///
  /// For the one flow that cannot wait for the sync session: attaching a
  /// scanned receipt needs the server id, and the image is not queued.
  Future<String?> syncExpenseNow(String expenseId) async {
    if (!await isPendingExpense(expenseId)) return resolveId(expenseId);
    await drainOutboxOnce();
    if (await isPendingExpense(expenseId)) return null;
    final id = resolveId(expenseId);
    return id == expenseId ? null : id;
  }

  /// Mirrors the server's `buildSplits`: participants sorted by id, equal
  /// splits hand the remainder to the first ones, weighted splits give the
  /// last participant whatever rounding left over, and the payer's own share
  /// is born settled.
  static List<api.Split> localExpenseSplits({
    required String expenseId,
    required Map<String, dynamic> request,
    required DateTime createdAt,
  }) {
    final amount = (request['amount'] as num?)?.toInt() ?? 0;
    final total = (request['base_amount'] as num?)?.toInt() ?? amount;
    final payerId = request['payer_id'] as String? ?? '';
    final mode = (request['split_mode'] as String? ?? 'equal').toLowerCase();
    final custom = (request['splits'] as List?)
            ?.whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    final inputs = <Map<String, dynamic>>[
      if (custom.isNotEmpty)
        ...custom
      else
        for (final id in (request['split_user_ids'] as List?) ?? const [])
          {'user_id': id.toString()},
    ]..sort(
        (a, b) => (a['user_id'] as String).compareTo(b['user_id'] as String));
    if (inputs.isEmpty) return const [];

    int weightOf(Map<String, dynamic> input, String key) =>
        (input[key] as num?)?.toInt() ?? 0;
    final amounts = List<int>.filled(inputs.length, 0);
    void byWeight(String key) {
      final sum = inputs.fold<int>(0, (acc, i) => acc + weightOf(i, key));
      var assigned = 0;
      for (var i = 0; i < inputs.length; i++) {
        if (i == inputs.length - 1 || sum == 0) {
          amounts[i] = total - assigned;
          break;
        }
        amounts[i] = total * weightOf(inputs[i], key) ~/ sum;
        assigned += amounts[i];
      }
    }

    switch (mode) {
      case 'amount':
      case 'exact':
        for (var i = 0; i < inputs.length; i++) {
          amounts[i] = weightOf(inputs[i], 'amount');
        }
      case 'shares':
        byWeight('shares');
      case 'percentage':
        byWeight('percentage');
      default:
        final base = total ~/ inputs.length;
        final rem = total % inputs.length;
        for (var i = 0; i < inputs.length; i++) {
          amounts[i] = base + (i < rem ? 1 : 0);
        }
    }

    return [
      for (var i = 0; i < inputs.length; i++)
        api.Split(
          id: 'local-$expenseId-$i',
          expenseId: expenseId,
          userId: inputs[i]['user_id'] as String,
          amount: amounts[i],
          isSettled: inputs[i]['user_id'] == payerId,
          createdAt: createdAt,
        ),
    ];
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
      // Live only, like refreshGroup: the blob is the offline copy.
      final fresh = await ResponseCacheInterceptor.liveOnly(
          () => _remote.listSettlements(groupId));
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
    final cancelled = <String>{
      for (final op in await _db.getOutboxOpsByType('cancelSettlement'))
        if (op.entityId != null) op.entityId!,
    };
    if (ops.isEmpty && cancelled.isEmpty) return server;

    // A cancel still queued must not be undone by the server snapshot.
    final merged = [
      for (final s in server)
        if (!cancelled.contains(s.id)) s,
    ];
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
    final synced = _syncedIds[settlementId];
    if (synced != null) {
      // It reached the server after the screen captured its local id.
      return cancelSettlementOfflineFirst(groupId, synced);
    }
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

  /// Cancels one of the user's own settlements: removed from the list now,
  /// `DELETE` queued for the sync session. One that never synced is simply
  /// dropped — see [cancelLocalSettlement].
  Future<void> cancelSettlementOfflineFirst(
      String groupId, String settlementId) async {
    final id = resolveId(settlementId);
    if (id.startsWith('local-')) return cancelLocalSettlement(groupId, id);

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'cancelSettlement',
      payload: {'groupId': groupId, 'settlementId': id},
      idempotencyKey: 'cancelSettlement:$id',
      entityType: 'settlement',
      entityId: id,
    );
    final remaining =
        (await getSettlementsOnce(groupId)).where((s) => s.id != id).toList();
    await _db.upsertSettlements(
      groupId: groupId,
      settlementsJson: jsonEncode(remaining.map((s) => s.toJson()).toList()),
    );
    _afterLocalWrite();
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
      String requestedId, api.UpdateExpenseRequest req) async {
    final expenseId = resolveId(requestedId);
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

  Future<void> deleteExpenseOfflineFirst(String requestedId) async {
    final expenseId = resolveId(requestedId);
    final unsyncedCreate = await _pendingCreateOp('createExpense', expenseId);
    final row = await (_db.select(_db.expensesTable)
          ..where((t) => t.id.equals(expenseId)))
        .getSingleOrNull();

    await _db.transaction(() async {
      await (_db.delete(_db.expensesTable)
            ..where((t) => t.id.equals(expenseId)))
          .go();
      // Edits queued for it are moot either way.
      await _db.deleteOutboxOpsByTypeAndEntity('updateExpense', expenseId);
      if (unsyncedCreate != null) {
        // Never reached the server, so there is nothing to DELETE: dropping
        // the queued create is the whole delete. (If its POST is in flight
        // right now, `_syncCreateExpense` sees the op gone and finishes the
        // delete against the real id.)
        await _db.deleteOutboxOp(unsyncedCreate.id);
        return;
      }
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteExpense',
        payload: {
          'expenseId': expenseId,
          if (row != null) 'groupId': row.groupId,
        },
        idempotencyKey: 'deleteExpense:$expenseId',
        entityType: 'expense',
        entityId: expenseId,
      );
    });

    if (unsyncedCreate == null) _afterLocalWrite();
  }

  /// The still-queued create op of [type] for [entityId], if any.
  Future<OutboxOp?> _pendingCreateOp(String type, String entityId) async {
    for (final op in await _db.getOutboxOpsByType(type)) {
      if (op.entityId == entityId) return op;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Recurring expenses
  //
  // The server list is kept in ResponseCaches under a key of our own (no new
  // table), and queued creates / edits / deletes are laid over it on every
  // read, the same re-splice the settlements blob uses. Optimistic rows carry
  // `local-` ids until their create drains.
  // ---------------------------------------------------------------------------

  static const List<String> _recurringOpTypes = [
    'createRecurringExpense',
    'updateRecurringExpense',
    'deleteRecurringExpense',
  ];

  static String _recurringCacheKey(String groupId) =>
      'finance:recurring-expenses:$groupId';

  /// The household's recurring rules: fresh from the server when reachable,
  /// the last stored list otherwise, with queued local changes applied.
  /// Throws only when there is nothing at all to show.
  Future<List<api.RecurringExpense>> loadRecurringExpenses(
      String groupId) async {
    List<api.RecurringExpense> base;
    try {
      // Live only: our stored list is spliced on every sync, so it is newer
      // than the last raw response the API client may have kept.
      base = await ResponseCacheInterceptor.liveOnly(
          () => _remote.listRecurringExpenses(groupId));
      await _writeRecurringCache(groupId, base);
    } catch (_) {
      final cached = await _readRecurringCache(groupId);
      if (cached != null) {
        base = cached;
      } else {
        try {
          // Never stored here yet (first offline visit after an update):
          // the API client's last raw response is still better than nothing.
          base = await _remote.listRecurringExpenses(groupId);
        } catch (_) {
          // Nothing cached anywhere. Rules added on this device still show
          // instead of an error page.
          if (!await _hasPendingRecurring(groupId)) rethrow;
          base = const [];
        }
      }
    }
    return _withPendingRecurring(groupId, base);
  }

  /// Cache-only read, for painting before the network answers.
  Future<List<api.RecurringExpense>?> getRecurringExpensesOnce(
      String groupId) async {
    final cached = await _readRecurringCache(groupId);
    if (cached == null && !await _hasPendingRecurring(groupId)) return null;
    return _withPendingRecurring(groupId, cached ?? const []);
  }

  Future<api.RecurringExpense> createRecurringExpenseOfflineFirst(
      api.CreateRecurringExpenseRequest req) async {
    final local = api.RecurringExpense(
      id: 'local-${_uuid.v4()}',
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      description: req.description,
      category: req.category,
      currency: req.currency ?? 'USD',
      frequency: req.frequency,
      nextDue: req.nextDue,
      isActive: req.isActive,
      createdAt: DateTime.now(),
      splitMode: req.splitMode,
      splitInputs: req.splitInputs,
    );
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createRecurringExpense',
      payload: {
        'groupId': req.groupId,
        'tempId': local.id,
        'request': req.toJson(),
        'recurring': local.toJson(),
      },
      idempotencyKey: 'createRecurringExpense:${local.id}',
      entityType: 'recurringExpense',
      entityId: local.id,
    );
    _afterLocalWrite();
    return local;
  }

  Future<void> updateRecurringExpenseOfflineFirst(
    String groupId,
    String requestedId,
    api.UpdateRecurringExpenseRequest req,
  ) async {
    final id = resolveId(requestedId);
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'updateRecurringExpense',
      payload: {'groupId': groupId, 'id': id, 'patch': req.toJson()},
      idempotencyKey:
          'updateRecurringExpense:$id:${DateTime.now().toIso8601String()}',
      entityType: 'recurringExpense',
      entityId: id,
    );
    _afterLocalWrite();
  }

  Future<void> deleteRecurringExpenseOfflineFirst(
      String groupId, String requestedId) async {
    final id = resolveId(requestedId);
    final unsyncedCreate = await _pendingCreateOp('createRecurringExpense', id);
    await _db.transaction(() async {
      await _db.deleteOutboxOpsByTypeAndEntity('updateRecurringExpense', id);
      if (unsyncedCreate != null) {
        await _db.deleteOutboxOp(unsyncedCreate.id);
        return;
      }
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteRecurringExpense',
        payload: {'groupId': groupId, 'id': id},
        idempotencyKey: 'deleteRecurringExpense:$id',
        entityType: 'recurringExpense',
        entityId: id,
      );
    });
    if (unsyncedCreate == null) _afterLocalWrite();
  }

  Future<bool> _hasPendingRecurring(String groupId) async {
    for (final type in _recurringOpTypes) {
      for (final op in await _db.getOutboxOpsByType(type)) {
        if (_decode(op.payloadJson)?['groupId'] == groupId) return true;
      }
    }
    return false;
  }

  Future<List<api.RecurringExpense>> _withPendingRecurring(
    String groupId,
    List<api.RecurringExpense> base,
  ) async {
    final ops = <OutboxOp>[
      for (final type in _recurringOpTypes)
        ...await _db.getOutboxOpsByType(type),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (ops.isEmpty) return base;

    final byId = {for (final r in base) r.id: r};
    for (final op in ops) {
      final payload = _decode(op.payloadJson);
      if (payload == null || payload['groupId'] != groupId) continue;
      try {
        switch (op.type) {
          case 'createRecurringExpense':
            final local = api.RecurringExpense.fromJson(
                (payload['recurring'] as Map).cast<String, dynamic>());
            byId[local.id] = local;
          case 'updateRecurringExpense':
            final id = payload['id'] as String;
            final old = byId[id];
            if (old == null) continue;
            byId[id] = _applyRecurringPatch(
                old, (payload['patch'] as Map).cast<String, dynamic>());
          case 'deleteRecurringExpense':
            byId.remove(payload['id']);
        }
      } catch (_) {
        // Malformed ops are the drainer's problem.
      }
    }
    return byId.values.toList(growable: false);
  }

  api.RecurringExpense _applyRecurringPatch(
      api.RecurringExpense old, Map<String, dynamic> patch) {
    return api.RecurringExpense(
      id: old.id,
      groupId: old.groupId,
      payerId: patch['payer_id'] as String? ?? old.payerId,
      amount: (patch['amount'] as num?)?.toInt() ?? old.amount,
      description: patch['description'] as String? ?? old.description,
      category: patch['category'] as String? ?? old.category,
      currency: patch['currency'] as String? ?? old.currency,
      frequency: patch['frequency'] as String? ?? old.frequency,
      nextDue: patch['next_due'] == null
          ? old.nextDue
          : DateTime.parse(patch['next_due'] as String),
      isActive: patch['is_active'] as bool? ?? old.isActive,
      createdAt: old.createdAt,
      splitMode: patch['split_mode'] as String? ?? old.splitMode,
      splitInputs: patch['split_inputs'] is List
          ? _recurringSplitInputs(patch['split_inputs'] as List)
          : old.splitInputs,
    );
  }

  static List<api.RecurringSplitInput> _recurringSplitInputs(List raw) => raw
      .whereType<Map>()
      .map((m) => api.RecurringSplitInput.fromJson(m.cast<String, dynamic>()))
      .toList();

  Future<List<api.RecurringExpense>?> _readRecurringCache(
      String groupId) async {
    final row = await _db.getResponseCache(_recurringCacheKey(groupId));
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.bodyJson);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((m) => api.RecurringExpense.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRecurringCache(
      String groupId, List<api.RecurringExpense> items) {
    return _db.upsertResponseCache(
      cacheKey: _recurringCacheKey(groupId),
      statusCode: 200,
      bodyJson: jsonEncode(items.map((r) => r.toJson()).toList()),
    );
  }

  /// Applies [change] to the stored server list, when there is one.
  Future<void> _editRecurringCache(
    String groupId,
    List<api.RecurringExpense> Function(List<api.RecurringExpense>) change,
  ) async {
    final cached = await _readRecurringCache(groupId) ?? const [];
    await _writeRecurringCache(groupId, change(cached));
  }

  // ---------------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------------

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

  /// Runs one drain pass, or joins the one already running.
  Future<void> drainOutboxOnce() {
    final running = _draining;
    if (running != null) return running;
    final pass = _drainPass().whenComplete(() => _draining = null);
    _draining = pass;
    return pass;
  }

  Future<void> _drainPass() async {
    await OutboxDrainer(_db).drain(
      types: const [
        'createExpense',
        'updateExpense',
        'deleteExpense',
        'createSettlement',
        'cancelSettlement',
        ..._recurringOpTypes,
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
        'cancelSettlement': (op, payload) =>
            _syncCancelSettlement(op.id, payload, op.idempotencyKey),
        'createRecurringExpense': (op, payload) =>
            _syncCreateRecurring(op.id, payload, op.idempotencyKey),
        'updateRecurringExpense': (op, payload) =>
            _syncUpdateRecurring(op.id, payload, op.idempotencyKey),
        'deleteRecurringExpense': (op, payload) =>
            _syncDeleteRecurring(op.id, payload, op.idempotencyKey),
      },
    );
    await _refreshDirtySummaries();
  }

  /// Re-fetches the balances of households a drained op changed. Best-effort:
  /// the next screen load refreshes them anyway.
  Future<void> _refreshDirtySummaries() async {
    if (_summaryDirty.isEmpty) return;
    final groups = {..._summaryDirty};
    _summaryDirty.clear();
    for (final groupId in groups) {
      try {
        final summary = await _remote.getFinanceSummary(groupId);
        await _db.upsertFinanceSummary(
            groupId: groupId, summaryJson: summary.toJson());
      } catch (_) {}
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
    if (localId != null) _syncedIds[localId] = created.id;

    if (await _db.getOutboxOpById(opId) == null) {
      // Cancelled while the POST was in flight: the server has it now, so
      // finish the user's cancel against the real id.
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'cancelSettlement',
        payload: {'groupId': groupId, 'settlementId': created.id},
        idempotencyKey: 'cancelSettlement:${created.id}',
        entityType: 'settlement',
        entityId: created.id,
      );
      _afterLocalWrite();
      return;
    }

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

  Future<void> _syncCancelSettlement(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final settlementId = payload['settlementId'] as String?;
    if (settlementId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _ignoringNotFound(() =>
        _remote.cancelSettlement(settlementId, idempotencyKey: idempotencyKey));
    final groupId = payload['groupId'];
    if (groupId is String) _summaryDirty.add(groupId);
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
      // Exact / shares / percent splits ride along; dropping them would
      // record a custom split as an equal one.
      splits: ((requestRaw['splits'] as List?) ?? const [])
          .whereType<Map>()
          .map((s) => api.CreateExpenseSplitRequest(
                userId: s['user_id'] as String,
                amount: (s['amount'] as num?)?.toInt(),
                shares: (s['shares'] as num?)?.toInt(),
                percentage: (s['percentage'] as num?)?.toInt(),
              ))
          .toList(),
    );

    final created =
        await _remote.createExpense(req, idempotencyKey: idempotencyKey);
    _syncedIds[tempId] = created.id;
    _summaryDirty.add(created.groupId);

    if (await _db.getOutboxOpById(opId) == null) {
      // Deleted locally while the POST was in flight: the server has it now,
      // so finish the user's delete against the real id.
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteExpense',
        payload: {'expenseId': created.id, 'groupId': created.groupId},
        idempotencyKey: 'deleteExpense:${created.id}',
        entityType: 'expense',
        entityId: created.id,
      );
      _afterLocalWrite();
      return;
    }

    await _db.transaction(() async {
      await (_db.delete(_db.expensesTable)..where((t) => t.id.equals(tempId)))
          .go();
      // Follow-up ops queued against the temp id now target the real one.
      await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
      await _db.rewriteOutboxEntityIds(oldId: tempId, newId: created.id);
      await _db.deleteOutboxOp(opId);
      // Edits still queued keep showing until they drain too.
      await _db.upsertExpensesRows(
          [_toExpensesRow(await _withQueuedEdits(created))]);
    });
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
    _summaryDirty.add(updated.groupId);
    await _db.deleteOutboxOp(opId);
    // Deleted locally since: don't bring the row back.
    if (await _db.pendingOpCountForEntity('deleteExpense', expenseId) > 0) {
      return;
    }
    await _db
        .upsertExpensesRows([_toExpensesRow(await _withQueuedEdits(updated))]);
  }

  Future<void> _syncCreateRecurring(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final groupId = payload['groupId'] as String?;
    final tempId = payload['tempId'] as String?;
    final raw = payload['request'];
    if (groupId == null || tempId == null || raw is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final json = raw.cast<String, dynamic>();
    final created = await _remote.createRecurringExpense(
      api.CreateRecurringExpenseRequest(
        groupId: json['group_id'] as String,
        payerId: json['payer_id'] as String,
        amount: (json['amount'] as num).toInt(),
        description: json['description'] as String,
        category: json['category'] as String? ?? 'other',
        currency: json['currency'] as String?,
        frequency: json['frequency'] as String? ?? 'monthly',
        nextDue: DateTime.parse(json['next_due'] as String),
        isActive: json['is_active'] as bool? ?? true,
        splitMode: json['split_mode'] as String? ?? 'payer_only',
        splitInputs:
            _recurringSplitInputs((json['split_inputs'] as List?) ?? const []),
      ),
      idempotencyKey: idempotencyKey,
    );
    _syncedIds[tempId] = created.id;

    if (await _db.getOutboxOpById(opId) == null) {
      // Deleted locally while the POST was in flight.
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteRecurringExpense',
        payload: {'groupId': groupId, 'id': created.id},
        idempotencyKey: 'deleteRecurringExpense:${created.id}',
        entityType: 'recurringExpense',
        entityId: created.id,
      );
      _afterLocalWrite();
      return;
    }

    await _editRecurringCache(
        groupId,
        (items) => [
              for (final r in items)
                if (r.id != tempId && r.id != created.id) r,
              created,
            ]);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.rewriteOutboxEntityIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdateRecurring(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final groupId = payload['groupId'] as String?;
    final id = payload['id'] as String?;
    final patch = payload['patch'];
    if (groupId == null || id == null || patch is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final json = patch.cast<String, dynamic>();
    final updated = await _remote.updateRecurringExpense(
      id,
      api.UpdateRecurringExpenseRequest(
        payerId: json['payer_id'] as String?,
        amount: (json['amount'] as num?)?.toInt(),
        description: json['description'] as String?,
        category: json['category'] as String?,
        currency: json['currency'] as String?,
        frequency: json['frequency'] as String?,
        nextDue: json['next_due'] == null
            ? null
            : DateTime.parse(json['next_due'] as String),
        isActive: json['is_active'] as bool?,
        splitMode: json['split_mode'] as String?,
        splitInputs: json['split_inputs'] is List
            ? _recurringSplitInputs(json['split_inputs'] as List)
            : null,
      ),
      idempotencyKey: idempotencyKey,
    );
    await _editRecurringCache(
        groupId,
        (items) => [
              for (final r in items) r.id == id ? updated : r,
            ]);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDeleteRecurring(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final groupId = payload['groupId'] as String?;
    final id = payload['id'] as String?;
    if (groupId == null || id == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _ignoringNotFound(() =>
        _remote.deleteRecurringExpense(id, idempotencyKey: idempotencyKey));
    await _editRecurringCache(
        groupId,
        (items) => [
              for (final r in items)
                if (r.id != id) r
            ]);
    await _db.deleteOutboxOp(opId);
  }

  /// Runs a queued delete, treating "already gone" as done: a replay after a
  /// lost response, or someone else deleting it first, both end where the
  /// user wanted.
  Future<void> _ignoringNotFound(Future<void> Function() call) async {
    try {
      await call();
    } on ApiException catch (e) {
      if (e.cause?.response?.statusCode != 404) rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
  }

  static Map<String, dynamic>? _decode(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return null;
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
    await _ignoringNotFound(
        () => _remote.deleteExpense(expenseId, idempotencyKey: idempotencyKey));
    final groupId = payload['groupId'];
    if (groupId is String) _summaryDirty.add(groupId);
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
