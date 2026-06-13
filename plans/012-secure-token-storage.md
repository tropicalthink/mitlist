# Plan 012: Move auth tokens from SharedPreferences to flutter_secure_storage

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/services/auth_service.dart frontend/lib/services/api_client.dart frontend/lib/services/sse_service.dart frontend/lib/config/api_config.dart frontend/pubspec.yaml`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (auth regression = locked-out users; needs a migration path for existing installs)
- **Depends on**: plans/009-frontend-test-baseline.md
- **Category**: security
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

Access and refresh tokens are stored as plain strings in SharedPreferences,
which is included in OS backups (Android auto-backup, iTunes/Finder backups) and
trivially readable on rooted/jailbroken devices. The refresh token is long-lived
— exfiltrating it grants persistent account access. Platform keystores
(Android Keystore / iOS Keychain via `flutter_secure_storage`) are the standard
fix. The user-profile JSON cache and UI prefs can stay in SharedPreferences —
only the two tokens move.

## Current state

- `frontend/pubspec.yaml` — `flutter_secure_storage` is NOT a dependency;
  `shared_preferences: ^2.3.5` is.
- Token keys: `frontend/lib/config/api_config.dart:56,59` —
  `accessTokenKey = 'access_token'`, `refreshTokenKey = 'refresh_token'`.
- Write sites: `frontend/lib/services/auth_service.dart:335–349` (`_saveTokens`)
  and `frontend/lib/services/api_client.dart:~117` (token-refresh interceptor
  writes rotated tokens). Clear site: `auth_service.dart:351–360` (`_clearTokens`).
- Read sites: enumerate with
  `grep -rn "accessTokenKey\|refreshTokenKey" frontend/lib/` — expect at least
  `auth_service.dart` (getAccessToken :330, logout :110), `api_client.dart`
  (interceptors), `sse_service.dart:~151` (reads the access token from
  SharedPreferences before connecting), and `push_subscription_service_web.dart`.
- **Web caveat**: `flutter_secure_storage`'s web backend is WebCrypto-wrapped
  localStorage — fine, but the app has web-specific files
  (`push_subscription_service_web.dart`, `browser_redirect_web.dart`). Keep the
  abstraction platform-neutral.
- Test harness overrides providers via `ProviderScope`
  (`frontend/test/frontend_flows_test.dart:~995`); SharedPreferences in tests
  uses `SharedPreferences.setMockInitialValues` — check current usage with
  `grep -rn "setMockInitialValues" frontend/test/`.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Add dep | `flutter pub add flutter_secure_storage` | exit 0, pubspec updated |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/pubspec.yaml` (one new dependency)
- New file `frontend/lib/services/token_store.dart` (the abstraction)
- `frontend/lib/services/auth_service.dart`, `frontend/lib/services/api_client.dart`,
  `frontend/lib/services/sse_service.dart`, `frontend/lib/services/push_subscription_service_web.dart`
  (switch token reads/writes to the store)
- Provider wiring file(s) for injecting the store
- Tests under `frontend/test/`

**Out of scope**:
- `userDataKey` profile JSON and all UI-pref keys — they stay in SharedPreferences.
- Android `android/` / iOS `ios/` platform config beyond what
  `flutter_secure_storage`'s README requires (if it requires minSdk or Keychain
  entitlement changes, apply the minimal documented change and note it).
- Token format/refresh logic.

## Git workflow

- Branch: `feat/secure-token-storage` off `new-main-fr`.
- Conventional commits (`feat: ...`, `refactor: ...`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Introduce a TokenStore abstraction

`frontend/lib/services/token_store.dart`:

```dart
abstract class TokenStore {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> save({required String accessToken, required String refreshToken});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore { /* flutter_secure_storage-backed */ }
```

Expose via a Riverpod provider following the style of
`frontend/lib/providers/auth_provider.dart`. Include an in-memory
`FakeTokenStore` for tests (in the test tree, not lib/).

**Verify**: `dart analyze lib/` → exit 0.

### Step 2: One-time migration from SharedPreferences

In the store's first read (or an explicit `migrateFromPrefs(SharedPreferences)`
called during app bootstrap where SharedPreferences is already available): if
secure storage has no refresh token but SharedPreferences does, copy both tokens
into secure storage and `remove()` them from SharedPreferences. Idempotent.
Existing logged-in users must stay logged in across the upgrade.

**Verify**: `dart analyze lib/` → exit 0; migration unit test (Step 4) passes.

### Step 3: Switch every read/write site

Replace direct `_prefs` token access at every site enumerated in Current state
with the injected `TokenStore`. `_clearTokens` keeps clearing the non-token prefs
keys AND calls `tokenStore.clear()`. After the sweep:

**Verify**: `grep -rn "accessTokenKey\|refreshTokenKey" frontend/lib/ | grep -v "token_store\|api_config"` → only the migration code may remain.

### Step 4: Tests

- Migration test: seed mock SharedPreferences with both tokens, run migration
  against `FakeTokenStore`-equivalent backed by a map, assert tokens moved and
  prefs keys removed; run twice, assert idempotent.
- Update any existing tests that seeded tokens via `setMockInitialValues` to
  override the TokenStore provider instead.

**Verify**: `flutter test` → all pass.

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] `flutter_secure_storage` in pubspec; `TokenStore` exists with secure impl
- [ ] Step 3 grep clean (no raw token-key access outside store/migration/config)
- [ ] Migration test proves existing sessions survive
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `flutter_secure_storage` demands platform changes beyond a documented minSdk
  bump / Keychain accessibility setting (e.g. breaking the web build).
- The SSE/interceptor token reads are too hot for async secure-storage reads
  without caching — if you need an in-memory cache layer, that's in scope ONLY
  as a private field of `SecureTokenStore` (invalidated on save/clear); anything
  fancier, stop and report.
- Any test starts failing in auth flows and the cause isn't an un-migrated
  override.

## Maintenance notes

- New token consumers must use `TokenStore` — never SharedPreferences directly.
- Reviewer: check the migration runs before the first authenticated request on
  upgrade (bootstrap ordering), and that logout clears BOTH stores.
- Deferred: removing the one-time migration after a few releases.
