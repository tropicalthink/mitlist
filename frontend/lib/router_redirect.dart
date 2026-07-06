/// Pure redirect resolver for [GoRouter]. Extracted for unit testing.
class AppRedirectInput {
  const AppRedirectInput({
    required this.location,
    required this.queryParameters,
    required this.authBootstrapLoading,
    required this.authState,
    this.pendingAuthNavigation,
    this.requestedPathWithQuery,
  });

  final String location;
  final Map<String, String> queryParameters;
  final bool authBootstrapLoading;
  final bool authState;
  final String? pendingAuthNavigation;

  /// Full path + query of the route being redirected (e.g. `/lists?foo=bar`).
  final String? requestedPathWithQuery;
}

class AppRedirectResult {
  const AppRedirectResult({
    this.redirect,
    this.clearPendingAuth = false,
  });

  final String? redirect;
  final bool clearPendingAuth;
}

const sessionBootstrapPath = '/_session';

const authRoutePrefixes = [
  '/welcome',
  '/login',
  '/signup',
  '/auth/callback',
];

final _inviteCodePattern = RegExp(r'^[A-Za-z0-9\-]{4,}$');

bool isSessionBootstrapPath(String location) =>
    location.startsWith(sessionBootstrapPath);

bool isPlausibleInviteCode(String code) => _inviteCodePattern.hasMatch(code);

AppRedirectResult resolveAppRedirect(AppRedirectInput input) {
  final location = input.location;
  final isAuthRoute =
      authRoutePrefixes.any((prefix) => location.startsWith(prefix));

  if (input.authBootstrapLoading) {
    if (location.startsWith('/auth/callback')) {
      return const AppRedirectResult();
    }
    if (isSessionBootstrapPath(location)) {
      return const AppRedirectResult();
    }
    final target = input.requestedPathWithQuery ?? location;
    return AppRedirectResult(
      redirect: '$sessionBootstrapPath?continue=${Uri.encodeComponent(target)}',
    );
  }

  if (isSessionBootstrapPath(location)) {
    final cont = input.queryParameters['continue'];
    String? continueTarget;
    if (cont != null && cont.isNotEmpty) {
      final decoded = Uri.decodeComponent(cont);
      if (decoded.startsWith('/') && !decoded.startsWith('//')) {
        continueTarget = decoded;
      }
    }

    if (input.authState) {
      return AppRedirectResult(redirect: continueTarget ?? '/home');
    }

    if (continueTarget != null &&
        authRoutePrefixes.any((p) => continueTarget!.startsWith(p))) {
      return AppRedirectResult(redirect: continueTarget);
    }
    return const AppRedirectResult(redirect: '/welcome');
  }

  if (!input.authState && !isAuthRoute) {
    if (location.startsWith('/join/')) {
      final code = location.substring('/join/'.length);
      if (isPlausibleInviteCode(code)) {
        return AppRedirectResult(
          redirect: '/welcome?invite=${Uri.encodeComponent(code)}',
        );
      }
    }
    return const AppRedirectResult(redirect: '/welcome');
  }

  if (input.authState && isAuthRoute) {
    if (input.pendingAuthNavigation != null) {
      return AppRedirectResult(
        redirect: input.pendingAuthNavigation,
        clearPendingAuth: true,
      );
    }
    final invite = input.queryParameters['invite'];
    if (invite != null && isPlausibleInviteCode(invite)) {
      return AppRedirectResult(
        redirect: '/join/${Uri.encodeComponent(invite)}',
      );
    }
    if (location.startsWith('/signup') ||
        location.startsWith('/auth/callback')) {
      return const AppRedirectResult(redirect: '/onboarding');
    }
    if (location.startsWith('/welcome') || location.startsWith('/login')) {
      return const AppRedirectResult(redirect: '/home');
    }
    return const AppRedirectResult();
  }

  return const AppRedirectResult();
}
