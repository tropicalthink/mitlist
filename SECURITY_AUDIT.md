# Security Audit

## CRITICAL

### AUTH-1: No access token revocation on logout
**File**: `internal/api/handlers/auth.go:220-233`
**Description**: `Logout` handler only revokes the refresh token. The access token continues working until it expires (up to 60 minutes). A user cannot force-logout all sessions, and a stolen access token remains valid.
**Fix**: Also add the access token JTI to the revocation list. The Flutter frontend should also clear local tokens immediately on logout.

### AUTH-2: Login endpoint not per-IP rate limited enough for brute force
**File**: `internal/middleware/ratelimit.go:111-116`
**Description**: `shouldSkip` exempts `/api/v1/auth/token*` from rate limiting. The general per-IP rate limiter (100 req/min) applies but is too generous for brute-force prevention. Login and register should have stricter limits (e.g., 5 req/min per IP).
**Fix**: Add dedicated rate limit tiers for auth endpoints (login, register, password-reset).

### AUTH-3: No brute force protection on login
**File**: `internal/api/handlers/auth.go:176-192`, `internal/services/user_service.go:94-117`
**Description**: Login has no account lockout, progressive delay, or CAPTCHA. With 100 req/min per IP, an attacker can try ~1700 passwords before the rate limiter engages.
**Fix**: Implement progressive delay or account lockout after N failed attempts. Add per-account rate limiting.

### FINANCE-1: PayerID can be set to any group member
**File**: `internal/api/handlers/finance.go:40-76`
**Description**: `CreateExpense` allows the caller to set `PayerID` to any UUID. A malicious group member can create expenses and claim another member paid, creating fake financial obligations.
**Fix**: Validate that `PayerID` equals the authenticated user, or require admin role to set a different payer.

### FINANCE-2: Split IsSettled can be modified by any member
**File**: `internal/api/handlers/finance.go:244-288`
**Description**: `UpdateSplit` allows setting `is_settled` via the request body. Any group member can mark any split as settled, bypassing the settlement flow.
**Fix**: Remove `is_settled` from updatable fields on `UpdateSplit`. Only allow settlement via the dedicated `CreateSettlement` endpoint.

### INFRA-1: Hardcoded dev secrets in docker-compose.yml
**File**: `docker-compose.yml:24-25`
**Description**: `SECRET_KEY` and `SESSION_SECRET_KEY` are hardcoded in docker-compose.yml. If this config is used in production, JWT keys are compromised.
**Fix**: Remove hardcoded secrets from docker-compose.yml. Require them via .env file. Add a warning message if defaults are used in production.

### AUTH-4: No CSRF protection for cookie-based auth
**File**: `internal/middleware/auth.go:50-58`
**Description**: The `extractToken` function checks cookies before the Authorization header. Cookie-based auth without CSRF tokens allows cross-site request forgery if a user visits a malicious site while logged in.
**Fix**: For cookie auth, implement CSRF token validation (double-submit cookie pattern or SameSite=Strict). For modern apps, prefer Authorization header-only auth.

## HIGH

### IDOR-1: Unauthenticated access check coverage
**File**: Internal middleware and all handler files
**Description**: All protected routes are properly behind `middleware.Auth()`. Confirmed no unprotected routes expose user data. Verified through route audit.

### IDOR-2: Group membership enforcement
**File**: All services
**Description**: All group-scoped services (List, Chore, Finance, Vault, Living) correctly check `requireMembership` or `requireAdmin` before returning data. IDOR is properly prevented.

### SEC-CONFIG-1: Rate limiter bypassed when Redis is down
**File**: `internal/middleware/ratelimit.go:73-76`
**Description**: When Redis is unavailable, rate limiting is silently bypassed (logged as warning). An attacker who can DoS Redis can then bypass rate limits entirely.
**Fix**: Consider a local in-memory fallback rate limiter, or fail closed instead of open.

### SEC-OBS-1: Account enumeration via timing
**File**: `internal/services/user_service.go:94-117`
**Description**: Login returns "invalid email or password" for both cases. Password reset returns the same message regardless of email existence. Account enumeration via timing differences is theoretically possible but practically mitigated by bcrypt (constant-time comparison on password hash).

## MEDIUM

### SEC-OBS-2: Password reset token in plaintext
**File**: `internal/services/user_service.go:241`
**Description**: Password reset token is a hex string sent via email in plaintext. If email is intercepted, anyone can reset the password.
**Mitigation**: Acceptable for current scope. Tokens expire after 24 hours and are single-use.

### SEC-OBS-3: Push notification service is a stub
**File**: `internal/services/push/push.go`
**Description**: Logs messages but does not actually send push notifications. If used in production, users will not receive notifications.

### SEC-OBS-4: No rate limiting on password reset
**Description**: Password reset endpoint has no per-email rate limiting. An attacker could spam password reset emails to a victim's inbox.

### SEC-OBS-5: Missing CGO for race detection
**Description**: `go test -race` fails because CGO_ENABLED=1 is not set. Race conditions in production code cannot be detected in CI.
**Fix**: Document or set `CGO_ENABLED=1` in the build environment.
