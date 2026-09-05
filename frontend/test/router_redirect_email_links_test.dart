import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/router_redirect.dart';

/// The two email links (`/verify?token=`, `/reset-password?token=`) must land
/// on their screens no matter who opens them.
void main() {
  group('email link routes', () {
    test('a signed-out visitor reaches the verify and reset screens', () {
      for (final path in ['/verify', '/reset-password']) {
        final result = resolveAppRedirect(AppRedirectInput(
          location: path,
          queryParameters: const {'token': 'ABCD1234'},
          authBootstrapLoading: false,
          authState: false,
        ));
        expect(result.redirect, isNull, reason: path);
      }
    });

    test('a fresh page load carries the link through session bootstrap', () {
      // Every cold web load passes the /_session gate first; the link must
      // come out the other side intact instead of collapsing to /welcome.
      for (final path in ['/verify', '/reset-password']) {
        final target = '$path?token=ABCD1234';
        final gated = resolveAppRedirect(AppRedirectInput(
          location: path,
          queryParameters: const {'token': 'ABCD1234'},
          authBootstrapLoading: true,
          authState: false,
          requestedPathWithQuery: target,
        ));
        expect(
          gated.redirect,
          '$sessionBootstrapPath?continue=${Uri.encodeComponent(target)}',
        );

        final released = resolveAppRedirect(AppRedirectInput(
          location: sessionBootstrapPath,
          queryParameters: {'continue': Uri.encodeComponent(target)},
          authBootstrapLoading: false,
          authState: false,
        ));
        expect(released.redirect, target, reason: path);
      }
    });

    test('a signed-in visitor is not bounced off the link screens', () {
      // A guest verifying the address they just added is signed in already;
      // someone resetting a password on a device that still holds another
      // session must be able to finish. Neither gets the /login treatment.
      for (final path in ['/verify', '/reset-password']) {
        final result = resolveAppRedirect(AppRedirectInput(
          location: path,
          queryParameters: const {'token': 'ABCD1234'},
          authBootstrapLoading: false,
          authState: true,
        ));
        expect(result.redirect, isNull, reason: path);
      }
    });

    test('after the screen parks a destination, the router follows it', () {
      // Both screens finish by parking where to go and flipping auth state;
      // the redirect consumes the parked path and clears it.
      final result = resolveAppRedirect(const AppRedirectInput(
        location: '/reset-password',
        queryParameters: {'token': 'ABCD1234'},
        authBootstrapLoading: false,
        authState: true,
        pendingAuthNavigation: '/home',
      ));
      expect(result.redirect, '/home');
      expect(result.clearPendingAuth, isTrue);
    });
  });
}
