import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/app_check_config.dart';
import 'api_error_mapper.dart';

/// Supplies an App Check token for requests that need abuse protection.
abstract interface class AppCheckTokenProvider {
  Future<String?> getToken();
}

/// App Check integration used by guest account creation.
///
/// It is intentionally a small provider rather than a Dio interceptor: guest
/// creation is the only unauthenticated endpoint that currently needs this
/// attestation, and a token is fetched immediately before that request.
class FirebaseAppCheckService implements AppCheckTokenProvider {
  FirebaseAppCheckService._();

  static final FirebaseAppCheckService instance = FirebaseAppCheckService._();
  static final Logger _log = Logger();

  static Future<bool>? _activation;
  static bool _active = false;
  static String? _activationError;

  /// Activates App Check once. Calling this is safe when Firebase is absent:
  /// self-hosted/debug builds simply remain Firebase-free.
  static Future<bool> initialize() async {
    if (!AppCheckConfig.enabled) return false;
    if (_active) return true;
    final inFlight = _activation;
    if (inFlight != null) return inFlight;

    final attempt = _activate();
    _activation = attempt;
    try {
      return await attempt;
    } finally {
      // Configuration may be corrected or a transient provider failure may
      // clear while the app remains open. Preserve only successful activation.
      if (!_active) _activation = null;
    }
  }

  static Future<bool> _activate() async {
    final configError = AppCheckConfig.configurationError;
    if (configError != null) {
      _activationError = configError;
      _log.w('Firebase App Check is enabled but not configured: $configError');
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          final options = AppCheckConfig.firebaseWebOptions;
          if (options == null) return false;
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }

      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        providerWeb: kDebugMode
            ? WebDebugProvider()
            : ReCaptchaV3Provider(AppCheckConfig.webRecaptchaSiteKey),
      );
      _active = true;
      _activationError = null;
      return true;
    } catch (error) {
      _activationError = error.toString();
      _log.w('Firebase App Check activation failed: $error');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    if (!AppCheckConfig.enabled) return null;
    if (!await initialize() || !_active) {
      throw AppCheckUnavailableException(
        'Secure guest sign-up is unavailable because Firebase App Check '
        'is not configured for this build${_activationError == null ? '' : '.'}',
      );
    }

    try {
      // This token is sent to mitlist's Go API rather than a Firebase product.
      // Firebase recommends limited-use tokens for sensitive non-Firebase
      // backends. The API currently verifies authenticity and expiry; it does
      // not claim server-side replay consumption.
      final token = await FirebaseAppCheck.instance.getLimitedUseToken();
      if (token.isEmpty) {
        throw const AppCheckUnavailableException(
          'Secure guest sign-up could not obtain an App Check token. Please try again.',
        );
      }
      return token;
    } catch (error) {
      if (error is AppCheckUnavailableException) rethrow;
      _log.w('Firebase App Check token request failed: $error');
      throw const AppCheckUnavailableException(
        'Secure guest sign-up could not be verified. Please try again.',
      );
    }
  }
}

/// Clean error shown when a release build is missing its App Check setup.
class AppCheckUnavailableException extends ApiException {
  const AppCheckUnavailableException(super.message);
}
