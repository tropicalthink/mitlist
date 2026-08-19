import 'package:flutter/foundation.dart';

/// Build-time configuration for Firebase App Check.
///
/// App Check is opt-in for every build so self-hosted releases remain
/// Firebase-free, and it is **mobile-only**: official release workflows pass
/// `--dart-define=APP_CHECK_ENABLED=true` and the app attests with Play
/// Integrity or App Attest. Web has no App Check provider here — see
/// [TurnstileConfig] for what guards guest sign-up in the browser.
///
/// Native builds read Firebase settings from google-services.json and
/// GoogleService-Info.plist.
class AppCheckConfig {
  static const String _enabledOverride = String.fromEnvironment(
    'APP_CHECK_ENABLED',
    defaultValue: '',
  );

  /// Disabled unless the build explicitly opts in. Official builds enforce
  /// the true value in CI; local and self-hosted builds remain independent.
  ///
  /// Never enabled on web: the only web provider is reCAPTCHA Enterprise, and
  /// web attests with Cloudflare Turnstile instead (see [TurnstileConfig]).
  /// The platform check lives here rather than at the call sites so a stray
  /// `--dart-define=APP_CHECK_ENABLED=true` in a web build cannot make guest
  /// sign-up demand a token no provider can mint.
  static bool get enabled => !kIsWeb && _enabledOverride == 'true';

  /// Native builds read their Firebase settings from google-services.json and
  /// GoogleService-Info.plist, so there is nothing further to validate here.
  static String? get configurationError => null;
}
