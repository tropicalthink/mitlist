import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/app_check_service.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppCheck implements AppCheckTokenProvider {
  _FakeAppCheck(this.token);

  final String? token;
  var calls = 0;

  @override
  Future<String?> getToken() async {
    calls++;
    return token;
  }
}

class _MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guest creation fetches and attaches the current App Check token',
      () async {
    final appCheck = _FakeAppCheck('attestation-token');
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/auth/guest');
            expect(options.headers['X-Firebase-AppCheck'], 'attestation-token');
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'access_token': 'guest-access',
                'refresh_token': 'guest-refresh',
              },
            ));
          },
        ),
      );
    final auth = AuthService.forTest(
      dio,
      await SharedPreferences.getInstance(),
      _MemoryTokenStore(),
      appCheck: appCheck,
    );

    await auth.createGuest();
    expect(appCheck.calls, 1);
  });

  test('guest creation does not add an empty App Check header', () async {
    final appCheck = _FakeAppCheck(null);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers.containsKey('X-Firebase-AppCheck'), false);
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'access_token': 'guest-access',
                'refresh_token': 'guest-refresh',
              },
            ));
          },
        ),
      );
    final auth = AuthService.forTest(
      dio,
      await SharedPreferences.getInstance(),
      _MemoryTokenStore(),
      appCheck: appCheck,
    );

    await auth.createGuest();
    expect(appCheck.calls, 1);
  });
}
