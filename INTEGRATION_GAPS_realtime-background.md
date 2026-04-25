# Integration gaps: realtime and background delivery

Scope: backend websocket/SSE/polling endpoints, frontend usage of those endpoints, and push notification/VAPID endpoint usage.

Severity scale:
- **High**: shipped realtime/background notification behavior cannot work end-to-end.
- **Medium**: endpoint or UI exists but is disconnected, incomplete, or only manually refreshed.
- **Low**: supporting gap or ambiguity that may become important once the primary gaps are fixed.

## Summary

The repo does not currently expose a websocket, SSE, or long-polling realtime API from the backend, and the Flutter app does not contain a realtime client. The only "polling-like" frontend behavior found is initial screen loads and user-driven `RefreshIndicator` refreshes.

Push notification support is also not wired end-to-end. The backend has notification, VAPID, push subscription, and scheduled job code, but notification and VAPID handlers are not mounted in `backend/cmd/api/main.go`; there are no mounted push subscription endpoints; the push service only logs; and the Flutter app has no notification service, VAPID call, web push subscription flow, or backend notification API usage.

## Findings

### High: No backend websocket/SSE/long-polling endpoint exists

Evidence:
- `backend/cmd/api/main.go` mounts REST routes under `/api/v1`, plus health routes, but no websocket, SSE, event stream, or long-poll route.
- `backend/internal/server/server.go` configures a standard chi HTTP server and middleware stack, with no upgrade or streaming-specific route setup.
- Code search in `backend/**/*.go` found notification and push code but no websocket/SSE/event-source implementation.

Impact:
- The frontend has no backend endpoint it could subscribe to for live list, chore, expense, household, or notification updates.
- Any "realtime" product expectation currently falls back to manual reloads or normal request/response REST calls.

### High: Frontend has no websocket/SSE/polling integration

Evidence:
- `frontend/lib/services/api_client.dart` creates a Dio REST client only.
- `frontend/lib/services/*.dart` calls ordinary REST endpoints such as `/groups`, `/lists`, `/chores`, `/expenses`, `/recipes`, `/living-things`, and `/vault`; no service calls `/notifications`, `/vapid`, websocket URLs, SSE endpoints, or polling-specific endpoints.
- `frontend/pubspec.yaml` does not declare direct realtime or notification dependencies such as `web_socket_channel`, `firebase_messaging`, local notification plugins, background fetch, or workmanager.
- `frontend/lib/screens/**` contains `RefreshIndicator` and initial `_load...()` calls, but no periodic network polling. The one `Timer.periodic` match is in `frontend/lib/screens/auth/welcome_screen.dart` for a welcome-screen carousel, not data refresh.

Impact:
- The Flutter app cannot receive realtime events or background updates from the backend.
- User-visible data freshness depends on screen entry, manual pull-to-refresh, or explicit button retry flows.

### High: Notification endpoints exist in code but are not mounted

Evidence:
- `backend/internal/api/handlers/notification.go` defines routes for:
  - `GET /notifications`
  - `GET /notifications/{id}`
  - `PATCH /notifications/{id}/read`
  - `PATCH /notifications/read-all`
  - `DELETE /notifications/{id}`
  - `GET /notifications/preferences`
  - `PATCH /notifications/preferences`
- `backend/cmd/api/main.go` does not instantiate `NewNotificationHandler`, does not call `RegisterRoutes`, and does not mount `/notifications`.
- Existing inventory already flags notifications as unmounted in `INTEGRATION_MAP.md` and `BACKEND_SURFACE.md`.

Impact:
- Even if the frontend added notification API calls, `/api/v1/notifications*` would return 404 in the production router.
- Notification preferences cannot be retrieved or changed through the mounted API.

### High: VAPID public-key endpoint exists but is not mounted or consumed

Evidence:
- `backend/internal/api/handlers/vapid.go` defines a handler that returns `{"public_key": <VAPID_PUBLIC_KEY>}`.
- `backend/internal/api/handlers/misc_test.go` tests the handler directly at `/api/v1/vapid`, but direct handler tests do not prove router mounting.
- `backend/cmd/api/main.go` does not instantiate `NewVAPIDHandler` or mount `/vapid`.
- `frontend/lib/services` and `frontend/lib/screens` contain no `/vapid` call.

Impact:
- A web-push capable client cannot fetch the VAPID public key from the mounted API.
- Browser/web push subscription setup cannot be completed from the current Flutter client.

### High: Push subscription storage exists, but there is no API or frontend flow to register subscriptions

