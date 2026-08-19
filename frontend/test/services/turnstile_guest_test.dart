import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/app_check_service.dart';
import 'package:mitlist/services/token_store.dart';
import 'package:mitlist/services/turnstile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTurnstile implements TurnstileTokenProvider {
  _FakeTurnstile(this.token);

  final String? token;
  var calls = 0;

  @override
  Future<String?> getToken() async {
    calls++;
    return token;
  }
}

/// Mobile builds have no Turnstile widget and web builds have no App Check
/// provider, so each platform contributes exactly one header — never both.
class _NullAppCheck implements AppCheckTokenProvider {
  @override
  Future<String?> getToken() async => null;
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

Dio _dioExpecting(void Function(RequestOptions options) check) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          check(options);
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guest creation attaches the Turnstile token', () async {
    final turnstile = _FakeTurnstile('solved-challenge');
    final dio = _dioExpecting((options) {
      expect(options.path, '/auth/guest');
      expect(options.headers['X-Mitlist-Turnstile'], 'solved-challenge');
      expect(options.headers.containsKey('X-Firebase-AppCheck'), false);
    });

    final auth = AuthService.forTest(
      dio,
      await SharedPreferences.getInstance(),
      _MemoryTokenStore(),
      appCheck: _NullAppCheck(),
      turnstile: turnstile,
    );

    await auth.createGuest();
    expect(turnstile.calls, 1);
  });

  test('guest creation does not add an empty Turnstile header', () async {
    final turnstile = _FakeTurnstile(null);
    final dio = _dioExpecting((options) {
      expect(options.headers.containsKey('X-Mitlist-Turnstile'), false);
    });

    final auth = AuthService.forTest(
      dio,
      await SharedPreferences.getInstance(),
      _MemoryTokenStore(),
      appCheck: _NullAppCheck(),
      turnstile: turnstile,
    );

    await auth.createGuest();
    expect(turnstile.calls, 1);
  });
}
