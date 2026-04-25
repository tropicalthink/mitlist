// API configuration for the mitlist Flutter app.
//
// This file defines the base URL for the API and other configuration values.
// In production, these values should be loaded from environment variables or a
// secure configuration service.

class ApiConfig {
  /// The base URL for the API.
  ///
  /// In development, this should point to the local Go backend.
  /// In production, this should point to the production API server.
  static const String baseUrl = 'http://localhost:8000';

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

  /// Whether to verify SSL certificates.
  ///
  /// In production, this should be `true`.
  /// In development with self-signed certificates, this may need to be `false`.
  static const bool verifySsl = true;
}