Evidence:
- `backend/internal/models/auth.go` defines `PushSubscription`.
- `backend/internal/repositories/auth_repo.go` implements create/list/delete operations for `push_subscriptions`.
- `backend/migrations/000001_init_schema.up.sql` creates the `push_subscriptions` table.
- No backend handler route was found for creating, listing, or deleting push subscriptions.
- The Flutter app has no subscription model/service, no service worker or platform notification registration flow, and no dependency that would register device/browser push tokens.

Impact:
- The backend has nowhere to receive a user's push endpoint/key material.
- Scheduled jobs and notification code cannot target real client devices even if VAPID and notification routes are mounted later.

### High: Backend push delivery is a stub

Evidence:
- `backend/internal/services/push/push.go` implements `SendToUser` and `BroadcastToGroup` by logging `"push notification sent"` / `"push broadcast sent"` and returning `nil`.
- `backend/go.mod` includes `github.com/SherClockHolmes/webpush-go`, and VAPID config exists in `backend/internal/config/config.go`, but the push service does not use them.
- `backend/internal/jobs/runner.go` wires scheduled jobs to `cnt.Push()`, so jobs call the stub service.

Impact:
- Chore, living thing, vault, recurring expense, weekly summary, and notification-triggered push paths do not deliver external notifications.
- Success is currently indistinguishable from "logged only" behavior because `SendToUser` always returns `nil`.

### Medium: Notification preferences UI is local-only

Evidence:
- `frontend/lib/screens/you/account_screen.dart` has `_notificationsEnabled` and a "Notifications" switch.
- The switch only calls `setState`; it does not call `/notifications/preferences` or persist locally.
- The backend preference endpoint is unmounted, and its update handler expects a `NotificationPreference` object including an existing preference ID.

Impact:
- Toggling notifications in the app does not affect backend notification preferences.
- Users may believe notifications are enabled/disabled while backend behavior is unchanged.

### Medium: Backend notifications are database-backed but disconnected from Flutter

Evidence:
- `backend/internal/repositories/notification_repo.go` persists notifications and preferences.
- `backend/internal/services/notification_service.go` creates notifications and conditionally calls push when a matching `channel == "push"` preference exists.
- Flutter has no notification model, provider, service, inbox screen, badge flow, or calls to `/notifications`.

Impact:
- In-app notification history/read state is unavailable to users.
- Notification records, if created by backend code, cannot be surfaced or acknowledged by the Flutter client.

### Low: Existing manual refresh is not background polling

Evidence:
- Several screens use `RefreshIndicator` and `_load...()` calls on screen entry or user action.
- No `Timer.periodic`, `Stream.periodic`, isolate, background task, or app lifecycle refresh loop was found for API data.

Impact:
- This is acceptable for manual refresh semantics, but it should not be counted as realtime or background sync coverage.

## Endpoint status matrix

| Capability | Backend status | Frontend status | Severity |
| --- | --- | --- | --- |
| Websocket realtime | No endpoint found | No client found | High |
| SSE realtime | No endpoint found | No client found | High |
| Long-polling/poll endpoint | No dedicated endpoint found | No automatic network polling found | High |
| Notifications REST | Handler exists, not mounted | No usage found | High |
| Notification preferences | Handler exists, not mounted | Local-only switch | Medium |
| VAPID public key | Handler exists, not mounted | No usage found | High |
| Push subscription registration | Repo/table exist, no handler route found | No subscription flow found | High |
| Push delivery | Stub logs only | No receiving/registering flow found | High |

## Evidence references

- `backend/cmd/api/main.go` mounts auth and protected feature REST routes, but not notification, VAPID, push subscription, websocket, SSE, or polling routes.
- `backend/internal/api/handlers/notification.go` defines notification REST routes that are not mounted by the production router.
- `backend/internal/api/handlers/vapid.go` defines a VAPID public key handler that is not mounted by the production router.
- `backend/internal/services/push/push.go` logs push sends instead of using web push delivery.
- `backend/internal/repositories/auth_repo.go` has push subscription persistence methods with no corresponding handler route.
- `frontend/lib/services/api_client.dart` configures Dio REST access only.
- `frontend/lib/services/*.dart` contains no notification, VAPID, websocket, SSE, or push subscription API calls.
- `frontend/lib/screens/you/account_screen.dart` contains a local notifications switch with no backend call.
- `frontend/pubspec.yaml` has no direct realtime, push messaging, local notification, or background task dependency.
