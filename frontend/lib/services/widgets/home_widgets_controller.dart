import 'dart:async';

import '../../repositories/widget_ops_repository.dart';
import 'widget_bridge.dart';
import 'widget_credential_provisioner.dart';
import 'widget_snapshot_sync.dart';

/// Runs the app's side of home screen widgets over the app's lifecycle
/// (plans/047, stage 2):
/// - takes over the ops widgets queued, before the outbox drains;
/// - keeps the widget credential issued for the current households;
/// - keeps the widgets' snapshot current.
///
/// Every step is best effort; nothing here may hold up the app.
class HomeWidgetsController {
  HomeWidgetsController({
    required WidgetBridge bridge,
    required WidgetCredentialProvisioner provisioner,
    required WidgetSnapshotSync snapshots,
    required WidgetOpsRepository ops,
    required Future<String?> Function() currentUserId,
    required Future<List<String>> Function() householdIds,
    required bool Function() isSignedIn,
    required Future<bool> Function() sessionIsRemembered,
    Future<bool> Function(String userId)? credentialIssuedFor,
  })  : _bridge = bridge,
        _sessionIsRemembered = sessionIsRemembered,
        _isSignedIn = isSignedIn,
        _credentialIssuedFor =
            credentialIssuedFor ?? WidgetCredentialProvisioner.issuedFor,
        _provisioner = provisioner,
        _snapshots = snapshots,
        _ops = ops,
        _currentUserId = currentUserId,
        _householdIds = householdIds;

  final WidgetBridge _bridge;
  final WidgetCredentialProvisioner _provisioner;
  final WidgetSnapshotSync _snapshots;
  final WidgetOpsRepository _ops;
  final Future<String?> Function() _currentUserId;
  final Future<List<String>> Function() _householdIds;
  final bool Function() _isSignedIn;
  final Future<bool> Function() _sessionIsRemembered;

  /// Set by [start] once it knows widgets may run for this session.
  bool _enabled = false;
  final Future<bool> Function(String userId) _credentialIssuedFor;

  bool get isSupported => _bridge.isSupported;

  /// Signed in, on a cold start or after sign-in. The credential request
  /// goes first: it is also the first proof that a restored session is still
  /// alive, and a dead one signs out (and clears the widgets) before
  /// anything is imported.
  ///
  /// A session the person chose not to keep ("Remember me" off, for a shared
  /// phone) ends when the app does, so it gets no widget credential: widgets
  /// would otherwise keep showing and changing the household afterwards.
  Future<void> start() async {
    if (!isSupported || !_isSignedIn()) return;
    if (!await _sessionIsRemembered()) {
      _enabled = false;
      await _bridge.clearAll();
      return;
    }
    _enabled = true;
    await ensureCredential();
    await importOps();
    if (_isSignedIn()) await _snapshots.refreshNow();
  }

  /// Back in the foreground, after [importOps] (which the caller runs first
  /// so widget taps made meanwhile are in the outbox before it drains).
  Future<void> onResumed() async {
    if (!_enabled || !_isSignedIn()) return;
    await ensureCredential();
    if (_isSignedIn()) _snapshots.schedule();
  }

  /// Leaving the app: write the freshest snapshot while the network is ours.
  void onPaused() {
    if (!_enabled || !_isSignedIn()) return;
    unawaited(_snapshots.refreshNow());
  }

  /// Something the widgets show changed: a drained outbox, a live update, a
  /// household joined or left.
  void onDataChanged() {
    if (_enabled && _isSignedIn()) _snapshots.schedule();
  }

  Future<void> onHouseholdsChanged() async {
    if (!_enabled || !_isSignedIn()) return;
    await ensureCredential();
    _snapshots.schedule();
  }

  /// Moves the native queue into the outbox, but only for the person the
  /// widgets' credential was issued to: ops left from another account, or
  /// from before this install ever issued one, are not theirs to send.
  Future<int> importOps() async {
    if (!_enabled || !_isSignedIn()) return 0;
    try {
      final userId = await _currentUserId();
      if (userId == null || !await _credentialIssuedFor(userId)) return 0;
      if (!_isSignedIn()) return 0;
      return await _ops.importPending();
    } catch (_) {
      return 0;
    }
  }

  Future<void> ensureCredential() async {
    if (!_enabled || !_isSignedIn()) return;
    try {
      final userId = await _currentUserId();
      if (userId == null) return;
      final households = await _householdIds();
      final issued =
          await _provisioner.ensure(userId: userId, householdIds: households);
      if (issued) unawaited(_bridge.requestRefresh());
    } catch (_) {
      // Offline or signed out mid-flight: the next resume tries again.
    }
  }
}
