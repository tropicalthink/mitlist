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

Future<void> launchNativeOAuthUrl(String url) async {
  await _oauthLauncherChannel.invokeMethod<void>('launchExternalUrl', {
    'url': url,
  });
}
