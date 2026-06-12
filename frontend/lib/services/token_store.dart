import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Abstraction over the secure token storage backend.
///
/// Concrete implementations must be safe to call concurrently; in particular
/// [save] and [clear] invalidate any cached state.
abstract class TokenStore {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

/// [TokenStore] backed by [FlutterSecureStorage] (platform keystore /
/// iOS Keychain / Android Keystore / WebCrypto-wrapped localStorage on web).
///
/// An in-memory cache reduces repeated keystore reads on hot paths (e.g. the
/// Dio auth interceptor). The cache is invalidated on every [save] and [clear].
class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage _storage;
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> getAccessToken() async {
    _cachedAccessToken ??=
        await _storage.read(key: ApiConfig.accessTokenKey);
    return _cachedAccessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    _cachedRefreshToken ??=
        await _storage.read(key: ApiConfig.refreshTokenKey);
    return _cachedRefreshToken;
  }

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: ApiConfig.accessTokenKey, value: accessToken);
    await _storage.write(key: ApiConfig.refreshTokenKey, value: refreshToken);
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: ApiConfig.accessTokenKey);
    await _storage.delete(key: ApiConfig.refreshTokenKey);
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
  }

  /// One-time migration: if [prefs] holds token values under the legacy keys
  /// but secure storage does not yet have a refresh token, copy both tokens
  /// into secure storage and remove them from [prefs]. Idempotent.
  Future<void> migrateFromPrefs(SharedPreferences prefs) async {
    // Only migrate when secure storage is still empty.
    final existing = await _storage.read(key: ApiConfig.refreshTokenKey);
    if (existing != null) return; // already migrated or fresh install

    final legacyAccess = prefs.getString(ApiConfig.accessTokenKey);
    final legacyRefresh = prefs.getString(ApiConfig.refreshTokenKey);

    if (legacyRefresh == null) return; // nothing to migrate

    await _storage.write(
      key: ApiConfig.refreshTokenKey,
      value: legacyRefresh,
    );
    _cachedRefreshToken = legacyRefresh;

    if (legacyAccess != null) {
      await _storage.write(
        key: ApiConfig.accessTokenKey,
        value: legacyAccess,
      );
      _cachedAccessToken = legacyAccess;
    }

    await prefs.remove(ApiConfig.accessTokenKey);
    await prefs.remove(ApiConfig.refreshTokenKey);
  }
}

/// Riverpod provider for the application-wide [TokenStore].
///
/// Override this in tests with a [FakeTokenStore] (defined in the test tree).
final tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});
