import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/native_oauth_launcher.dart';

const _channel = MethodChannel('mitlist/oauth_launcher');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  /// Stands in for the platform side, answering [answer] the way the native
  /// handler would.
  void mockPlatform(String? answer) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return answer;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('startNativeOAuthSession', () {
    test('passes the URL and bare callback scheme to the platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockPlatform(null);

      await startNativeOAuthSession(
        'https://api.mitlist.me/api/v1/oauth/google',
        callbackScheme: 'mitlist',
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'startAuthSession');
      expect(calls.single.arguments, {
        'url': 'https://api.mitlist.me/api/v1/oauth/google',
        'callbackScheme': 'mitlist',
      });
    });

    test('a returned callback URL completes the flow in-process', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockPlatform('mitlist:///auth/callback?provider=apple&handoff=abc123');

      final result = await startNativeOAuthSession(
        'https://api.mitlist.me/api/v1/oauth/apple',
        callbackScheme: 'mitlist',
      );

      expect(result.outcome, NativeOAuthOutcome.completed);
      expect(
        result.callbackUrl,
        'mitlist:///auth/callback?provider=apple&handoff=abc123',
      );
    });

    test('null on iOS means the user dismissed the sheet', () async {
      // ASWebAuthenticationSession hands back the callback itself, so nothing
      // coming back can only mean the sheet was closed.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockPlatform(null);

      final result = await startNativeOAuthSession(
        'https://api.mitlist.me/api/v1/oauth/google',
        callbackScheme: 'mitlist',
      );

      expect(result.outcome, NativeOAuthOutcome.cancelled);
      expect(result.callbackUrl, isNull);
    });

    test('null on Android means the Custom Tab is open', () async {
      // A Custom Tab cannot answer through the channel: the redirect arrives
      // later as a deep link, so null here is "opened", not "cancelled".
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mockPlatform(null);

      final result = await startNativeOAuthSession(
        'https://api.mitlist.me/api/v1/oauth/google',
        callbackScheme: 'mitlist',
      );

      expect(result.outcome, NativeOAuthOutcome.pendingDeepLink);
      expect(result.callbackUrl, isNull);
    });

    test('platform errors propagate to the caller', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        throw PlatformException(code: 'launch_failed');
      });

      expect(
        () => startNativeOAuthSession(
          'https://api.mitlist.me/api/v1/oauth/google',
          callbackScheme: 'mitlist',
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
