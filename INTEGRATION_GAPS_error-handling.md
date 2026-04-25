# Integration gaps: error handling

Scope: backend error writers in `backend/internal/api/errors.go`, `backend/internal/api/respond.go`, `backend/internal/api/handlers/common.go`, rate limiting in `backend/internal/middleware/ratelimit.go`, and frontend service error handling in `frontend/lib/services`.

## Backend error response inventory

- `api.WriteError(w, err)` writes JSON with status from `HTTPStatusForError`.
  - Shape: `{"error":"<HTTP status text>","message":"<err.Error()>","field":"<optional field>"}`.
  - Possible mapped statuses: `400`, `401`, `403`, `404`, `409`, `500`.
  - In mounted request flow it is used by auth middleware, so the common live case is `401 {"error":"Unauthorized","message":"unauthorized"}` before protected handlers run.

- `api.RespondError(w, err)` maps domain errors to statuses, but only validation uses the mapped error value.
  - Validation shape: `400 {"error":"<validation error string>"}`.
  - Non-validation shape: `<mapped status> {"error":"internal server error"}`.
  - Possible statuses: `400`, `401`, `403`, `404`, `409`, `500`.
  - Note: `ErrValidation` is initially mapped to `422`, then the writer emits `400`, so this helper does not actually produce `422`.

- `handlers.respondError(w, err)` writes the newer flat JSON envelope.
  - Validation: `400 {"error":"validation_error","message":"<message>","field":"<field if present>"}`.
  - Unauthorized: `401 {"error":"unauthorized","message":"unauthorized"}`.
  - Permission denied: `403 {"error":"permission_denied","message":"<message>"}`.
  - Not found: `404 {"error":"not_found","message":"<message>"}`.
  - Conflict: `409 {"error":"conflict","message":"<message>"}`.
  - Fallback: `500 {"error":"internal_error","message":"internal server error"}`.

- Rate limiting uses `http.Error`.
  - Shape/status: `429` with `Content-Type: text/plain; charset=utf-8` and body text containing `{"error":"rate limit exceeded"}` plus a trailing newline.
  - This is not a JSON response to Dio even though the body text looks JSON-like.

- Health/readiness endpoints can produce service-unavailable responses outside the normal service clients.
  - `/internal/health`: `503 {"status":"error","checks":{...}}`.
  - `/readyz`: `503` plain text.

## Frontend behavior by status

- `400` validation errors - **High gap**.
  - `AuthService` and `GroupService` only try to read `data['error']['message']`, expecting a nested error object. All backend writers found here return flat error fields, so real validation messages and `field` are lost and the UI receives `Invalid request`.
  - `ListService`, `RecipeService`, `VaultService`, `LivingService`, `FinanceService`, and `ChoreService` do not handle `400`, so validation failures become `An error occurred`.
  - Minimal fix: add one shared frontend error parser that accepts all current backend shapes: flat `message`, flat string `error`, optional `field`, legacy nested `error.message`, and text bodies that can be JSON-decoded.

- `401` refresh/logout/redirect - **High gap**.
  - All services use `TokenRefreshInterceptor`, so a `401` attempts `POST /auth/token/refresh` and retries once unless the failing request is already the refresh endpoint.
  - Only `AuthService.create(ref)` passes a Riverpod `Ref` into `createApiClient(ref)`. The feature services call `createApiClient()` without `ref`, so refresh failure clears stored tokens but does not set `authStateProvider` to `false`.
  - Router redirect depends on `authStateProvider`; therefore expired sessions from feature-service calls can fail without reliably redirecting to auth UI.
  - Minimal fix: pass `ref` through every service provider into `createApiClient(ref)`, or centralize auth failure notification outside individual services.

- `403` - **Medium gap**.
  - All services map the status to an access-denied style message except the simplified services discard backend `permission_denied.message`.
  - Minimal fix: keep the status-specific fallback but prefer parsed backend `message`.

- `404` - **Medium gap**.
  - All services map the status, but simplified services return generic `Not found` and discard backend resource-specific `not_found.message`.
  - Minimal fix: prefer parsed backend `message`, then fall back to domain-specific strings like `Group not found`.

- `409` - **Medium gap**.
  - `AuthService` and `GroupService` map `409`; the other feature services do not and return `An error occurred`.
  - Backend `api.RespondError` may send status `409` with body `{"error":"internal server error"}`, so frontend should rely on status first but use parsed message when available.
  - Minimal fix: add shared `409` handling in the common parser and use it from every service.

- `422` - **Low gap / mostly unused by current backend helpers**.
  - `AuthService` and `GroupService` map `422` to `Validation error`; other services do not.
  - The inspected backend helpers do not currently emit `422` for validation: both `api.WriteError` and `handlers.respondError` map validation to `400`, and `api.RespondError` overrides its `422` mapping with a `400` response.
  - Minimal fix: treat `422` like `400` in the shared frontend parser for future compatibility, but do not prioritize backend changes unless an endpoint starts returning real `422`.

- `429` rate limit - **High gap**.
  - `AuthService` and `GroupService` map `429` to a useful generic message.
  - Most feature services do not handle `429`, so rate limits become `An error occurred`.
  - Rate limit responses are `text/plain`, so body parsing must tolerate strings and optionally JSON-decode the string body.
  - Minimal fix: shared status handling for `429`, plus optional parsing of text bodies and `Retry-After` if added later.

- `500` - **Medium gap**.
  - `AuthService` and `GroupService` map `500` to a server-error message.
  - Most feature services return `An error occurred`.
  - Backend intentionally hides internal details, so frontend should keep a generic fallback but make it consistent.

- `503` - **Medium gap**.
  - `AuthService` and `GroupService` map `503`.
  - Most feature services return `An error occurred`.
  - Health/readiness 503 shapes are not consumed by the current service layer, but any future service check should tolerate both JSON and plain text.

## Recommended minimal frontend fixes

1. Introduce a small shared `ApiException`/error parser in `frontend/lib/services` and use it from all services instead of per-service private mappers.
2. Parse current backend variants in this order: flat `message`, nested `error.message`, flat string `error`, decoded string body, then status fallback.
3. Preserve `statusCode`, `error` code, `field`, and display message so forms can show field-level validation later.
4. Pass `Ref` into every service-created Dio client, or provide an auth-failure callback, so failed refresh reliably flips `authStateProvider` and triggers router redirect.
5. Add uniform fallbacks for `400`, `401`, `403`, `404`, `409`, `422`, `429`, `500`, `503`, timeout, and connection errors.

Backend fixes are optional but would reduce client complexity: standardize `api.RespondError` onto the `handlers.respondError` flat envelope, and replace rate-limit `http.Error` with JSON plus `Content-Type: application/json`.
