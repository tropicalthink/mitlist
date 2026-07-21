import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Connectivity state manager.
///
/// `connectivity_plus` only reports the OS network *interface* state — a
/// captive-portal/hotel wifi or a dead uplink reads as "connected" even though
/// no request can reach the server. That produced the offline/syncing banner
/// flicker and pointless drain attempts that immediately time out.
///
/// So [isOnline] gates the interface check behind a real **reachability probe**
/// (a short-timeout `GET /healthz`). The probe result is cached briefly so
/// rapid callers (the 3s banner poll, the coordinator) don't each fire a ping,
/// and status-change events are debounced + probed before reporting online.
///
/// A probe failure is *soft* evidence: it can equally mean a genuinely dead
/// uplink, a radio still waking from a low-power state, or an OS that suspended
/// our network while the app sat in the background. Reporting offline off a
/// single soft failure is how the app ended up showing a stale "you are
/// offline" bar on resume, so [isOnline] requires [_failureThreshold]
/// consecutive probe failures before it will report offline. Losing the
/// interface outright stays instant — that one is hard evidence from the OS.
class ConnectivityService {
  final Connectivity _connectivity;
  final Future<bool> Function() _probe;
  final Duration _cacheTtl;
  final Duration _debounce;
  final int _failureThreshold;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;
  final _controller = StreamController<bool>.broadcast();

  bool? _cachedReachable;
  DateTime? _cachedAt;
  int _consecutiveFailures = 0;
  bool _reported = true;

  ConnectivityService({
    Connectivity? connectivity,
    Future<bool> Function()? reachabilityProbe,
    Duration cacheTtl = const Duration(seconds: 8),
    Duration debounce = const Duration(milliseconds: 600),
    int failureThreshold = 2,
  })  : _connectivity = connectivity ?? Connectivity(),
        _probe = reachabilityProbe ?? _defaultProbe,
        _cacheTtl = cacheTtl,
        _debounce = debounce,
        _failureThreshold = failureThreshold {
    _sub = _connectivity.onConnectivityChanged.listen(_onInterfaceChange);
  }

  static const _probeTimeout = Duration(seconds: 6);

  /// One long-lived client for probes. Building a fresh [Dio] per probe forced
  /// a full DNS + TCP + TLS handshake every time, which on a cold radio (right
  /// after the app is resumed) regularly costs more than the whole timeout
  /// budget — so the probe failed for reasons that had nothing to do with
  /// connectivity. Reusing one client keeps the connection warm.
  static final Dio _probeClient = Dio(BaseOptions(
    connectTimeout: _probeTimeout,
    receiveTimeout: _probeTimeout,
    sendTimeout: _probeTimeout,
    // Any status is "reachable" — even 401/500 proves the server answered.
    validateStatus: (_) => true,
  ));

  /// Default probe: a cheap `GET /healthz`. Any non-error HTTP response means
  /// the server is reachable; a timeout/socket error means it is not (the real
  /// signal we care about, unlike interface state).
  static Future<bool> _defaultProbe() async {
    try {
      await _probeClient.getUri(Uri.parse('${ApiConfig.baseUrl}/healthz'));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _interfaceUp(List<ConnectivityResult> results) => results.any((r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet);

  void _onInterfaceChange(List<ConnectivityResult> results) {
    _invalidateCache();
    _debounceTimer?.cancel();
    if (!_interfaceUp(results)) {
      // Losing the interface is unambiguous — report offline immediately.
      _controller.add(false);
      return;
    }
    // Gaining an interface is not the same as having internet. Debounce (links
    // flap) then probe before announcing we're back online.
    _debounceTimer = Timer(_debounce, () async {
      final online = await isOnline();
      if (!_controller.isClosed) _controller.add(online);
    });
  }

  void _invalidateCache() {
    _cachedReachable = null;
    _cachedAt = null;
  }

  /// Emits whenever connectivity changes. A `true` event has been verified by a
  /// reachability probe; a `false` event fires as soon as the interface drops.
  Stream<bool> get onStatusChange => _controller.stream;

  /// True only when an interface is up AND the server is actually reachable.
  ///
  /// The probe result is cached for [_cacheTtl] so back-to-back callers share
  /// one ping. Pass [forceProbe] to bypass the cache.
  ///
  /// Probe failures are damped: see the class doc for why a single one is not
  /// enough to report offline.
  Future<bool> isOnline({bool forceProbe = false}) async {
    if (forceProbe) _invalidateCache();

    final results = await _connectivity.checkConnectivity();
    if (!_interfaceUp(results)) {
      // Hard evidence from the OS — report immediately, and drop the streak so
      // the interface coming back is evaluated from a clean slate.
      _invalidateCache();
      _consecutiveFailures = 0;
      _reported = false;
      return false;
    }

    if (!forceProbe &&
        _cachedReachable != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      // Replay the last verdict without touching the streak, so hysteresis
      // counts independent probes rather than poll ticks sharing one result.
      return _reported;
    }

    final reachable = await _probe();
    _cachedReachable = reachable;
    _cachedAt = DateTime.now();
    return _record(reachable);
  }

  /// Applies hysteresis to a fresh probe result.
  ///
  /// The asymmetry is deliberate: a wrong "offline" is expensive (the user
  /// stares at a banner contradicted by a working network) while a wrong
  /// "online" is cheap (one outbox drain attempt fails and is retried). So we
  /// clear the streak on the first success but need [_failureThreshold]
  /// failures in a row to flip the other way.
  bool _record(bool reachable) {
    if (reachable) {
      _consecutiveFailures = 0;
      return _reported = true;
    }
    _consecutiveFailures++;
    return _reported = _consecutiveFailures < _failureThreshold;
  }

  /// Drops the cached probe result and the failure streak, so the next
  /// [isOnline] re-evaluates from scratch.
  ///
  /// Call this when the app returns to the foreground. Any probe that ran while
  /// backgrounded may have failed only because the OS suspended the app's
  /// network — Xiaomi's HyperOS and similar skins do this aggressively — and
  /// such a result says nothing about connectivity now. Without this the stale
  /// `false` outlived the resume and painted an offline bar over a working app.
  void reset() {
    _invalidateCache();
    _consecutiveFailures = 0;
    _reported = true;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}
