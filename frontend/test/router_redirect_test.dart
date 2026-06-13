import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/router_redirect.dart';

void main() {
  group('resolveAppRedirect', () {
    test('while bootstrap is loading, deep links use session gate', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/lists',
          queryParameters: {},
          authBootstrapLoading: true,
          authState: false,
          requestedPathWithQuery: '/lists',
        ),
      );

      expect(result.redirect, '/_session?continue=%2Flists');
      expect(result.clearPendingAuth, isFalse);
    });

    test('while bootstrap is loading, oauth callback is allowed through', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/auth/callback',
          queryParameters: {},
          authBootstrapLoading: true,
          authState: false,
        ),
      );

      expect(result.redirect, isNull);
    });

    test('while bootstrap is loading, session path stays put', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {},
          authBootstrapLoading: true,
          authState: false,
        ),
      );

      expect(result.redirect, isNull);
    });

    test('unauthenticated bootstrap sends user to welcome', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome');
    });

    test('authenticated bootstrap sends user to home', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/home');
    });

    test('authenticated bootstrap honors continue deep link', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/lists'},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/lists');
    });

    test('unauthenticated bootstrap honors continue to login', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/login'},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/login');
    });

    test('authenticated user on login is redirected to home', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/login',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/home');
    });

    test('authenticated user on signup is redirected to onboarding', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/signup',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/onboarding');
    });

    test('authenticated user on welcome with invite goes to join', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/welcome',
          queryParameters: {'invite': 'SUNNY-TACO'},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/join/SUNNY-TACO');
    });

    test('pending post-auth navigation overrides login redirect', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/login',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: true,
          pendingAuthNavigation: '/onboarding',
        ),
      );

      expect(result.redirect, '/onboarding');
      expect(result.clearPendingAuth, isTrue);
    });

    test('unauthenticated join link preserves invite on welcome', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/join/SUNNY-TACO',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome?invite=SUNNY-TACO');
    });

    test('unauthenticated protected route redirects to welcome', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/home',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome');
    });
  });
}
