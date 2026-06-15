import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/api_config.dart';
import 'token_store.dart';

/// Result of a successful token refresh.
class TokenPairResult {
  final String accessToken;
  final String refreshToken;
  const TokenPairResult({
    required this.accessToken,
    required this.refreshToken,
  });
}

/// Single source of truth for refreshing the access/refresh token pair.
///
/// The backend rotates refresh tokens: each successful refresh revokes the
/// supplied refresh token and issues a new pair. That makes a refresh token
/// strictly single-use, so concurrent refreshes that send the *same* token
/// race — the first wins (200) and the rest fail (401) against an
/// already-revoked token.
///
/// This coordinator serialises refreshes process-wide via a single in-flight
/// future, and persists the rotated pair to the shared [TokenStore]. Every
/// consumer (the Dio auth interceptor, the SSE reconnect loop, …) must call
/// [refresh] rather than hitting `/auth/token/refresh` directly, so they all
/// collapse onto one network call and observe the same rotated tokens.
class TokenRefreshCoordinator {
  final TokenStore _store;
  final Dio _dio;
  final Logger _logger = Logger();

  Future<TokenPairResult?>? _inFlight;

  TokenRefreshCoordinator(this._store, this._dio);

  /// The shared instance used by production code paths.
  ///
  /// Uses [SecureTokenStore.shared] and a bare Dio (no interceptors, so the
  /// refresh call can never recurse back into a token-refresh interceptor).
  static final TokenRefreshCoordinator shared = TokenRefreshCoordinator(
    SecureTokenStore.shared,
    Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: ApiConfig.requestTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
        sendTimeout: ApiConfig.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    ),
  );

  /// Refresh the token pair, coalescing concurrent callers onto one request.
  ///
  /// Returns the rotated pair (already persisted to the store) on success, or
  /// `null` if there is no refresh token or the refresh failed.
  Future<TokenPairResult?> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _run();
    _inFlight = future;
    // Clear the slot only if it still points at this future, so a refresh
    // started after we finished isn't clobbered.
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<TokenPairResult?> _run() async {
    final refreshToken = await _store.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _dio.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final access = data['access_token'];
        final refresh = data['refresh_token'];
        if (access is String && refresh is String) {
          await _store.save(accessToken: access, refreshToken: refresh);
          return TokenPairResult(accessToken: access, refreshToken: refresh);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        final status = e is DioException ? e.response?.statusCode : null;
        _logger.e('Token refresh failed (status: $status)');
      }
    }
    return null;
  }
}
