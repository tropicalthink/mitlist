// API configuration for the mitlist Flutter app.
//
// This file defines the base URL for the API and other configuration values.
// In production, these values should be loaded from environment variables or a
// secure configuration service.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// The base URL for the API.
  ///
  /// Set at build time via `--dart-define=API_BASE_URL=https://api.example.com`.
  /// Release builds MUST provide it — there is no production default baked in,
  /// so we never ship a binary silently pointing at a developer's machine.
  /// Debug builds fall back to the local Go backend for convenience.
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;

    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL is not set. Release builds must be built with '
        '--dart-define=API_BASE_URL=https://your-api-host (no trailing slash).',
      );
    }

    // Debug-only fallback to the local Go backend.
    // On Android emulators, "localhost" points to the emulator itself.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  /// The API path prefix.
  static const String apiPrefix = '/api/v1';

  /// The timeout for API requests in seconds.
  static const int requestTimeoutSeconds = 30;

  /// The timeout for API requests as a Duration.
  static const Duration requestTimeout = Duration(seconds: requestTimeoutSeconds);

  /// The header name for the authorization token.
  static const String authorizationHeader = 'Authorization';

  /// The prefix for the authorization token type.
  static const String authorizationPrefix = 'Bearer ';

  /// The key for the access token in shared preferences.
  static const String accessTokenKey = 'access_token';

  /// The key for the refresh token in shared preferences.
  static const String refreshTokenKey = 'refresh_token';

  /// The key for the user data in shared preferences.
  static const String userDataKey = 'user_data';

  /// Whether the current session should survive app restarts.
  static const String persistSessionKey = 'persist_session';

  /// Temporary remember-me choice saved across browser OAuth redirects.
  static const String pendingOAuthRememberMeKey = 'pending_oauth_remember_me';

  /// Native-app callback used for browser-based OAuth handoff on mobile.
  static const String nativeOAuthCallbackUri = 'mitlist:///auth/callback';

  /// Whether to verify SSL certificates.
  ///
  /// In production, this should be `true`.
  /// In development with self-signed certificates, this may need to be `false`.
  static const bool verifySsl = true;
}
