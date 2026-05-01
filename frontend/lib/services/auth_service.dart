import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

/// Authentication service for managing user authentication.
///
/// This service handles:
/// - User registration
/// - User login
/// - Token refresh
/// - Logout
/// - Password reset
/// - User profile management
class AuthService {
  final Dio _dio;
  final Logger _logger = Logger();
  final SharedPreferences _prefs;

  AuthService._(this._dio, this._prefs);

  static Future<AuthService> create([Ref? ref]) async {
    final prefs = await SharedPreferences.getInstance();
    final dio = createApiClient(ref);
    return AuthService._(dio, prefs);
  }

  /// Registers a new user.
  ///
  /// Returns a [TokenPair] with access and refresh tokens.
  Future<TokenPair> register(
    RegisterRequest request, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Registration failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Logs in a user.
  ///
  /// Returns a [TokenPair] with access and refresh tokens.
  Future<TokenPair> login(
    LoginRequest request, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Login failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Refreshes the access token using a refresh token.
  ///
  /// Returns a new [TokenPair] with updated tokens.
  Future<TokenPair> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(
        tokenPair,
        persistSession: _prefs.getBool(ApiConfig.persistSessionKey) ?? true,
      );
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Token refresh failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Logs out the current user.
  ///
  /// Clears all stored tokens and user data.
  Future<void> logout() async {
    try {
      final refreshToken = _prefs.getString(ApiConfig.refreshTokenKey);
      if (refreshToken != null) {
        await _dio.post(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } on DioException catch (e) {
      _logger.e('Logout failed: ${e.response?.data}');
      // Continue to clear tokens even if logout API call fails
    }

    await _clearTokens();
  }

  /// Requests a password reset for the given email.
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post(
        '/auth/password-reset',
        data: {'email': email},
      );
    } on DioException catch (e) {
      _logger.e('Password reset request failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Confirms a password reset with the given token and new password.
  Future<void> confirmPasswordReset(String token, String newPassword) async {
    try {
      await _dio.post(
        '/auth/password-reset/confirm',
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      _logger.e('Password reset confirmation failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Completes an OAuth callback exchange and stores the issued session.
  Future<TokenPair> completeOAuthCallback({
    required String provider,
    required String code,
    required String redirectUri,
    required String state,
    String? idToken,
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/oauth/$provider/callback',
        data: {
          'code': code,
          'redirect_uri': redirectUri,
          'state': state,
          if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
        },
      );
      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('OAuth callback failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Stores an already-issued token pair from a backend OAuth redirect handoff.
  Future<void> saveTokenPair(
    TokenPair tokenPair, {
    required bool rememberMe,
  }) async {
    await _saveTokens(tokenPair, persistSession: rememberMe);
  }

  /// Persists the remember-me choice before handing off to a browser OAuth flow.
  Future<void> setPendingOAuthRememberMe(bool rememberMe) async {
    await _prefs.setBool(ApiConfig.pendingOAuthRememberMeKey, rememberMe);
  }

  /// Returns and clears the pending browser OAuth remember-me choice.
  Future<bool> consumePendingOAuthRememberMe() async {
    final rememberMe =
        _prefs.getBool(ApiConfig.pendingOAuthRememberMeKey) ?? true;
    await _prefs.remove(ApiConfig.pendingOAuthRememberMeKey);
    return rememberMe;
  }

  /// Creates a guest account.
  ///
  /// Returns a [TokenPair] with access and refresh tokens.
  Future<TokenPair> createGuest({bool rememberMe = true}) async {
    try {
      final response = await _dio.post('/auth/guest');

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Guest account creation failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Gets the current user's profile.
  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Get user failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Updates the current user's profile.
  Future<User> updateMe(UpdateUserRequest request) async {
    try {
      final response = await _dio.patch(
        '/auth/me',
        data: request.toJson(),
      );
      return User.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Update user failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Deletes the current user's account.
  Future<void> deleteMe() async {
    try {
      await _dio.delete('/auth/me');
      await _clearTokens();
    } on DioException catch (e) {
      _logger.e('Delete user failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Changes the current user's password.
  Future<void> changePassword(ChangePasswordRequest request) async {
    try {
      await _dio.post(
        '/auth/change-password',
        data: request.toJson(),
      );
    } on DioException catch (e) {
      _logger.e('Change password failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Converts a guest account to a full account.
  Future<TokenPair> convertGuest(
    ConvertGuestRequest request, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/guest/convert',
        data: request.toJson(),
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Convert guest failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Claims an account (for users who signed up with a different method).
  Future<TokenPair> claimAccount(
    ClaimAccountRequest request, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/claim-account',
        data: request.toJson(),
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logger.e('Claim account failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Checks if the user is authenticated.
  Future<bool> isAuthenticated() async {
    final token = _prefs.getString(ApiConfig.accessTokenKey);
    return token != null;
  }

  /// Restores a persisted session, clearing non-persistent sessions on restart.
  Future<bool> bootstrapSession() async {
    final token = _prefs.getString(ApiConfig.accessTokenKey);
    if (token == null) {
      return false;
    }

    final persistSession = _prefs.getBool(ApiConfig.persistSessionKey);
    if (persistSession == false) {
      await _clearTokens();
      return false;
    }

    return true;
  }

  /// Gets the stored access token.
  Future<String?> getAccessToken() async {
    return _prefs.getString(ApiConfig.accessTokenKey);
  }

  Future<void> _saveTokens(
    TokenPair tokenPair, {
    required bool persistSession,
  }) async {
    await _prefs.setString(ApiConfig.accessTokenKey, tokenPair.accessToken);
    await _prefs.setString(ApiConfig.refreshTokenKey, tokenPair.refreshToken);
    await _prefs.setBool(ApiConfig.persistSessionKey, persistSession);
    if (tokenPair.user != null) {
      await _prefs.setString(
        ApiConfig.userDataKey,
        jsonEncode(tokenPair.user!.toJson()),
      );
    }
  }

  /// Clears all stored tokens and user data.
  Future<void> _clearTokens() async {
    await _prefs.remove(ApiConfig.accessTokenKey);
    await _prefs.remove(ApiConfig.refreshTokenKey);
    await _prefs.remove(ApiConfig.userDataKey);
    await _prefs.remove(ApiConfig.persistSessionKey);
    await _prefs.remove(ApiConfig.pendingOAuthRememberMeKey);
  }

  Exception _handleError(DioException e) {
    return ApiException(ApiErrorMapper.fromDio(e));
  }
}
