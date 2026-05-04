import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/outbox_coordinator.dart';
import 'chore_provider.dart';
import 'finance_provider.dart';
import 'list_provider.dart';
import 'pinwall_provider.dart';
import 'recipe_provider.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  ref.onDispose(svc.dispose);
  return svc;
});

final outboxCoordinatorProvider = FutureProvider<OutboxCoordinator>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final listRepo = await ref.watch(listRepositoryProvider.future);
  final financeRepo = await ref.watch(financeRepositoryProvider.future);
  final recipeRepo = await ref.watch(recipeRepositoryProvider.future);
  final choreRepo = await ref.watch(choreRepositoryProvider.future);
  final pinwallRepo = await ref.watch(pinwallRepositoryProvider.future);

  final coordinator = OutboxCoordinator(
    db: db,
    connectivity: connectivity,
    listRepo: listRepo,
    financeRepo: financeRepo,
    recipeRepo: recipeRepo,
    choreRepo: choreRepo,
    pinwallRepo: pinwallRepo,
  );

  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Status of the offline outbox queue.
enum OutboxStatus { online, syncing, offline, error, conflict }

class OutboxState {
  final OutboxStatus status;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;

  const OutboxState({
    required this.status,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
  });

  bool get isOffline => status == OutboxStatus.offline;
  bool get isSyncing => status == OutboxStatus.syncing;
  bool get hasErrors => status == OutboxStatus.error || failedCount > 0;
  bool get hasConflicts => status == OutboxStatus.conflict || conflictCount > 0;
}

/// Watches connectivity and outbox queue to produce a unified sync status.
final outboxStateProvider = StreamProvider<OutboxState>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);

  Future<OutboxState> computeState() async {
    final online = await connectivity.isOnline();
    final pending = await db.outboxPendingCount();
    final failed = await db.outboxFailedCount();
    final conflicts = await db.conflictCount();

    if (conflicts > 0) {
      return OutboxState(
        status: OutboxStatus.conflict,
        pendingCount: pending,
        failedCount: failed,
        conflictCount: conflicts,
      );
    }
    if (!online) {
      return OutboxState(
        status: OutboxStatus.offline,
        pendingCount: pending + failed,
        failedCount: failed,
      );
    }
    if (failed > 0) {
      return OutboxState(
        status: OutboxStatus.error,
        pendingCount: pending,
        failedCount: failed,
      );
    }
    if (pending > 0) {
      return OutboxState(
        status: OutboxStatus.syncing,
        pendingCount: pending,
        failedCount: 0,
      );
    }
    return const OutboxState(status: OutboxStatus.online);
  }

  // Yield immediately, then poll every 3 seconds.
  // This is lightweight (a COUNT query) and keeps the banner responsive
  // as the outbox drains or fails.
  yield await computeState();

  await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
    if (ref.state.hasError) break;
    yield await computeState();
  }
});
