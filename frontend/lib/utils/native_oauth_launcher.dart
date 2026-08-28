import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _oauthLauncherChannel = MethodChannel(
  'mitlist/oauth_launcher',
);

bool get supportsNativeOAuthLaunch {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// The outcome of an in-app OAuth sheet.
///
/// The two platforms end the flow differently, so the caller has to be able to
/// tell them apart rather than assuming a URL always comes back.
enum NativeOAuthOutcome {
  /// iOS: `ASWebAuthenticationSession` intercepted the `mitlist://` redirect
  /// and handed us [NativeOAuthResult.callbackUrl] directly.
  completed,

  /// Android: the Custom Tab is open. The redirect will arrive as a deep link
  /// and drive the router on its own — there is nothing more to do here.
  pendingDeepLink,

  /// The user dismissed the sheet. Not an error; the sign-in screen simply
  /// stays put.
  cancelled,
}

class NativeOAuthResult {
  const NativeOAuthResult(this.outcome, [this.callbackUrl]);

  final NativeOAuthOutcome outcome;

  /// The full `mitlist:///auth/callback?...` URL, set only when [outcome] is
  /// [NativeOAuthOutcome.completed].
  final String? callbackUrl;
}

/// Presents [url] in an in-app authentication sheet.
///
/// [callbackScheme] is the bare scheme (no `://`) the session watches for to
/// know the flow is over — iOS closes the sheet the moment a URL with that
/// scheme is loaded.
Future<NativeOAuthResult> startNativeOAuthSession(
  String url, {
  required String callbackScheme,
}) async {
  final callbackUrl = await _oauthLauncherChannel.invokeMethod<String>(
    'startAuthSession',
    {'url': url, 'callbackScheme': callbackScheme},
  );

  if (callbackUrl != null && callbackUrl.isNotEmpty) {
    return NativeOAuthResult(NativeOAuthOutcome.completed, callbackUrl);
  }

  // Android always answers null: the tab is open and the deep link finishes the
  // job. iOS answers null only when the user dismissed the sheet.
  return NativeOAuthResult(
    defaultTargetPlatform == TargetPlatform.iOS
        ? NativeOAuthOutcome.cancelled
        : NativeOAuthOutcome.pendingDeepLink,
  );
}
