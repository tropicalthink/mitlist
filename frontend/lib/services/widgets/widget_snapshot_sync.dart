import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../response_cache_interceptor.dart';
import 'widget_bridge.dart';

/// Where an unconfigured widget, and the "Add item" app icon shortcut, point:
/// the snapshot's `defaults` (plans/047, C1).
class WidgetDefaults {
  const WidgetDefaults({this.householdId, this.listId});
  final String? householdId;
  final String? listId;
}

/// Keeps the widgets' snapshot current while the app runs. The snapshot
/// always comes from the server (`GET /widget/snapshot`, fetched here with
/// the session), so it covers every household, not only the ones this
/// device has cached, and is never older than what the widgets already show.
///
/// [schedule] coalesces bursts (a drained outbox, a run of live updates)
/// into one fetch; [refreshNow] fetches at once.
class WidgetSnapshotSync {
  WidgetSnapshotSync({
    required Dio dio,
    required WidgetBridge bridge,
    this.debounce = const Duration(seconds: 2),
  })  : _dio = dio,
        _bridge = bridge;

  final Dio _dio;
  final WidgetBridge _bridge;
  final Duration debounce;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _again = false;

  final _defaults = StreamController<WidgetDefaults>.broadcast();

  /// The defaults of every snapshot written.
  Stream<WidgetDefaults> get defaults => _defaults.stream;

  void schedule() {
    if (!_bridge.isSupported) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(refreshNow()));
  }

  /// Fetches and writes the snapshot. Failures are swallowed: offline, the
  /// widgets keep what they have and native code retries on its own.
  Future<void> refreshNow() {
    if (!_bridge.isSupported) return Future.value();
    _timer?.cancel();
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    return _inFlight = _refresh().whenComplete(() {
      _inFlight = null;
      if (_again) {
        _again = false;
        schedule();
      }
    });
  }

  Future<void> _refresh() async {
    try {
      final response = await _dio.get<String>(
        '/widget/snapshot',
        options: Options(
          responseType: ResponseType.plain,
          // A cached copy could be older than what the widgets show.
          extra: {ResponseCacheInterceptor.noCacheExtra: true},
        ),
      );
      final body = response.data;
      if (body == null || body.isEmpty) return;
      final defaults = _parseDefaults(body);
      if (defaults == null) return;
      await _bridge.writeSnapshot(body);
      if (!_defaults.isClosed) _defaults.add(defaults);
    } catch (_) {
      // Best effort.
    }
  }

  static WidgetDefaults? _parseDefaults(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['version'] is! int) return null;
      final defaults = decoded['defaults'];
      if (defaults is! Map) return const WidgetDefaults();
      return WidgetDefaults(
        householdId: defaults['household_id'] as String?,
        listId: defaults['list_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_defaults.close());
  }
}
