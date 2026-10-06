import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/config/api_config.dart';
import 'package:mitlist/services/api_client.dart';
import 'package:mitlist/services/token_refresh_coordinator.dart';
import 'package:mitlist/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;
  var clearCount = 0;

  _MemoryTokenStore({this.accessToken, this.refreshToken});

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
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    clearCount++;
  }
}

/// A refresh endpoint that refuses every token, optionally running
/// [beforeAnswer] first (e.g. a sign-in saving a new session meanwhile).
TokenRefreshCoordinator _rejectingCoordinator(
  TokenStore store, {
  void Function()? beforeAnswer,
  void Function()? onCall,
}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    onCall?.call();
    beforeAnswer?.call();
    handler.reject(DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
      type: DioExceptionType.badResponse,
    ));
  }));
  return TokenRefreshCoordinator(store, dio);
}

/// An API client whose every request is answered 401, behind the refresh
/// interceptor under test.
Dio _apiAnswering401(TokenStore store, TokenRefreshCoordinator coordinator) {
  final dio = Dio();
  dio.interceptors.add(TokenRefreshInterceptor(dio, null, store, coordinator));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
        type: DioExceptionType.badResponse,
      ),
      true,
    );
  }));
  return dio;
}

Options _withSession(String token) => Options(headers: {
      ApiConfig.authorizationHeader: '${ApiConfig.authorizationPrefix}$token',
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a 401 on a request sent without a session neither refreshes nor '
      'signs out', () async {
    // A queued op sent while signed out (or racing a sign-in) used to run the
    // refresh-failure path and wipe whatever session was saved by then.
    final store = _MemoryTokenStore(
        accessToken: 'fresh-access', refreshToken: 'fresh-refresh');
    var refreshCalls = 0;
    final coordinator =
        _rejectingCoordinator(store, onCall: () => refreshCalls++);
    final dio = _apiAnswering401(store, coordinator);

    await expectLater(
      dio.patch('/auth/me', data: {'language': 'de'}),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 0);
    expect(store.clearCount, 0);
    expect(store.refreshToken, 'fresh-refresh');
  });

  test('a refused refresh does not wipe a session saved meanwhile', () async {
    final store =
        _MemoryTokenStore(accessToken: 'old-access', refreshToken: 'old');
    final coordinator = _rejectingCoordinator(store, beforeAnswer: () {
      store.accessToken = 'new-access';
      store.refreshToken = 'new';
    });
    final dio = _apiAnswering401(store, coordinator);

    await expectLater(
      dio.get('/groups', options: _withSession('old-access')),
      throwsA(isA<DioException>()),
    );

    expect(store.clearCount, 0);
    expect(store.refreshToken, 'new');
  });

  test('a refused refresh of the current session signs out', () async {
    final store =
        _MemoryTokenStore(accessToken: 'old-access', refreshToken: 'old');
    final dio = _apiAnswering401(store, _rejectingCoordinator(store));

    await expectLater(
      dio.get('/groups', options: _withSession('old-access')),
      throwsA(isA<DioException>()),
    );

    expect(store.clearCount, 1);
    expect(store.refreshToken, isNull);
  });
}
