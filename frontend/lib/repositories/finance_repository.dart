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

  bool _isDraining = false;

  FinanceRepository({
    required AppDatabase db,
    required FinanceService remote,
    Uuid? uuid,
    bool autoSync = true,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync;

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
      await _db.clearExpensesForGroup(groupId);
    }
    await _db.upsertExpensesRows(expenses.map(_toExpensesRow));
    if (summary != null) {
      await _db.upsertFinanceSummary(
          groupId: groupId, summaryJson: summary.toJson());
    }
    return expenses.length;
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

    await _db.upsertExpensesRows([_toExpensesRow(local)]);
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createExpense',
      payload: {
        'tempId': tempId,
        'request': req.toJson(),
      },
      idempotencyKey: 'createExpense:$tempId',
      entityType: 'expense',
      entityId: tempId,
    );

    if (_autoSync) unawaited(drainOutboxOnce());
    return local;
  }

  Future<api.Expense> updateExpenseOfflineFirst(
      String expenseId, api.UpdateExpenseRequest req) async {
    // Optimistic patch from current cached row if present.
    final existingRows = await (_db.select(_db.expensesTable)
          ..where((t) => t.id.equals(expenseId)))
        .get();
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
      await _db.upsertExpensesRows([_toExpensesRow(patched)]);
    }

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'updateExpense',
      payload: {
        'expenseId': expenseId,
        'patch': req.toJson(),
      },
      idempotencyKey:
          'updateExpense:$expenseId:${DateTime.now().toIso8601String()}',
      entityType: 'expense',
      entityId: expenseId,
    );

    if (_autoSync) unawaited(drainOutboxOnce());

    final row = (await (_db.select(_db.expensesTable)
          ..where((t) => t.id.equals(expenseId)))
        .getSingleOrNull());
    return row == null
        ? throw const NotFoundException('Expense not found')
        : _toExpense(row);
  }

  Future<void> deleteExpenseOfflineFirst(String expenseId) async {
    await (_db.delete(_db.expensesTable)..where((t) => t.id.equals(expenseId)))
        .go();

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'deleteExpense',
      payload: {'expenseId': expenseId},
      idempotencyKey: 'deleteExpense:$expenseId',
      entityType: 'expense',
      entityId: expenseId,
    );

    if (_autoSync) unawaited(drainOutboxOnce());
  }

  Future<void> drainOutboxOnce() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      await OutboxDrainer(_db).drain(
        types: const ['createExpense', 'updateExpense', 'deleteExpense'],
        handlers: {
          'createExpense': (op, payload) => _syncCreateExpense(op.id, payload),
          'updateExpense': (op, payload) => _syncUpdateExpense(op.id, payload),
          'deleteExpense': (op, payload) => _syncDeleteExpense(op.id, payload),
        },
      );
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _syncCreateExpense(
      String opId, Map<String, dynamic> payload) async {
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

    final created = await _remote.createExpense(req);
    await (_db.delete(_db.expensesTable)..where((t) => t.id.equals(tempId)))
        .go();
    await _db.upsertExpensesRows([_toExpensesRow(created)]);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdateExpense(
      String opId, Map<String, dynamic> payload) async {
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
    );

    final updated = await _remote.updateExpense(expenseId, req);
    await _db.upsertExpensesRows([_toExpensesRow(updated)]);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDeleteExpense(
      String opId, Map<String, dynamic> payload) async {
    final expenseId = payload['expenseId'] as String?;
    if (expenseId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.deleteExpense(expenseId);
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
    );
  }
}
