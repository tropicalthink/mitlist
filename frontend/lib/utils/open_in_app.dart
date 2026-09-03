// Hands a web page over to the installed mobile app.
//
// A link such as https://app.mitlist.me/join/<code> only opens the app
// directly when the device has verified the domain (Android App Links via
// assetlinks.json, iOS Universal Links via the AASA file). Where that has not
// happened the link lands in the browser, and this is the way back: a button
// on the web page that navigates to a URL the installed app claims.

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Android application id, as declared in android/app/build.gradle.
const androidPackageName = 'me.mitlist';

/// True in a phone browser, the one place an app hand-off can succeed. On a
/// desktop browser the same navigation only produces a "no application"
/// error, so callers should not offer it there.
bool get isMobileBrowser =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isAndroidBrowser =>
    kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The custom-scheme form of an in-app [path] such as `/join/ABCD-1234`.
///
/// The triple slash matters: Flutter hands the router the URL's *path*, so
/// `mitlist:///join/<code>` arrives as `/join/<code>` and matches the route,
/// whereas `mitlist://join/<code>` would make `join` the host and leave the
/// router looking at `/<code>`. The Android intent filter and the iOS URL
/// type are written for the same shape.
Uri appSchemeUri(String path) {
  assert(path.startsWith('/'), 'path must be absolute: $path');
  return Uri.parse('mitlist://$path');
}

/// Builds the URL a phone browser should navigate to so the installed app
/// takes over [path].
///
/// On Android this is an Intent URL naming the package. Chrome resolves it
/// against the app's `mitlist` scheme filter, which needs no App Link
/// verification, and when the app is not installed it follows
/// [fallbackUrl] instead of showing an error page. Elsewhere it is the plain
/// custom-scheme link; iOS has no fallback mechanism, so Safari shows its own
/// "cannot open" alert when the app is missing.
///
/// [isAndroid] is a parameter rather than read from the platform so the
/// builder can be unit tested; callers pass [isAndroidBrowser].
Uri openInAppUri(
  String path, {
  required bool isAndroid,
  Uri? fallbackUrl,
}) {
  if (!isAndroid) return appSchemeUri(path);
  assert(path.startsWith('/'), 'path must be absolute: $path');
  final buf = StringBuffer('intent://$path#Intent')
    ..write(';scheme=mitlist')
    ..write(';package=$androidPackageName');
  if (fallbackUrl != null) {
    buf.write(
      ';S.browser_fallback_url=${Uri.encodeComponent(fallbackUrl.toString())}',
    );
  }
  buf.write(';end');
  return Uri.parse(buf.toString());
}
