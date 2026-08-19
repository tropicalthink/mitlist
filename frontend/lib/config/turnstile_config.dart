import 'package:flutter/foundation.dart';

/// Build-time configuration for Cloudflare Turnstile.
///
/// Turnstile guards guest sign-up on the **web** only. Mobile keeps Firebase
/// App Check (Play Integrity / App Attest), whose web equivalent would be
/// reCAPTCHA Enterprise — a GCP billing dependency we do not want for a single
/// unauthenticated endpoint. See [AppCheckConfig] for the mobile half.
///
/// Official web builds pass `--dart-define=TURNSTILE_SITE_KEY=...`. Self-hosted
/// builds that omit it stay challenge-free, exactly as they stay App
/// Check-free; the API then accepts unattested guests, which is the
/// self-hoster's call to make.
///
/// The widget must be configured as **Invisible** in the Cloudflare dashboard.
/// A Managed widget can decide to show an interactive challenge, and this
/// integration renders into an off-screen container where the user could never
/// complete one.
class TurnstileConfig {
  static const String siteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
    defaultValue: '',
  );

  /// Web-only: on mobile the equivalent protection is App Check.
  static bool get enabled => kIsWeb && siteKey.isNotEmpty;
}
