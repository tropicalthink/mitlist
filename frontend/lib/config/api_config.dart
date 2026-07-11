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
  /// A self-hoster can override it at runtime from the login screen; the
  /// override is persisted under [serverUrlKey] and applied in `main()` before
  /// the first network call, so store builds work against any server.
  /// Debug builds fall back to the local Go backend for convenience.
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Preference key holding the user-chosen server URL ('' / absent = default).
  static const String serverUrlKey = 'custom_server_url';

  static String? _runtimeBaseUrl;

  /// The user-chosen server URL, if any. Set from `main()` at startup and by
  /// the login screen's server sheet. Pass null/empty to return to [defaultBaseUrl].
  static String? get runtimeBaseUrl => _runtimeBaseUrl;

  static void setRuntimeBaseUrl(String? url) {
    final trimmed = url?.trim().replaceAll(RegExp(r'/+$'), '');
    _runtimeBaseUrl = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The server the build ships with (dart-define, or the local Go backend in
  /// debug). Empty when a release build was made without API_BASE_URL — such
  /// builds are only usable once the user picks a server.
  static String get defaultBaseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (kReleaseMode) return '';

    // Debug-only fallback to the local Go backend.
    // On Android emulators, "localhost" points to the emulator itself.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  /// Whether a usable server URL exists (runtime override or build default).
  static bool get isConfigured =>
      _runtimeBaseUrl != null || defaultBaseUrl.isNotEmpty;

  static String get baseUrl => _runtimeBaseUrl ?? defaultBaseUrl;

  /// The API path prefix.
  static const String apiPrefix = '/api/v1';

  /// The timeout for API requests in seconds.
  static const int requestTimeoutSeconds = 30;

  /// The timeout for API requests as a Duration.
  static const Duration requestTimeout =
      Duration(seconds: requestTimeoutSeconds);

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
