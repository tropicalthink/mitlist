import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/api_config.dart';
import 'token_store.dart';
import 'dio_platform.dart';

/// Result of a successful token refresh.
class TokenPairResult {
  final String accessToken;
  final String refreshToken;
  const TokenPairResult({
    required this.accessToken,
    required this.refreshToken,
  });
}

enum TokenRefreshOutcomeType {
  success,
  authRejected,
  transportError,
}

/// Detailed token-refresh result for callers that must distinguish an invalid
/// refresh token from a transient network failure.
class TokenRefreshOutcome {
  final TokenRefreshOutcomeType type;
  final TokenPairResult? tokenPair;

  const TokenRefreshOutcome._(this.type, [this.tokenPair]);

  const TokenRefreshOutcome.success(TokenPairResult tokenPair)
      : this._(TokenRefreshOutcomeType.success, tokenPair);

  const TokenRefreshOutcome.authRejected()
      : this._(TokenRefreshOutcomeType.authRejected);

  const TokenRefreshOutcome.transportError()
      : this._(TokenRefreshOutcomeType.transportError);
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

  Future<TokenRefreshOutcome>? _inFlight;

  TokenRefreshCoordinator(this._store, this._dio);

  /// The shared instance used by production code paths.
  ///
  /// Uses [SecureTokenStore.shared] and a bare Dio (no interceptors, so the
  /// refresh call can never recurse back into a token-refresh interceptor).
  static final TokenRefreshCoordinator shared = TokenRefreshCoordinator(
    SecureTokenStore.shared,
    _createRefreshDio(),
  );

  static Dio _createRefreshDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
        sendTimeout: ApiConfig.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (kIsWeb) 'X-Mitlist-Client': 'web',
        },
      ),
    );
    configureDioForPlatform(dio);
    return dio;
  }

  /// Refresh the token pair, coalescing concurrent callers onto one request.
  ///
  /// Returns the rotated pair (already persisted to the store) on success, or
  /// `null` if there is no refresh token or the refresh failed.
  Future<TokenPairResult?> refresh() async {
    final outcome = await refreshDetailed();
    return outcome.tokenPair;
  }

  /// Refresh the token pair and preserve the reason for non-success outcomes.
  Future<TokenRefreshOutcome> refreshDetailed() {
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

  Future<TokenRefreshOutcome> _run() async {
    final refreshToken = await _store.getRefreshToken();
    if (refreshToken == null && !kIsWeb) {
      return const TokenRefreshOutcome.authRejected();
    }

    final attemptedRefresh = refreshToken ?? '';

    try {
      final response = await _dio.post(
        '/auth/token/refresh',
        data: {'refresh_token': attemptedRefresh},
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final access = data['access_token'];
        final refresh = data['refresh_token'];
        if (access is String && (refresh is String || kIsWeb)) {
          final current = await _store.getRefreshToken();
          if (!kIsWeb && current != attemptedRefresh) {
            return const TokenRefreshOutcome.authRejected();
          }
          final rotatedRefresh = refresh is String ? refresh : '';
          if (kIsWeb && _store is SecureTokenStore) {
            await _store.saveEphemeral(
              accessToken: access,
              refreshToken: rotatedRefresh,
            );
          } else {
            await _store.save(
              accessToken: access,
              refreshToken: rotatedRefresh,
            );
          }
          return TokenRefreshOutcome.success(
            TokenPairResult(
              accessToken: access,
              refreshToken: rotatedRefresh,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        _logger.e('Token refresh failed (status: ${e.response?.statusCode})');
      }
      if (_isTransportError(e)) {
        return const TokenRefreshOutcome.transportError();
      }
      return const TokenRefreshOutcome.authRejected();
    } catch (e) {
      if (kDebugMode) {
        _logger.e('Token refresh failed (${e.runtimeType})');
      }
    }
    return const TokenRefreshOutcome.authRejected();
  }

  bool _isTransportError(DioException e) {
    return e.response == null ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}
