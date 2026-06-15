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
class ConnectivityService {
  final Connectivity _connectivity;
  final Future<bool> Function() _probe;
  final Duration _cacheTtl;
  final Duration _debounce;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;
  final _controller = StreamController<bool>.broadcast();

  bool? _cachedReachable;
  DateTime? _cachedAt;

  ConnectivityService({
    Connectivity? connectivity,
    Future<bool> Function()? reachabilityProbe,
    Duration cacheTtl = const Duration(seconds: 8),
    Duration debounce = const Duration(milliseconds: 600),
  })  : _connectivity = connectivity ?? Connectivity(),
        _probe = reachabilityProbe ?? _defaultProbe,
        _cacheTtl = cacheTtl,
        _debounce = debounce {
    _sub = _connectivity.onConnectivityChanged.listen(_onInterfaceChange);
  }

  /// Default probe: a cheap `GET /healthz` with a short timeout. Any non-error
  /// HTTP response means the server is reachable; a timeout/socket error means
  /// it is not (the real signal we care about, unlike interface state).
  static Future<bool> _defaultProbe() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
        // Any status is "reachable" — even 401/500 proves the server answered.
        validateStatus: (_) => true,
      ));
      await dio.getUri(Uri.parse('${ApiConfig.baseUrl}/healthz'));
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
  Future<bool> isOnline({bool forceProbe = false}) async {
    final results = await _connectivity.checkConnectivity();
    if (!_interfaceUp(results)) {
      _invalidateCache();
      return false;
    }

    if (!forceProbe &&
        _cachedReachable != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedReachable!;
    }

    final reachable = await _probe();
    _cachedReachable = reachable;
    _cachedAt = DateTime.now();
    return reachable;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}
