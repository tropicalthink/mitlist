import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';
import 'billing_provider.dart';
import 'chore_provider.dart';
import 'finance_provider.dart';
import 'group_provider.dart';
import 'list_provider.dart';
import 'outbox_provider.dart';
import 'pinwall_provider.dart';

/// Progress of the cold-start refresh. [failed] means at least one pull did
/// not land — the cache on screen may be stale, and the banner offers a retry.
enum InitialSyncStatus { idle, syncing, done, failed }

/// Forces a server pull of the active household once per sign-in, so a cold
/// start never quietly serves yesterday's cache.
///
/// Screens keep their cache-first rendering — this runs behind them and the
/// drift streams push fresh rows into whatever is visible. What it adds over
/// the per-screen refreshes is scope (everything, not just the screen the user
/// happens to open) and honesty: those refreshes swallow failures when a cache
/// exists, while this one reports [InitialSyncStatus.failed] to the banner and
/// retries by itself when connectivity returns.
class InitialSyncNotifier extends StateNotifier<InitialSyncStatus> {
  InitialSyncNotifier(this._ref) : super(InitialSyncStatus.idle) {
    _connectivitySub =
        _ref.read(connectivityServiceProvider).onStatusChange.listen((online) {
      if (online && state == InitialSyncStatus.failed) unawaited(retry());
    });
  }

  final Ref _ref;
  StreamSubscription<bool>? _connectivitySub;

  /// Runs the refresh if it has not run yet this sign-in. Safe to call from
  /// every bootstrap path; only the first call does work.
  Future<void> start() async {
    if (state != InitialSyncStatus.idle) return;
    await _run();
  }

  /// Explicit re-run: the banner tap, or connectivity coming back.
  Future<void> retry() async {
    if (state == InitialSyncStatus.syncing) return;
    await _run();
  }

  /// Forgets the completed run so the next sign-in syncs again.
  void reset() => state = InitialSyncStatus.idle;

  Future<void> _run() async {
    state = InitialSyncStatus.syncing;
    var failures = 0;
    try {
      // Membership first — it validates the persisted active-group choice.
      final groupNotifier = _ref.read(currentGroupIdProvider.notifier);
      await groupNotifier.ensureLoaded();
      if (!await _guard(() async =>
          (await _ref.read(groupRepositoryProvider.future)).refreshGroups())) {
        failures++;
      }

      final groupId = _ref.read(currentGroupIdProvider);
      if (groupId != null) {
        final results = await Future.wait<bool>([
          _guard(() async => (await _ref.read(listRepositoryProvider.future))
              .refreshLists(groupId)),
          _guard(() async => (await _ref.read(choreRepositoryProvider.future))
              .refreshCurrentChores(groupId)),
          _guard(() async => (await _ref.read(financeRepositoryProvider.future))
              .refreshGroup(groupId)),
          _guard(() async => (await _ref.read(pinwallRepositoryProvider.future))
              .refreshPosts(groupId)),
        ]);
        failures += results.where((ok) => !ok).length;
      }

      // Billing has no local cache table; dropping the provider refetches.
      _ref.invalidate(billingStatusProvider);

      if (!mounted) return;
      state = failures == 0 ? InitialSyncStatus.done : InitialSyncStatus.failed;
    } catch (_) {
      if (mounted) state = InitialSyncStatus.failed;
    }
  }

  Future<bool> _guard(Future<Object?> Function() task) async {
    try {
      await task();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}

final initialSyncProvider =
    StateNotifierProvider<InitialSyncNotifier, InitialSyncStatus>(
  (ref) => InitialSyncNotifier(ref),
);
