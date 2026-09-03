import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import 'browser_redirect.dart';
import 'native_oauth_launcher.dart';

/// How a provider round-trip will come back to the app, if at all.
enum OAuthLaunchOutcome {
  /// This platform can open neither a browser redirect nor a native session.
  unsupported,

  /// The browser is navigating away; the callback arrives as a page load.
  redirecting,

  /// Android's Custom Tab holds the screen until the deep link re-enters.
  pendingDeepLink,

  /// iOS's sheet captured the redirect itself; [OAuthLaunch.callbackUrl]
  /// carries what the router must be handed.
  completed,

  /// The person backed out of the provider's screen.
  cancelled,
}

class OAuthLaunch {
  const OAuthLaunch(this.outcome, {this.callbackUrl});

  final OAuthLaunchOutcome outcome;
  final String? callbackUrl;
}

/// Sends the person to [provider]'s consent screen through the backend's
/// initiation endpoint and reports how the round-trip will return.
///
/// With [linkToken] the round-trip upgrades the current guest instead of
/// signing someone in; the token comes from the auth service and is carried
/// by the backend, so the redirect URI itself stays on the allowlist.
Future<OAuthLaunch> launchOAuthProvider(
  WidgetRef ref, {
  required String provider,
  required bool rememberMe,
  String? linkToken,
}) async {
  if (!supportsBrowserRedirect && !supportsNativeOAuthLaunch) {
    return const OAuthLaunch(OAuthLaunchOutcome.unsupported);
  }

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  final redirectUri = supportsBrowserRedirect
      ? Uri(
          scheme: browserCurrentUri().scheme,
          host: browserCurrentUri().host,
          port: browserCurrentUri().hasPort ? browserCurrentUri().port : null,
          path: '/auth/callback',
        ).toString()
      : ApiConfig.nativeOAuthCallbackUri;

  final authService = await ref.read(authServiceProviderAsync.future);
  await authService.setPendingOAuthRememberMe(rememberMe);

  final authUrl = Uri(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    path: '${ApiConfig.apiPrefix}/oauth/$provider',
    queryParameters: {
      'redirect_uri': redirectUri,
      if (linkToken != null && linkToken.isNotEmpty) 'link': linkToken,
    },
  ).toString();

  if (supportsBrowserRedirect) {
    redirectBrowser(authUrl);
    return const OAuthLaunch(OAuthLaunchOutcome.redirecting);
  }

  final result = await startNativeOAuthSession(
    authUrl,
    callbackScheme: Uri.parse(ApiConfig.nativeOAuthCallbackUri).scheme,
  );
  switch (result.outcome) {
    case NativeOAuthOutcome.completed:
      return OAuthLaunch(
        OAuthLaunchOutcome.completed,
        callbackUrl: result.callbackUrl,
      );
    case NativeOAuthOutcome.pendingDeepLink:
      return const OAuthLaunch(OAuthLaunchOutcome.pendingDeepLink);
    case NativeOAuthOutcome.cancelled:
      return const OAuthLaunch(OAuthLaunchOutcome.cancelled);
  }
}
