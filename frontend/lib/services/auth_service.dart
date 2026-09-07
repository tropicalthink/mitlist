import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'app_check_service.dart';
import 'turnstile_service.dart';
import 'fcm_service.dart';
import 'push_subscription_service.dart';
import 'token_store.dart';
import 'dio_platform.dart';
import 'token_refresh_coordinator.dart';

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
  static const _installIdKey = 'mitlist_install_id';
  final Dio _dio;
  final Logger _logger = Logger();
  final SharedPreferences _prefs;
  final TokenStore _tokenStore;
  final AppCheckTokenProvider _appCheck;
  final TurnstileTokenProvider _turnstile;

  void _logFailure(String operation, DioException error) {
    if (!kDebugMode) return;
    _logger.e(
        '$operation failed (status: ${error.response?.statusCode}, type: ${error.type})');
  }

  /// Optional callback invoked during logout to wipe the local Drift database.
  /// Wrapped in try/catch so a wipe failure never blocks token clearance.
  final Future<void> Function()? _wipeLocalData;

  AuthService._(this._dio, this._prefs, this._tokenStore,
      {Future<void> Function()? wipeLocalData,
      AppCheckTokenProvider? appCheck,
      TurnstileTokenProvider? turnstile})
      : _wipeLocalData = wipeLocalData,
        _appCheck = appCheck ?? FirebaseAppCheckService.instance,
        _turnstile = turnstile ?? TurnstileService.instance;

  /// Test-only constructor that accepts all dependencies directly.
  @visibleForTesting
  AuthService.forTest(
    Dio dio,
    SharedPreferences prefs,
    TokenStore tokenStore, {
    Future<void> Function()? wipeLocalData,
    AppCheckTokenProvider? appCheck,
    TurnstileTokenProvider? turnstile,
  }) : this._(dio, prefs, tokenStore,
            wipeLocalData: wipeLocalData,
            appCheck: appCheck,
            turnstile: turnstile);

  static Future<AuthService> create([Ref? ref]) async {
    final prefs = await SharedPreferences.getInstance();
    final dio = resolveDio(ref);
    final store = SecureTokenStore.shared;
    await store.migrateFromPrefs(prefs);
    await _attachInstallIdentity(dio, prefs);
    return AuthService._(dio, prefs, store);
  }

  /// Creates an [AuthService] wired to wipe the local Drift database on logout.
  static Future<AuthService> createWithWipe({
    Ref? ref,
    required Future<void> Function() wipeLocalData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dio = resolveDio(ref);
    final store = SecureTokenStore.shared;
    await store.migrateFromPrefs(prefs);
    await _attachInstallIdentity(dio, prefs);
    return AuthService._(dio, prefs, store, wipeLocalData: wipeLocalData);
  }

  static Future<void> _attachInstallIdentity(
      Dio dio, SharedPreferences prefs) async {
    var installId = prefs.getString(_installIdKey);
    if (installId == null || installId.isEmpty) {
      installId = const Uuid().v4();
      await prefs.setString(_installIdKey, installId);
    }
    dio.options.headers['X-Mitlist-Install-ID'] = installId;
  }

  /// Registers a new user.
  ///
  /// Registration does not create a session until email ownership is proven.
  Future<RegistrationResult> register(
    RegisterRequest request, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      return RegistrationResult.fromJson(response.data);
    } on DioException catch (e) {
      _logFailure('Registration', e);
      throw apiException(e);
    }
  }

  Future<TokenPair> verifyEmail(
    String token, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-email',
        data: {'token': token},
      );
      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logFailure('Email verification', e);
      throw apiException(e);
    }
  }

  Future<void> resendEmailVerification(String email) async {
    try {
      await _dio.post(
        '/auth/verify-email/resend',
        data: {'email': email},
      );
    } on DioException catch (e) {
      _logFailure('Email verification resend', e);
      throw apiException(e);
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
      _logFailure('Login', e);
      throw apiException(e);
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
      _logFailure('Token refresh', e);
      throw apiException(e);
    }
  }

  /// Logs out the current user.
  ///
  /// Clears all stored tokens and user data.
  Future<void> logout() async {
    final accessToken = await _tokenStore.getAccessToken();
    final refreshToken = await _tokenStore.getRefreshToken();
    try {
      await FcmService.reset().timeout(const Duration(seconds: 2));
    } catch (e) {
      if (kDebugMode) _logger.e('FCM reset failed (${e.runtimeType})');
    }

    final cleanupDio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      headers: {
        'Content-Type': 'application/json',
        if (kIsWeb) 'X-Mitlist-Client': 'web',
        if (accessToken != null)
          ApiConfig.authorizationHeader:
              '${ApiConfig.authorizationPrefix}$accessToken',
      },
    ));
    configureDioForPlatform(cleanupDio);
    try {
      await Future.wait<void>([
        FcmService.unregisterToken(cleanupDio),
        PushSubscriptionService(_tokenStore).unsubscribe(),
        if (refreshToken != null || kIsWeb)
          cleanupDio.post<void>('/auth/logout',
              data: {'refresh_token': refreshToken ?? ''}),
      ]).timeout(const Duration(seconds: 4));
    } on DioException catch (e) {
      _logFailure('Logout cleanup', e);
    } catch (e) {
      if (kDebugMode) _logger.e('Logout cleanup failed (${e.runtimeType})');
    } finally {
      cleanupDio.close(force: true);
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    await _clearTokens();
    if (_wipeLocalData != null) {
      try {
        await _wipeLocalData();
      } catch (e) {
        if (kDebugMode) {
          _logger.e('Failed to wipe local database (${e.runtimeType})');
        }
      }
    }
  }

  /// Requests a password reset for the given email.
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post(
        '/auth/password-reset',
        data: {'email': email},
      );
    } on DioException catch (e) {
      _logFailure('Password reset request', e);
      throw apiException(e);
    }
  }

  /// Confirms a password reset with the given token and new password.
  ///
  /// The emailed code proved the address, so the server answers with a
  /// session and this saves it exactly like a login does, honouring
  /// [rememberMe]. Callers flip auth state afterwards rather than sending the
  /// person to type the password they just chose.
  Future<TokenPair> confirmPasswordReset(
    String token,
    String newPassword, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/password-reset/confirm',
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logFailure('Password reset confirmation', e);
      throw apiException(e);
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
      _logFailure('OAuth callback', e);
      throw apiException(e);
    }
  }

  /// Stores an already-issued token pair from a backend OAuth redirect handoff.
  Future<void> saveTokenPair(
    TokenPair tokenPair, {
    required bool rememberMe,
  }) async {
    await _saveTokens(tokenPair, persistSession: rememberMe);
  }

  Future<TokenPair> exchangeOAuthHandoff(
    String code, {
    required bool rememberMe,
  }) async {
    try {
      final response =
          await _dio.post('/oauth/handoff/exchange', data: {'code': code});
      final pair = TokenPair.fromJson(response.data);
      await _saveTokens(pair, persistSession: rememberMe);
      return pair;
    } on DioException catch (e) {
      _logFailure('OAuth handoff exchange', e);
      throw apiException(e);
    }
  }

  /// Mints the one-time token that turns a provider round-trip into an
  /// upgrade of the current guest account rather than a fresh sign-in.
  Future<String> createOAuthLinkToken() async {
    try {
      final response = await _dio.post('/auth/oauth-link');
      return response.data['link_token'] as String;
    } on DioException catch (e) {
      _logFailure('OAuth link token', e);
      throw apiException(e);
    }
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

  /// Parks the post-sign-in destination before handing off to a browser
  /// OAuth flow. Null or empty clears any earlier one, so a plain sign-in
  /// never inherits a stale invite.
  Future<void> setPendingOAuthNavigation(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove(ApiConfig.pendingOAuthNavigationKey);
      return;
    }
    await _prefs.setString(ApiConfig.pendingOAuthNavigationKey, path);
  }

  /// Returns and clears the parked post-sign-in destination.
  Future<String?> consumePendingOAuthNavigation() async {
    final path = _prefs.getString(ApiConfig.pendingOAuthNavigationKey);
    await _prefs.remove(ApiConfig.pendingOAuthNavigationKey);
    return path;
  }

  /// Creates a guest account.
  ///
  /// Returns a [TokenPair] with access and refresh tokens.
  Future<TokenPair> createGuest({bool rememberMe = true}) async {
    try {
      // Attestation is intentionally scoped to this unauthenticated, abuse-
      // sensitive endpoint. Both tokens are fetched immediately before the
      // request so expired ones are refreshed rather than cached in Dio
      // headers, and both are single-platform: App Check returns null on web,
      // Turnstile returns null everywhere else. The API accepts either.
      final appCheckToken = await _appCheck.getToken();
      final turnstileToken = await _turnstile.getToken();
      final response = await _dio.post(
        '/auth/guest',
        options: Options(
          headers: {
            if (appCheckToken != null && appCheckToken.isNotEmpty)
              'X-Firebase-AppCheck': appCheckToken,
            if (turnstileToken != null && turnstileToken.isNotEmpty)
              'X-Mitlist-Turnstile': turnstileToken,
          },
        ),
      );

      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(tokenPair, persistSession: rememberMe);
      return tokenPair;
    } on DioException catch (e) {
      _logFailure('Guest account creation', e);
      throw apiException(e);
    }
  }

  /// Gets the current user's profile.
  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final user = User.fromJson(response.data);
      // Keep the offline copy current so [cachedMe] never lags a rename or
      // verification the server already knows about.
      await _prefs.setString(ApiConfig.userDataKey, jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      _logFailure('Get user', e);
      throw apiException(e);
    }
  }

  /// The signed-in user as last seen from the server, or null before any
  /// session was saved. Screens that only need the user's id (to label "you"
  /// in a balance or highlight a share) read this first and refresh via
  /// [getMe] in the background, so an offline launch paints cached data
  /// instead of waiting out a connect timeout or failing outright.
  User? get cachedMe {
    final raw = _prefs.getString(ApiConfig.userDataKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
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
      _logFailure('Update user', e);
      throw apiException(e);
    }
  }

  /// Deletes the current user's account.
  Future<void> deleteMe() async {
    try {
      await _dio.delete('/auth/me');
      await _clearTokens();
    } on DioException catch (e) {
      _logFailure('Delete user', e);
      throw apiException(e);
    }
  }

  /// Changes the current user's password.
  Future<void> changePassword(ChangePasswordRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/change-password',
        data: request.toJson(),
      );
      final tokenPair = TokenPair.fromJson(response.data);
      await _saveTokens(
        tokenPair,
        persistSession: _prefs.getBool(ApiConfig.persistSessionKey) ?? true,
      );
    } on DioException catch (e) {
      _logFailure('Change password', e);
      throw apiException(e);
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
      _logFailure('Convert guest', e);
      throw apiException(e);
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
      _logFailure('Claim account', e);
      throw apiException(e);
    }
  }

  /// Checks if the user is authenticated.
  Future<bool> isAuthenticated() async {
    final token = await _tokenStore.getAccessToken();
    return token != null;
  }

  /// Restores a persisted session, clearing non-persistent sessions on restart.
  Future<bool> bootstrapSession() async {
    final token = await _tokenStore.getAccessToken();
    if (token == null) {
      if (kIsWeb) {
        final outcome = await TokenRefreshCoordinator(
          _tokenStore,
          _dio,
        ).refreshDetailed();
        return outcome.type == TokenRefreshOutcomeType.success;
      }
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
    return _tokenStore.getAccessToken();
  }

  Future<void> _saveTokens(
    TokenPair tokenPair, {
    required bool persistSession,
  }) async {
    if ((kIsWeb || !persistSession) && _tokenStore is SecureTokenStore) {
      await _tokenStore.saveEphemeral(
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
    } else {
      await _tokenStore.save(
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
    }
    await _prefs.setBool(ApiConfig.persistSessionKey, persistSession);
    if (tokenPair.user != null) {
      await _prefs.setString(
        ApiConfig.userDataKey,
        jsonEncode(tokenPair.user!.toJson()),
      );
    }
  }

  /// Clears all stored tokens, user data, and user-specific UI preferences.
  Future<void> _clearTokens() async {
    await _tokenStore.clear();
    await _prefs.remove(ApiConfig.userDataKey);
    await _prefs.remove(ApiConfig.persistSessionKey);
    await _prefs.remove(ApiConfig.pendingOAuthRememberMeKey);
    await _prefs.remove('hub_quick_start_dismissed');
    await _prefs.remove('chores_filter_me');
    await _prefs.remove('calendar_view_mode');
  }
}
