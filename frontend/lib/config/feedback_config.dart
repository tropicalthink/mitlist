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

  static const String baseUrl = String.fromEnvironment(
    'REQTRACK_URL',
    defaultValue: 'https://reqtrack.tropicalthink.com',
  );

  static const String intakePath = '/api/v1/intake/requests';

  /// Feedback entry points are hidden entirely when no app key was baked in
  /// (e.g. self-hosted builds), mirroring how OAuth buttons are gated.
  static bool get isConfigured => appKey.isNotEmpty;
}
