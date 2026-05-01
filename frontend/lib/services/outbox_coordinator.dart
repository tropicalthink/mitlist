import 'dart:async';

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
  void start() {
    _connectivity.onStatusChange.listen((online) {
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
  Future<void> drain() async {
    if (_isDraining) return;
    final online = await _connectivity.isOnline();
    if (!online) {
      _logger.i('Offline; skipping outbox drain');
      return;
    }
    _isDraining = true;
    try {
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

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, drain);
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}
