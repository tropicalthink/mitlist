## Live integration results (manual/observed)

Environment:
- Backend: `docker compose up` in `backend/` with `mitlist-app` published on `http://localhost:8000`
- Frontend: `flutter run` in `frontend/`

### Auth + error envelope (unauthorized)
- **GET** `/api/v1/auth/me` (no token)
  - **Observed**: `401` with JSON body `{"error":"Unauthorized","message":"unauthorized"}`
  - **Notes**: Confirms consistent JSON error envelope for unauthenticated access.

### Guest → protected route access
- **POST** `/api/v1/auth/guest`
  - **Observed**: `201` and response includes `access_token`
- **GET** `/api/v1/groups` with `Authorization: Bearer <token>`
  - **Observed**: `200` (response body observed as `null` in one run; frontend tolerates non-list by treating as empty)
  - **Risk**: returning `null` instead of `[]` is contract-odd; consider normalizing to `[]` for list endpoints.

### Vault end-to-end (previously unreachable)
After backend rebuild/restart, Vault routes are callable and functional:
- **POST** `/api/v1/groups` with guest token
  - **Observed**: `201` with group `id`
- **POST** `/api/v1/vault` with guest token
  - Body: `{group_id,type,title,content}` (no `reminder_date`)
  - **Observed**: `201` with created vault item JSON
- **GET** `/api/v1/vault?group_id=<id>&limit=50&offset=0` with guest token
  - **Observed**: `200` with JSON array containing the created item

### Notifications + VAPID (mounted)
- **GET** `/api/v1/vapid`
  - **Observed**: `200` with JSON body `{ "public_key": "<...>" }` (may be empty if not configured).
- **GET** `/api/v1/notifications/preferences` (with auth)
  - **Observed**: `200` with JSON array of preferences (used by Flutter AccountScreen toggle).

### Push subscriptions (mounted)
- **POST** `/api/v1/auth/push-subscriptions` (with auth)
  - **Expected**: `201` with created subscription JSON `{id,user_id,endpoint,p256dh,auth,created_at}`.
- **GET** `/api/v1/auth/push-subscriptions` (with auth)
  - **Expected**: `200` with JSON array.
- **DELETE** `/api/v1/auth/push-subscriptions/{id}` (with auth)
  - **Expected**: `204`.

### Integration Tools coverage (Flutter)
In debug builds, `IntegrationTestScreen` now includes runnable smoke flows for:
- templates + notifications
- group admin (pending claims + invite attempt)
- finance (expenses + recurring-expenses)
- recipes + collections
- living care (schedule + logs)
- assistant sessions/messages
- activity logs

### Frontend UI
Flutter static checks passed (`flutter analyze`, `flutter test`). Full interactive UI walkthrough was not automated; the live backend verification above demonstrates the key auth + vault path wiring and confirms endpoints are reachable.

