import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';

import '../repositories/chore_repository.dart';
import '../repositories/finance_repository.dart';
import '../repositories/list_repository.dart';
import '../repositories/pinwall_repository.dart';
import '../repositories/recipe_repository.dart';
import '../storage/app_database.dart';
import 'connectivity_service.dart';

/// Global outbox coordinator that drains pending writes across all domains.
///
/// Each repository owns its own sync logic; this class just orchestrates
/// draining in the right order and respects connectivity.
class OutboxCoordinator {
  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final ListRepository _listRepo;
  final FinanceRepository _financeRepo;
  final RecipeRepository _recipeRepo;
  final ChoreRepository _choreRepo;
  final PinwallRepository _pinwallRepo;
  final Logger _logger = Logger();

  Timer? _retryTimer;
  bool _isDraining = false;
  StreamSubscription<bool>? _connectivitySub;

  OutboxCoordinator({
    required AppDatabase db,
    required ConnectivityService connectivity,
    required ListRepository listRepo,
    required FinanceRepository financeRepo,
    required RecipeRepository recipeRepo,
    required ChoreRepository choreRepo,
    required PinwallRepository pinwallRepo,
  })  : _db = db,
        _connectivity = connectivity,
        _listRepo = listRepo,
        _financeRepo = financeRepo,
        _recipeRepo = recipeRepo,
        _choreRepo = choreRepo,
        _pinwallRepo = pinwallRepo;

  /// Start listening to connectivity changes and drain when back online.
  ///
  /// Idempotent: cancels any existing subscription before re-subscribing.
  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (online) {
        _logger.i('Connectivity restored; draining outbox');
        drain();
      }
    });
    // Initial drain if already online.
    _connectivity.isOnline().then((online) {
      if (online) drain();
    });
  }

  /// Drain all pending outbox operations once.
  ///
  /// Safe to call multiple times; internally guarded by [_isDraining].
  Future<void> drain({bool force = false}) async {
    if (_isDraining) return;
    // Set the flag BEFORE the first await so concurrent synchronous callers
    // are blocked even while isOnline() is still resolving.
    _isDraining = true;
    try {
      // [force] is used by an explicit user "Retry" — attempt even if the
      // reachability probe is being conservative; the user knows they're online.
      if (!force) {
        final online = await _connectivity.isOnline();
        if (!online) {
          _logger.i('Offline; skipping outbox drain');
          return;
        }
      }
      // Drain in dependency order: lists first (other entities may reference them)
      await _listRepo.drainOutboxOnce();
      await _recipeRepo.drainOutboxOnce();
      await _financeRepo.drainOutboxOnce();
      await _choreRepo.drainOutboxOnce();
      await _pinwallRepo.drainOutboxOnce();

      // Schedule a follow-up in case new ops were queued during drain
      final remaining = await _db.outboxCount();
      if (remaining > 0) {
        _scheduleRetry(const Duration(seconds: 5));
      }
    } catch (e) {
      _logger.e('Outbox drain failed: $e');
      _scheduleRetry(const Duration(seconds: 10));
    } finally {
      _isDraining = false;
    }
  }

  /// Re-arms dead-lettered ops and drains. Plain [drain] deliberately skips ops
  /// at the failure threshold, so the banner's "Retry" must reset them first —
  /// otherwise the button is a no-op for the very failures it offers to retry.
  Future<void> retryFailed() async {
    await _db.resetFailedOutboxOps();
    await drain(force: true);
  }

  /// Re-arms a single dead-lettered op and drains.
  Future<void> retryOp(String opId) async {
    await _db.resetFailedOutboxOps(id: opId);
    await drain(force: true);
  }

  /// Discards a single failed op (the "give up on this change" path).
  ///
  /// For a failed *create* the server never accepted the row, so the optimistic
  /// local entity is deleted — otherwise it lingers as ghost data the server
  /// will never have. For a failed update/delete we cannot reconstruct the
  /// server's value locally, so we drop the op and re-fetch the affected
  /// collection from the server (best-effort) to reconcile the local row.
  Future<void> discardFailedOp(String opId) async {
    final op = await _db.getOutboxOpById(opId);
    if (op == null) return;

    final entityType = op.entityType;
    final entityId = op.entityId;
    final isCreate = op.type.startsWith('create');

    if (isCreate && entityType != null && entityId != null) {
      await _db.deleteLocalEntity(entityType, entityId);
    }
    await _db.deleteOutboxOp(opId);

    if (!isCreate) {
      await _reconcileAfterDiscard(op);
    }
  }

  /// Best-effort server re-fetch so a discarded update/delete stops showing the
  /// user's abandoned local edit. Swallows errors (offline is fine — a later
  /// refresh/SSE reconciles).
  Future<void> _reconcileAfterDiscard(OutboxOp op) async {
    try {
      final payload =
          (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
      switch (op.entityType) {
        case 'listItem':
          final listId = payload['listId'] as String?;
          if (listId != null) await _listRepo.refreshItems(listId);
      }
    } catch (_) {
      // Reconciliation is best-effort; the op is already gone.
    }
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, drain);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _retryTimer?.cancel();
  }
}
