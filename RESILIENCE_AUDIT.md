# Resilience Audit

## CRITICAL

### RES-1: No offline support in Flutter
**File**: All Flutter screens
**Description**: The Flutter app has no offline-first strategy. No connectivity listener, no cached data, no offline fallback. All screens make HTTP requests and fail with error messages when offline. No data is available without a network connection.
**Fix**: Implement connectivity monitoring, cache last-known-good data locally, and show cached data when offline with a "offline" banner.

### RES-2: List detail screen uses mock data
**File**: `frontend/lib/screens/lists/list_detail_screen.dart`
**Description**: The list detail screen (viewing and managing items within a list) uses mock/simulated data instead of connecting to the real API. This feature is non-functional in production.
**Fix**: Wire the list detail screen to the `ListService` API calls.

## HIGH

### RES-3: Token refresh not tested under failure conditions
**File**: `frontend/lib/services/api_client.dart`
**Description**: The `TokenRefreshInterceptor` handles 401 with a single retry. But under rapid concurrent failures, the `_refreshInFlight` dedup could race. No tests verify the behavior when:
- Refresh token is expired -> should navigate to login
- Refresh endpoint returns 5xx -> should allow retry
- Network drops during refresh -> should show network error
- Multiple rapid 401s -> should only refresh once

### RES-4: No retry with backoff on network failures
**File**: All Flutter services
**Description**: When a request fails due to network error, there's no automatic retry with exponential backoff. The user must manually retry. For transient failures, this creates a poor experience.

### RES-5: Backend connection pool may exhaust under load
**File**: `internal/db/db.go`
**Description**: Connection pool max is 20. Under high concurrency (e.g., 100+ concurrent requests), queries will queue up waiting for a connection. With the 10s `statement_timeout`, this could lead to cascading failures.

### RES-6: No request timeouts on external API calls
**File**: `internal/services/ai/ai.go`
**Description**: The Gemini AI client has no request timeout. If the upstream API hangs, the handler will hang until the server-level 30s read timeout.

## MEDIUM

### RES-7: Graceful shutdown may not drain active requests
**File**: `internal/server/server.go`
**Description**: The server has a 30-second shutdown timeout. Long-running requests (e.g., file uploads, AI calls) may be aborted. The shutdown logs a warning but does not track in-flight requests.

### RES-8: No health check for AI/email/3rd-party services
**File**: `internal/api/handlers/health.go`
**Description**: The `/readyz` endpoint checks DB and Redis but not Gemini API, email services, or S3. A failure in any of these upstream services would not be detected by the health check.

### RES-9: Database connection retry may mask configuration errors
**File**: `internal/db/db.go`
**Description**: Retry with 5 attempts and exponential backoff means startup takes up to 30 seconds before failing. A misconfigured DATABASE_URL delays failure detection.

### RES-10: No connection timeout in Flutter HTTP timeouts
**File**: `frontend/lib/services/api_client.dart`
**Description**: Timeout is 30 seconds for connect/receive/send. On very slow networks, users wait 30 seconds for every request before seeing an error.
