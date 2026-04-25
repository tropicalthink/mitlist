import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

const _retryKey = 'has_retried';

class AuthInterceptor extends Interceptor {
  final Logger _logger = Logger();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.accessTokenKey);

    if (token != null) {
      options.headers[ApiConfig.authorizationHeader] =
          '${ApiConfig.authorizationPrefix}$token';
    }

    _logger.d('Request: ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d('Response: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('Dio Error: ${err.type} - ${err.message}');
    handler.next(err);
  }
}

/// Custom Dio interceptor for token refresh.
class TokenRefreshInterceptor extends Interceptor {
  final Dio dio;
  final Logger _logger = Logger();
  final Ref? _ref;

  TokenRefreshInterceptor(this.dio, [this._ref]);

  static Future<TokenPairResult?>? _refreshInFlight;

  Future<TokenPairResult?> _refreshTokensOnce(Dio dio, SharedPreferences prefs) async {
    if (_refreshInFlight != null) {
      return await _refreshInFlight!;
    }
    final refreshToken = prefs.getString(ApiConfig.refreshTokenKey);
    if (refreshToken == null) {
      return null;
    }

    final future = () async {
      try {
        final response = await dio.post(
          '/auth/token/refresh',
          options: Options(extra: {_retryKey: true}),
          data: {'refresh_token': refreshToken},
        );
        if (response.statusCode == 200 &&
            response.data is Map<String, dynamic> &&
            (response.data as Map<String, dynamic>).containsKey('access_token') &&
            (response.data as Map<String, dynamic>).containsKey('refresh_token')) {
          final data = response.data as Map<String, dynamic>;
          return TokenPairResult(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
          );
        }
      } catch (e) {
        // log below
        _logger.e('Token refresh failed: $e');
      }
      return null;
    }();

    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
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

    final prefs = await SharedPreferences.getInstance();
    final tokenPair = await _refreshTokensOnce(dio, prefs);
    if (tokenPair == null) {
      await _onRefreshFailure(prefs);
      handler.next(err);
      return;
    }

    await prefs.setString(ApiConfig.accessTokenKey, tokenPair.accessToken);
    await prefs.setString(ApiConfig.refreshTokenKey, tokenPair.refreshToken);

    final options = err.requestOptions;
    options.headers[ApiConfig.authorizationHeader] =
        '${ApiConfig.authorizationPrefix}${tokenPair.accessToken}';
    options.extra[_retryKey] = true;

    try {
      final retryResponse = await dio.fetch(options);
      handler.resolve(retryResponse);
      return;
    } catch (retryErr) {
      _logger.e('Retry failed: $retryErr');
    }

    await _onRefreshFailure(prefs);
    handler.next(err);
  }

  Future<void> _onRefreshFailure(SharedPreferences prefs) async {
    await prefs.remove(ApiConfig.accessTokenKey);
    await prefs.remove(ApiConfig.refreshTokenKey);
    await prefs.remove(ApiConfig.userDataKey);
    _ref?.read(authStateProvider.notifier).state = false;
  }
}

class TokenPairResult {
  final String accessToken;
  final String refreshToken;
  const TokenPairResult({required this.accessToken, required this.refreshToken});
}

/// Creates a configured Dio instance for API requests.
Dio createApiClient([Ref? ref]) {
  final dio = Dio(
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
  );

  dio.interceptors.add(TokenRefreshInterceptor(dio, ref));
  dio.interceptors.add(AuthInterceptor());

  final logger = Logger();
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (object) => logger.d(object),
  ));

  return dio;
}
