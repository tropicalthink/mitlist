/// Configuration for the in-app feature request intake.
///
/// Feedback is sent to the studio's request tracker (reqtrack/Staffroom), not
/// the mitlist backend. Both values are baked in at build time:
///
/// ```
/// --dart-define=REQTRACK_APP_KEY=sk_... \
/// --dart-define=REQTRACK_URL=https://reqtrack.tropicalthink.com
/// ```
///
/// The app key is the per-app intake key issued when mitlist was registered in
/// the tracker dashboard; it only permits submitting requests, never reading.
class FeedbackConfig {
  static const String appKey =
      String.fromEnvironment('REQTRACK_APP_KEY', defaultValue: '');

  /// Where the tracker lives when no override is supplied.
  static const String defaultBaseUrl = 'https://reqtrack.tropicalthink.com';

  // Deliberately defaults to '' rather than [defaultBaseUrl]: the release build
  // always passes `--dart-define=REQTRACK_URL=...`, so an unset CI secret
  // arrives as an empty (but *defined*) value, which would shadow a non-empty
  // default. Resolve the fallback in [baseUrl] instead.
  static const String _baseUrlOverride =
      String.fromEnvironment('REQTRACK_URL', defaultValue: '');

  /// Tracker origin, without a trailing slash so [intakePath] appends cleanly.
  static String get baseUrl {
    final trimmed = _baseUrlOverride.trim().replaceAll(RegExp(r'/+$'), '');
    return trimmed.isEmpty ? defaultBaseUrl : trimmed;
  }

  static const String intakePath = '/api/v1/intake/requests';

  /// Feedback entry points are hidden entirely when no app key was baked in
  /// (e.g. self-hosted builds), mirroring how OAuth buttons are gated.
  static bool get isConfigured => appKey.isNotEmpty;
}
