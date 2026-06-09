import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

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
  final StreamController<SseEvent> _controller =
      StreamController<SseEvent>.broadcast();

  HttpClient? _httpClient;
  bool _disposed = false;
  String? _currentGroupId;

  Stream<SseEvent> get events => _controller.stream;

  /// Connect (or reconnect) to the SSE stream for [groupId].
  Future<void> connect(String groupId) async {
    if (_currentGroupId == groupId) return;
    _currentGroupId = groupId;
    _httpClient?.close(force: true);
    _httpClient = null;
    unawaited(_startLoop(groupId));
  }

  Future<void> _startLoop(String groupId) async {
    var backoff = const Duration(seconds: 2);

    while (!_disposed && _currentGroupId == groupId) {
      try {
        await _connectOnce(groupId);
      } on _SseUnauthorizedException {
        if (_disposed || _currentGroupId != groupId) break;
        _log.i('SSE got 401 — attempting token refresh');
        final refreshed = await _tryRefreshToken();
        if (!refreshed) {
          _log.w('Token refresh failed; stopping SSE loop');
          break;
        }
        // New token saved — retry immediately without backoff.
      } catch (e) {
        if (_disposed || _currentGroupId != groupId) break;
        _log.w('SSE disconnected, retrying in ${backoff.inSeconds}s: $e');
        await Future.delayed(backoff);
        backoff = Duration(seconds: (backoff.inSeconds * 2).clamp(2, 60));
      }
    }
  }

  Future<bool> _tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(ApiConfig.refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/auth/token/refresh',
      );
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'refresh_token': refreshToken}));
      final resp = await req.close();
      if (resp.statusCode != 200) return false;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      if (newAccess == null) return false;

      await prefs.setString(ApiConfig.accessTokenKey, newAccess);
      if (newRefresh != null) {
        await prefs.setString(ApiConfig.refreshTokenKey, newRefresh);
      }
      return true;
    } catch (e) {
      _log.w('Token refresh in SSE failed: $e');
      return false;
    }
  }

  Future<void> _connectOnce(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.accessTokenKey);
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
      if (_disposed || _currentGroupId != groupId) return;
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
        } catch (_) {}
        return;
      }
    }
  }

  /// Stop the SSE connection and free resources.
  void dispose() {
    _disposed = true;
    _httpClient?.close(force: true);
    _httpClient = null;
    _controller.close();
  }
}
