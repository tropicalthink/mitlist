import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import 'browser_redirect.dart';
import 'friendly_error.dart';
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

/// The screen-side half of a provider round-trip, shared by every screen that
/// offers "Continue with Google / Apple" as a way in: it remembers which
/// button is waiting, resets it when the person backs out of Android's Custom
/// Tab, parks an invite code so the callback can still honour it, and turns
/// every [OAuthLaunchOutcome] into either navigation or a message.
///
/// The host state must also mix in [WidgetsBindingObserver]; registering and
/// removing it happens here.
mixin OAuthLaunchHandler<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  String? _oauthProvider;

  /// Provider whose in-app sign-in sheet is currently open, or null. Screens
  /// read it to spin one button and disable the others.
  String? get oauthProvider => _oauthProvider;

  /// Where a failed or unsupported launch is reported. A null [message]
  /// clears whatever was shown. Implementations call setState themselves,
  /// because only the screen knows where the text belongs.
  void showOAuthError(String? message);

  /// Whether the session should outlive the app closing. The login screen has
  /// a checkbox for it; screens without one keep people signed in.
  bool get oauthRememberMe => true;

  /// The invite code carried on the URL, or null when there is none — or no
  /// router at all, as when the screen is built on its own.
  String? get inviteCode => GoRouter.maybeOf(context) == null
      ? null
      : GoRouterState.of(context).uri.queryParameters['invite'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Android's Custom Tab returns no result, so backing out of it would
    // otherwise leave the button spinning forever. Coming back to the
    // foreground with a sheet still marked open means the user left it; a
    // successful callback routes away from this screen before this runs.
    if (state == AppLifecycleState.resumed && _oauthProvider != null) {
      setState(() => _oauthProvider = null);
    }
  }

  /// Sends the person to [provider] and handles every way the trip can end.
  Future<void> startOAuth(String provider) async {
    final l10n = AppLocalizations.of(context)!;
    // The callback screen navigates to whatever this holds, so an invite has
    // to be parked before control leaves for the browser.
    final invite = inviteCode;
    if (invite != null && invite.isNotEmpty) {
      ref.read(pendingAuthNavigationProvider.notifier).state =
          '/join/${Uri.encodeComponent(invite)}';
    }
    setState(() => _oauthProvider = provider);
    showOAuthError(null);

    try {
      final launch = await launchOAuthProvider(
        ref,
        provider: provider,
        rememberMe: oauthRememberMe,
      );
      if (!mounted) return;

      switch (launch.outcome) {
        case OAuthLaunchOutcome.unsupported:
          setState(() => _oauthProvider = null);
          showOAuthError(l10n.authLoginOAuthUnsupported(provider));
        case OAuthLaunchOutcome.redirecting:
          // The browser is leaving this page; nothing more to do here.
          break;
        case OAuthLaunchOutcome.completed:
          // iOS's sheet captured the redirect itself, so no deep link is
          // coming — hand the callback to the router directly.
          final callback = Uri.parse(launch.callbackUrl!);
          context.go('/auth/callback?${callback.query}');
        case OAuthLaunchOutcome.pendingDeepLink:
          // Android: the Custom Tab holds the screen until the mitlist://
          // redirect re-enters the app. Nothing to do but wait.
          break;
        case OAuthLaunchOutcome.cancelled:
          setState(() => _oauthProvider = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _oauthProvider = null);
      showOAuthError(friendlyErrorMessage(e, l10n));
    }
  }
}
