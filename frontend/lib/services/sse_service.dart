import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/api_config.dart';
import 'token_refresh_coordinator.dart';
import 'token_store.dart';

class _SseUnauthorizedException implements Exception {}

/// A single SSE event parsed from the server stream.
class SseEvent {
  final String type;
  final String groupId;
  final Map<String, dynamic> payload;

  const SseEvent({
    required this.type,
    required this.groupId,
    required this.payload,
  });

  factory SseEvent.fromJson(Map<String, dynamic> json) {
    return SseEvent(
      type: json['type'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Connects to the backend SSE endpoint and exposes a broadcast stream of
/// [SseEvent]s for a single group.
///
/// Usage:
///   final svc = SseService();
///   await svc.connect(groupId);
///   svc.events.listen((e) { ... });
///
/// Call [dispose] when the stream is no longer needed (e.g. screen removed).
class SseService {
  final Logger _log = Logger();
  final TokenStore _tokenStore;
  final TokenRefreshCoordinator _refreshCoordinator;
  final StreamController<SseEvent> _controller =
      StreamController<SseEvent>.broadcast();

  HttpClient? _httpClient;
  bool _disposed = false;
  String? _currentGroupId;
  int _generation = 0;

  SseService([TokenStore? tokenStore, TokenRefreshCoordinator? refreshCoordinator])
      : _tokenStore = tokenStore ?? SecureTokenStore.shared,
        _refreshCoordinator =
            refreshCoordinator ?? TokenRefreshCoordinator.shared;

  Stream<SseEvent> get events => _controller.stream;

  /// Connect (or reconnect) to the SSE stream for [groupId].
  Future<void> connect(String groupId) async {
    if (_currentGroupId == groupId) return;
    _currentGroupId = groupId;
    _httpClient?.close(force: true);
    _httpClient = null;
    final gen = ++_generation;
    unawaited(_startLoop(groupId, gen));
  }

  Future<void> _startLoop(String groupId, int gen) async {
    var backoff = const Duration(seconds: 2);

    while (!_disposed && _generation == gen) {
      try {
        await _connectOnce(groupId, gen);
      } on _SseUnauthorizedException {
        if (_disposed || _generation != gen) break;
        _log.i('SSE got 401 — attempting token refresh');
        final refreshed = await _tryRefreshToken();
        if (!refreshed) {
          _log.w('Token refresh failed; stopping SSE loop');
          break;
        }
        // New token saved — retry immediately without backoff.
      } catch (e) {
        if (_disposed || _generation != gen) break;
        _log.w('SSE disconnected, retrying in ${backoff.inSeconds}s: $e');
        await Future.delayed(backoff);
        backoff = Duration(seconds: (backoff.inSeconds * 2).clamp(2, 60));
      }
    }
  }

  Future<bool> _tryRefreshToken() async {
    // Delegate to the shared single-flight coordinator so an SSE refresh and a
    // concurrent Dio refresh collapse onto one request against one rotated
    // token, rather than racing and invalidating each other.
    final pair = await _refreshCoordinator.refresh();
    return pair != null;
  }

  Future<void> _connectOnce(String groupId, int gen) async {
    final token = await _tokenStore.getAccessToken();
    if (token == null) return;

    final baseUrl = kIsWeb ? ApiConfig.baseUrl : ApiConfig.baseUrl;
    final uri = Uri.parse(
      '$baseUrl${ApiConfig.apiPrefix}/events?group_id=$groupId',
    );

    final client = HttpClient();
    _httpClient = client;

    final request = await client.getUrl(uri);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Accept', 'text/event-stream');
    request.headers.set('Cache-Control', 'no-cache');

    final response = await request.close();
    if (response.statusCode == 401) {
      throw _SseUnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw HttpException('SSE returned ${response.statusCode}');
    }

    // Reset backoff on successful connect.
    _log.i('SSE connected for group $groupId');

    final buffer = StringBuffer();
    await for (final chunk in response.transform(utf8.decoder)) {
      if (_disposed || _generation != gen) return;
      buffer.write(chunk);

      // SSE events are separated by double newlines.
      final raw = buffer.toString();
      final parts = raw.split('\n\n');
      for (var i = 0; i < parts.length - 1; i++) {
        _parseAndEmit(parts[i].trim());
      }
      buffer.clear();
      buffer.write(parts.last);
    }
  }

  void _parseAndEmit(String raw) {
    if (raw.isEmpty || raw.startsWith(':')) return; // comment / keep-alive
    for (final line in raw.split('\n')) {
      if (line.startsWith('data:')) {
        final json = line.substring(5).trim();
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          if (!_controller.isClosed) {
            _controller.add(SseEvent.fromJson(map));
          }
        } catch (e) {
          _log.w('SSE: dropping malformed event: $e');
        }
        return;
      }
    }
  }

  /// Force-close the current SSE connection so the retry loop re-establishes it.
  ///
  /// Call on app resume to recover from connections silently dropped by the OS
  /// while the app was backgrounded.
  void reconnect() {
    if (_currentGroupId == null || _disposed) return;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  /// Stop the SSE connection and free resources.
  void dispose() {
    _disposed = true;
    _httpClient?.close(force: true);
    _httpClient = null;
    _controller.close();
  }
}
