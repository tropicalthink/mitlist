import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mitlist/config/api_config.dart';
import 'package:mitlist/services/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureTokenStore.migrateFromPrefs', () {
    test('copies tokens from SharedPreferences to secure storage and removes them', () async {
      SharedPreferences.setMockInitialValues({
        ApiConfig.accessTokenKey: 'old-access',
        ApiConfig.refreshTokenKey: 'old-refresh',
      });

      final prefs = await SharedPreferences.getInstance();
      final store = SecureTokenStore();

      await store.migrateFromPrefs(prefs);

      // Tokens are now in secure storage.
      expect(await store.getAccessToken(), 'old-access');
      expect(await store.getRefreshToken(), 'old-refresh');

      // Legacy keys are gone from SharedPreferences.
      expect(prefs.getString(ApiConfig.accessTokenKey), isNull);
      expect(prefs.getString(ApiConfig.refreshTokenKey), isNull);
    });

    test('migration is idempotent — running twice does not duplicate or clear', () async {
      SharedPreferences.setMockInitialValues({
        ApiConfig.accessTokenKey: 'old-access',
        ApiConfig.refreshTokenKey: 'old-refresh',
      });

      final prefs = await SharedPreferences.getInstance();
      final store = SecureTokenStore();

      // First run.
      await store.migrateFromPrefs(prefs);
      expect(await store.getAccessToken(), 'old-access');
      expect(await store.getRefreshToken(), 'old-refresh');

      // Simulate a fresh store instance (clears in-memory cache).
      final store2 = SecureTokenStore();

      // Second run — secure storage already has a refresh token so migration is
      // skipped, and nothing is corrupted.
      await store2.migrateFromPrefs(prefs);
      expect(await store2.getAccessToken(), 'old-access');
      expect(await store2.getRefreshToken(), 'old-refresh');
    });

    test('does nothing when SharedPreferences has no legacy tokens', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SecureTokenStore();

      await store.migrateFromPrefs(prefs);

      expect(await store.getAccessToken(), isNull);
      expect(await store.getRefreshToken(), isNull);
    });

    test('does nothing when secure storage already has a refresh token', () async {
      // Pre-populate secure storage (already migrated or fresh install with new app).
      FlutterSecureStorage.setMockInitialValues({
        ApiConfig.refreshTokenKey: 'current-refresh',
        ApiConfig.accessTokenKey: 'current-access',
      });
      SharedPreferences.setMockInitialValues({
        // These would be stale — migration must not overwrite secure storage.
        ApiConfig.accessTokenKey: 'stale-access',
        ApiConfig.refreshTokenKey: 'stale-refresh',
      });

      final prefs = await SharedPreferences.getInstance();
      final store = SecureTokenStore();

      await store.migrateFromPrefs(prefs);

      // Existing secure-storage values are untouched.
      expect(await store.getAccessToken(), 'current-access');
      expect(await store.getRefreshToken(), 'current-refresh');
    });
  });

  group('SecureTokenStore basic operations', () {
    test('save and retrieve tokens', () async {
      final store = SecureTokenStore();

      await store.save(accessToken: 'acc', refreshToken: 'ref');
      expect(await store.getAccessToken(), 'acc');
      expect(await store.getRefreshToken(), 'ref');
    });

    test('clear removes tokens', () async {
      final store = SecureTokenStore();
      await store.save(accessToken: 'acc', refreshToken: 'ref');

      await store.clear();
      expect(await store.getAccessToken(), isNull);
      expect(await store.getRefreshToken(), isNull);
    });

    test('cache is invalidated on save', () async {
      final store = SecureTokenStore();
      await store.save(accessToken: 'first', refreshToken: 'ref');
      // Prime cache.
      expect(await store.getAccessToken(), 'first');

      // Update — cache must reflect new value.
      await store.save(accessToken: 'second', refreshToken: 'ref2');
      expect(await store.getAccessToken(), 'second');
      expect(await store.getRefreshToken(), 'ref2');
    });
  });
}
