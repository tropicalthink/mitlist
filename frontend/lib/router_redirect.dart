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

/// Routes a signed-out visitor is allowed to see.
///
/// A shared recipe link has to render for someone who has neither the app nor
/// an account — that is the whole point of the fallback — so it cannot bounce
/// to /welcome like every other route.
const publicRoutePrefixes = ['/r/'];

final _inviteCodePattern = RegExp(r'^[A-Za-z0-9\-]{4,}$');

bool isPublicRoute(String location) =>
    publicRoutePrefixes.any((prefix) => location.startsWith(prefix));

bool isSessionBootstrapPath(String location) =>
    location.startsWith(sessionBootstrapPath);

bool isPlausibleInviteCode(String code) => _inviteCodePattern.hasMatch(code);

/// A signed-out visitor holding an invite link is sent to /welcome with the
/// code pinned to the query, so it survives sign-in and lands them on the
/// accept page afterwards. Returns null when [location] is not a join link.
String? welcomeWithInviteFor(String location) {
  if (!location.startsWith('/join/')) return null;
  var code = location.substring('/join/'.length);
  final cut = code.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) code = code.substring(0, cut);
  if (!isPlausibleInviteCode(code)) return null;
  return '/welcome?invite=${Uri.encodeComponent(code)}';
}

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

    // A signed-out visitor may still land where they asked to go when it is
    // an auth route or a public one. A share link opened in a fresh browser
    // passes through this gate first; bouncing it to /welcome would lose the
    // recipe they were sent.
    if (continueTarget != null &&
        (authRoutePrefixes.any((p) => continueTarget!.startsWith(p)) ||
            isPublicRoute(continueTarget))) {
      return AppRedirectResult(redirect: continueTarget);
    }
    // Same for an invite link: every fresh page load passes through this gate
    // before the /join/ handling below gets a look in, so without this the
    // code was dropped and the recipient ended up on a bare welcome page.
    if (continueTarget != null) {
      final welcome = welcomeWithInviteFor(continueTarget);
      if (welcome != null) return AppRedirectResult(redirect: welcome);
    }
    return const AppRedirectResult(redirect: '/welcome');
  }

  if (!input.authState && !isAuthRoute) {
    if (isPublicRoute(location)) {
      return const AppRedirectResult();
    }
    final welcome = welcomeWithInviteFor(location);
    if (welcome != null) return AppRedirectResult(redirect: welcome);
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
