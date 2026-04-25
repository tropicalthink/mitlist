# Auth Integration Gaps

Scope: backend auth middleware/JWT service and Flutter Dio interceptors/auth storage.

## Summary

Header naming and token prefix are aligned: the backend accepts `Authorization: Bearer <access_token>` and the Flutter client sends exactly that. Refresh endpoint naming and payload shape are also aligned: `POST /auth/token/refresh` with `{"refresh_token": "..."}` returns `access_token` and `refresh_token`.

The meaningful gaps are around refresh coordination, session state propagation, logout revocation depth, and role/permission visibility.

## Findings

### HIGH: Concurrent 401s can invalidate a newly refreshed session

Backend refresh rotates refresh tokens. `Refresh` validates the submitted refresh token, revokes its JTI, then issues a new access/refresh pair. The frontend refresh interceptor has no single-flight/lock around refresh attempts. If multiple expired-token requests fail with `401` at the same time, each request reads the same stored refresh token and posts it to `/auth/token/refresh`.

Expected race:

1. Request A refreshes successfully and stores the new refresh token.
2. Request B refreshes with the old refresh token.
3. Backend rejects B because A already revoked that token.
4. Frontend B handles refresh failure by removing `access_token`, `refresh_token`, and `user_data`.

That can log the user out even though the first refresh succeeded.

Evidence:

- Backend rotates on refresh in `backend/internal/api/handlers/auth.go` by calling `ValidateRefreshToken`, `RevokeRefreshToken`, then `GenerateTokenPair`.
- Refresh token revocation is persisted in Redis by JTI in `backend/internal/services/jwt/jwt.go`.
- Frontend refresh logic in `frontend/lib/services/api_client.dart` performs refresh per failing request and has only a per-request `_retryKey`, not a shared refresh-in-progress guard.

Recommended fix: add a shared refresh coordinator/mutex in the Dio layer so all pending `401` retries await the same refresh operation, then retry with the same new access token. Only clear auth state if the coordinated refresh fails.

### HIGH: Many API clients clear tokens on 401 without updating router auth state

`TokenRefreshInterceptor` only updates `authStateProvider` when it was constructed with a `Ref`. `AuthService.create(ref)` passes the ref, but the feature services create clients with `createApiClient()` and no `Ref`. For those services, refresh failure clears tokens from `SharedPreferences` but does not set `authStateProvider` to `false`, so `GoRouter` may keep the user on protected screens until a later rebuild or manual navigation.

Evidence:

- `frontend/lib/services/api_client.dart` uses `_ref?.read(authStateProvider.notifier).state = false`.
- `frontend/lib/services/group_service.dart`, `list_service.dart`, `chore_service.dart`, `finance_service.dart`, `living_service.dart`, `vault_service.dart`, and `recipe_service.dart` call `createApiClient()` without passing a `Ref`.
- `frontend/lib/router.dart` redirects protected routes based only on `authStateProvider`.

Recommended fix: centralize API client creation behind providers that always inject `Ref`, or move auth/session invalidation into a globally observable auth controller that does not depend on optional interceptor state.

### MEDIUM: Failed refresh does not actively redirect; it only mutates state when wired

On refresh failure, the interceptor clears storage and optionally sets `authStateProvider` to `false`, then forwards the original Dio error. There is no direct navigation action, and clients without `Ref` do not update the router state at all. This makes `401` handling inconsistent: some requests can redirect through router refresh, while others only surface an error message or stale screen state.

Evidence:

- `frontend/lib/services/api_client.dart` forwards the original error with `handler.next(err)` after `_onRefreshFailure`.
- `frontend/lib/router.dart` redirects to `/welcome` only when `authStateProvider` is false.
- `frontend/lib/screens/you/account_screen.dart` manually navigates on explicit logout, but refresh failure paths do not.

Recommended fix: make session expiration a single app-level event. The router should reliably observe it and redirect to the auth route from every API client path.

### MEDIUM: Logout only revokes the refresh token, not the active access token

The backend JWT service checks for revoked access-token JTIs, but logout only validates and revokes the submitted refresh token. The frontend clears local storage, which is correct for the current device, but an already issued access token remains usable until its expiry if it is copied or intercepted.

Evidence:

- `backend/internal/services/jwt/jwt.go` checks access-token revocation in `ValidateAccessToken`.
- `backend/internal/api/handlers/auth.go` `Logout` only calls `RevokeRefreshToken`.
- `frontend/lib/services/auth_service.dart` clears local tokens after logout regardless of API result.

Recommended fix: decide whether logout is intended to be local-only or server-side session invalidation. If server-side invalidation is expected, require the access token on logout and revoke its JTI, or keep access TTL short and document logout as refresh-token revocation only.

### MEDIUM: Backend enforces group/admin permissions that the frontend model does not know

The backend enforces group membership and admin-only operations in services, but the frontend `Group` model does not include the current user's membership role. As a result, the frontend cannot reliably hide or explain admin-only actions before receiving `403`.

Backend admin-only examples include:

- Updating/deleting groups.
- Inviting members.
- Removing members and changing member roles.
- Viewing/approving/rejecting pending claims.
- Finance delete operations such as deleting expenses, splits, settlements, and recurring expenses.

Evidence:

- `backend/internal/services/group_service.go` uses `requireAdmin` for update/delete/invite/member-management/claim routes.
- `backend/internal/services/finance_service.go` uses `requireAdmin` for selected destructive finance operations.
- `frontend/lib/models/group_models.dart` has `id`, `name`, `description`, `isPersonal`, `memberCount`, and timestamps, but no current-user role.
- `frontend/lib/models/auth_models.dart` user/token models do not expose roles/scopes/permissions.

Recommended fix: return current-user membership role/capabilities with group or membership responses, and teach frontend feature screens to gate admin-only actions or show precise permission errors.

### LOW: JWT roles exist but are not populated or consumed

The JWT claims include `roles`, and refresh metadata stores those roles, but auth token generation passes `nil` roles for register, refresh, claim-account, and the auth handler paths. Middleware only validates identity and loads the user; it does not enforce token roles/scopes.

This is not currently a header mismatch, but it is an integration contract ambiguity: clients should not assume JWT roles/scopes exist or are authoritative.

Evidence:

- `backend/internal/services/jwt/jwt.go` defines `Claims.Roles`.
- `backend/internal/api/handlers/auth.go` calls `GenerateTokenPair(..., nil)` in auth flows.
- `backend/internal/middleware/auth.go` only injects user ID/user into context after token validation.

Recommended fix: either remove/document JWT roles as unused, or define a stable role/scope contract and expose it through both backend authorization checks and frontend models.

### LOW: Header/prefix contract is aligned

No mismatch found for access-token transport.

Evidence:

- Backend auth middleware accepts cookie `access_token` or header `Authorization` with exact prefix `Bearer `.
- Flutter config defines `authorizationHeader = 'Authorization'` and `authorizationPrefix = 'Bearer '`.
- Flutter `AuthInterceptor` writes `Authorization: Bearer <token>` when `access_token` exists.

## Notes

- Refresh endpoint exclusion is correct: the frontend does not recursively refresh when `/auth/token/refresh` itself returns `401`.
- Retry is limited per request by `_retryKey`, which prevents infinite retry loops for a single request, but does not solve concurrent refresh races.
- Logout endpoint shape is aligned: frontend sends `{"refresh_token": "..."}` when present, backend returns `204` even for invalid refresh tokens.
