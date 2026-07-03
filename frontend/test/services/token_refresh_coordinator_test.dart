import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/token_refresh_coordinator.dart';
import 'package:mitlist/services/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  String? accessToken = 'old-access';
  String? refreshToken;
  var saveCount = 0;
  var clearCount = 0;

  _MemoryTokenStore({this.refreshToken});

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    clearCount++;
  }
}

Dio _dioWithRefresh(
    Future<void> Function(RequestOptions, RequestInterceptorHandler) handler) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: handler,
    ),
  );
  return dio;
}

void main() {
  group('TokenRefreshCoordinator.refreshDetailed', () {
    test('200 with a valid pair returns success and saves tokens', () async {
      final store = _MemoryTokenStore(refreshToken: 'old-refresh');
      final dio = _dioWithRefresh((options, handler) async {
        expect(options.path, '/auth/token/refresh');
        expect(options.data, {'refresh_token': 'old-refresh'});
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          },
        ));
      });

      final outcome =
          await TokenRefreshCoordinator(store, dio).refreshDetailed();

      expect(outcome.type, TokenRefreshOutcomeType.success);
      expect(outcome.tokenPair?.accessToken, 'new-access');
      expect(store.accessToken, 'new-access');
      expect(store.refreshToken, 'new-refresh');
      expect(store.saveCount, 1);
    });

    test('401 returns authRejected and does not save tokens', () async {
      final store = _MemoryTokenStore(refreshToken: 'old-refresh');
      final dio = _dioWithRefresh((options, handler) async {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
          type: DioExceptionType.badResponse,
        ));
      });

      final outcome =
          await TokenRefreshCoordinator(store, dio).refreshDetailed();

      expect(outcome.type, TokenRefreshOutcomeType.authRejected);
      expect(store.saveCount, 0);
      expect(store.refreshToken, 'old-refresh');
    });

    test('connectionError returns transportError and does not save tokens',
        () async {
      final store = _MemoryTokenStore(refreshToken: 'old-refresh');
      final dio = _dioWithRefresh((options, handler) async {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
        ));
      });

      final outcome =
          await TokenRefreshCoordinator(store, dio).refreshDetailed();

      expect(outcome.type, TokenRefreshOutcomeType.transportError);
      expect(store.saveCount, 0);
      expect(store.refreshToken, 'old-refresh');
    });

    test('missing refresh token returns authRejected', () async {
      final store = _MemoryTokenStore();
      final dio = _dioWithRefresh((options, handler) async {
        fail('refresh endpoint should not be called without a refresh token');
      });

      final outcome =
          await TokenRefreshCoordinator(store, dio).refreshDetailed();

      expect(outcome.type, TokenRefreshOutcomeType.authRejected);
      expect(store.saveCount, 0);
    });

    test('legacy refresh returns token pair only on success', () async {
      final store = _MemoryTokenStore(refreshToken: 'old-refresh');
      final dio = _dioWithRefresh((options, handler) async {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonDecode(
            '{"access_token":"new-access","refresh_token":"new-refresh"}',
          ),
        ));
      });

      final pair = await TokenRefreshCoordinator(store, dio).refresh();

      expect(pair?.refreshToken, 'new-refresh');
    });
  });
}
