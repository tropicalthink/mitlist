import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration for Firebase App Check.
///
/// App Check is opt-in for every build so self-hosted releases remain
/// Firebase-free. Official release workflows explicitly pass
/// `--dart-define=APP_CHECK_ENABLED=true`. Web additionally needs both the
/// reCAPTCHA site key and the Firebase web app settings:
///
/// ```text
/// --dart-define=APP_CHECK_WEB_RECAPTCHA_SITE_KEY=...
/// --dart-define=FIREBASE_API_KEY=...
/// --dart-define=FIREBASE_APP_ID=...
/// --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
/// --dart-define=FIREBASE_PROJECT_ID=...
/// ```
///
/// These Firebase web values identify the app; they are not secrets. Native
/// builds continue to use google-services.json/GoogleService-Info.plist.
class AppCheckConfig {
  static const String _enabledOverride = String.fromEnvironment(
    'APP_CHECK_ENABLED',
    defaultValue: '',
  );

  static const String webRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static const String _firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String _firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String _firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String _firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String _firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  /// Disabled unless the build explicitly opts in. Official builds enforce
  /// the true value in CI; local and self-hosted builds remain independent.
  static bool get enabled => _enabledOverride == 'true';

  static bool get webConfigured =>
      webRecaptchaSiteKey.isNotEmpty && firebaseWebOptions != null;

  /// Firebase.initializeApp requires options on web. Return null rather than
  /// constructing a partial configuration, so missing release defines fail
  /// with a useful message and never silently send an unverified request.
  static FirebaseOptions? get firebaseWebOptions {
    if (_firebaseApiKey.isEmpty ||
        _firebaseAppId.isEmpty ||
        _firebaseMessagingSenderId.isEmpty ||
        _firebaseProjectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      messagingSenderId: _firebaseMessagingSenderId,
      projectId: _firebaseProjectId,
      authDomain: _firebaseAuthDomain.isEmpty ? null : _firebaseAuthDomain,
      storageBucket:
          _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
    );
  }

  static String? get configurationError {
    if (!enabled) return null;
    if (kIsWeb && webRecaptchaSiteKey.isEmpty) {
      return 'APP_CHECK_WEB_RECAPTCHA_SITE_KEY is missing';
    }
    if (kIsWeb && firebaseWebOptions == null) {
      return 'Firebase web app dart-defines are incomplete';
    }
    return null;
  }
}
