import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/router_redirect.dart';

void main() {
  group('resolveAppRedirect', () {
    test('a signed-in guest finishing a provider upgrade stays on the callback',
        () {
      const input = AppRedirectInput(
        location: '/auth/callback',
        queryParameters: {'provider': 'google', 'handoff': 'h', 'link': '1'},
        authBootstrapLoading: false,
        authState: true,
        isOAuthLinkCallback: true,
      );
      // Without the marker an authenticated callback is bounced to
      // onboarding; with it the callback screen must be allowed to run.
      expect(resolveAppRedirect(input).redirect, isNull);
      expect(
        resolveAppRedirect(const AppRedirectInput(
          location: '/auth/callback',
          queryParameters: {'provider': 'google', 'handoff': 'h'},
          authBootstrapLoading: false,
          authState: true,
        )).redirect,
        '/onboarding',
      );
    });

    test('a signed-out visitor may open a shared recipe', () {
      // The whole point of a share link is that it renders for someone with
      // neither the app nor an account. Bouncing to /welcome would strand them.
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/r/ABCDEFGH',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, isNull);
    });

    test('a signed-out visitor is still bounced off a private route', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/recipes',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome');
    });

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

    test('unauthenticated bootstrap honors continue to a shared recipe', () {
      // A share link opened in a fresh browser goes through the session gate
      // before the public-route exemption gets a look in; it must come out the
      // other side still pointing at the recipe.
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/r/ABCDEFGH'},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/r/ABCDEFGH');
    });

    test('unauthenticated bootstrap keeps the invite from a join link', () {
      // Opening an invite link in a fresh browser goes through the session
      // gate first. The recipient must come out on welcome *with* the code,
      // otherwise sign-in drops them on home and the invite is lost.
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/join/SUNNY-TACO-ABC123'},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome?invite=SUNNY-TACO-ABC123');
    });

    test('unauthenticated bootstrap with an implausible join code falls back',
        () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/join/x'},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/welcome');
    });

    test('authenticated bootstrap sends a join link straight to the page', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/join/SUNNY-TACO-ABC123'},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/join/SUNNY-TACO-ABC123');
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

    test('a signed-out visitor may take the tour', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/tour',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, isNull);
    });

    test('a signed-in user on the tour is sent home', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/tour',
          queryParameters: {},
          authBootstrapLoading: false,
          authState: true,
        ),
      );

      expect(result.redirect, '/home');
    });

    test('unauthenticated bootstrap honors continue to the tour', () {
      final result = resolveAppRedirect(
        const AppRedirectInput(
          location: '/_session',
          queryParameters: {'continue': '/tour'},
          authBootstrapLoading: false,
          authState: false,
        ),
      );

      expect(result.redirect, '/tour');
    });
  });
}
