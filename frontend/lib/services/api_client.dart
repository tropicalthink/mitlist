import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/list_provider.dart' show appDatabaseProvider;
import '../providers/outbox_provider.dart' show connectivityServiceProvider;
import 'response_cache_interceptor.dart';
import 'token_refresh_coordinator.dart';
import 'token_store.dart';
import 'dio_platform.dart';

const _retryKey = 'has_retried';

bool _isPublicAuthPath(String path) {
  final normalized = Uri.tryParse(path)?.path ?? path;
  return normalized.endsWith('/auth/login') ||
      normalized.endsWith('/auth/register') ||
      normalized.endsWith('/auth/verify-email') ||
      normalized.endsWith('/auth/verify-email/resend') ||
      normalized.endsWith('/auth/password-reset') ||
      normalized.endsWith('/auth/password-reset/confirm') ||
      normalized.endsWith('/auth/guest') ||
      normalized.contains('/oauth/');
}

String _redactedDioError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final method = error.requestOptions.method;
    final path = error.requestOptions.path;
    return 'DioException(type: ${error.type}, status: $status, request: $method $path)';
  }
  return error.runtimeType.toString();
}

class AuthInterceptor extends Interceptor {
  final Logger _logger = Logger();
  final TokenStore _tokenStore;

  AuthInterceptor([TokenStore? tokenStore])
      : _tokenStore = tokenStore ?? SecureTokenStore();

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isPublicAuthPath(options.path)) {
      options.headers.remove(ApiConfig.authorizationHeader);
      handler.next(options);
      return;
    }
    final token = await _tokenStore.getAccessToken();

    if (token != null) {
      options.headers[ApiConfig.authorizationHeader] =
          '${ApiConfig.authorizationPrefix}$token';
    }

    if (kDebugMode) {
      _logger.d('Request: ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.d(
        'Response: ${response.statusCode} ${response.requestOptions.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.e(_redactedDioError(err));
    }
    handler.next(err);
  }
}

/// Custom Dio interceptor for token refresh.
///
/// On a 401, delegates to the shared [TokenRefreshCoordinator] (single-flight,
/// shared with the SSE service) so concurrent 401s collapse onto one refresh
/// against one rotated token, then retries the original request.
class TokenRefreshInterceptor extends Interceptor {
  final Dio dio;
  final Logger _logger = Logger();
  final Ref? _ref;
  final TokenStore _tokenStore;
  final TokenRefreshCoordinator _coordinator;

  TokenRefreshInterceptor(
    this.dio, [
    this._ref,
    TokenStore? tokenStore,
    TokenRefreshCoordinator? coordinator,
  ])  : _tokenStore = tokenStore ?? SecureTokenStore.shared,
        _coordinator = coordinator ?? TokenRefreshCoordinator.shared;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    if (_isPublicAuthPath(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    if (err.requestOptions.path.contains('/auth/token/refresh')) {
      handler.next(err);
      return;
    }

    if (err.requestOptions.extra[_retryKey] == true) {
      handler.next(err);
      return;
    }

    // Snapshot the token we're refreshing against so we can tell, on failure,
    // whether someone else rotated it underneath us.
    final attemptedRefreshToken = await _tokenStore.getRefreshToken();
    final refreshOutcome = await _coordinator.refreshDetailed();
    if (refreshOutcome.type == TokenRefreshOutcomeType.transportError) {
      handler.next(err);
      return;
    }
    if (refreshOutcome.type == TokenRefreshOutcomeType.authRejected) {
      await _onRefreshFailure(attemptedRefreshToken);
      handler.next(err);
      return;
    }
    final tokenPair = refreshOutcome.tokenPair!;

    // The coordinator already persisted the rotated pair to the shared store.
    final options = err.requestOptions;
    options.headers[ApiConfig.authorizationHeader] =
        '${ApiConfig.authorizationPrefix}${tokenPair.accessToken}';
    options.extra[_retryKey] = true;

    try {
      final retryResponse = await dio.fetch(options);
      handler.resolve(retryResponse);
      return;
    } on DioException catch (retryErr) {
      if (kDebugMode) {
        _logger.e('Retry failed: ${_redactedDioError(retryErr)}');
      }
      if (retryErr.response?.statusCode != 401) {
        handler.reject(retryErr);
        return;
      }
    } catch (retryErr) {
      if (kDebugMode) {
        _logger.e('Retry failed: ${_redactedDioError(retryErr)}');
      }
      handler.next(err);
      return;
    }

    await _onRefreshFailure(attemptedRefreshToken);
    handler.next(err);
  }

  Future<void> _onRefreshFailure(String? attemptedRefreshToken) async {
    // Defensive: if the stored refresh token changed since we started, another
    // path successfully rotated it — don't wipe a freshly-valid session.
    final current = await _tokenStore.getRefreshToken();
    if (attemptedRefreshToken != null &&
        current != null &&
        current != attemptedRefreshToken) {
      return;
    }
    if (_ref != null) {
      final authService = await _ref.read(authServiceProviderAsync.future);
      await authService.clearLocalSession();
    } else {
      await _tokenStore.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConfig.userDataKey);
    }
    _ref?.read(authStateProvider.notifier).state = false;
  }
}

/// Shared Dio instance for all API services.
final dioProvider = Provider<Dio>((ref) {
  final dio = createApiClient(ref);
  ref.onDispose(() => dio.close());
  return dio;
});

/// Returns the shared Dio when [ref] is available, otherwise a standalone client.
Dio resolveDio([Ref? ref]) {
  if (ref != null) {
    return ref.read(dioProvider);
  }
  return createApiClient(ref);
}

/// Creates a configured Dio instance for API requests.
Dio createApiClient([Ref? ref, TokenStore? tokenStore]) {
  final store = tokenStore ?? SecureTokenStore.shared;
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

  // First in the chain so a transport failure is answered from the cache
  // before the refresh interceptor ever sees it (it only cares about 401s),
  // and so a known-offline GET never reaches the wire at all. Standalone
  // clients built without a [Ref] have no database to cache into.
  if (ref != null) {
    dio.interceptors.add(ResponseCacheInterceptor(
      store: () => DriftResponseCacheStore(ref.read(appDatabaseProvider)),
      isKnownOffline: () =>
          ref.read(connectivityServiceProvider).isKnownOffline,
    ));
  }
  dio.interceptors.add(TokenRefreshInterceptor(dio, ref, store));
  dio.interceptors.add(AuthInterceptor(store));

  return dio;
}
