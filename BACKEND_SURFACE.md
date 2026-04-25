## Backend surface inventory (Go)

Base prefix is `cfg.APIPrefix + "/v1"`; default `API_PREFIX=/api`, so base is **`/api/v1`**.

Auth:
- Protected routes are under `middleware.Auth(cnt.JWT(), cnt.UserService())`.
- Token is accepted from cookie `access_token` **or** header `Authorization: Bearer <token>` (`backend/internal/middleware/auth.go`).

Global middleware behaviors relevant to clients:
- CORS is configured in `middleware.CorsMiddleware(cfg.FrontendURL, cfg.Environment)` (credentials enabled; OPTIONS returns 204).
- Rate limiting is applied via `middleware.RateLimit(...)`.

### Error envelopes (IMPORTANT)
There are multiple error helpers used across handlers:
- `handlers.respondError(...)` (from `backend/internal/api/handlers/common.go`) returns:
  - `{"error":"validation_error|not_found|permission_denied|conflict|unauthorized|internal_error","message":"...","field":"..."}` with status mapped to the error type.
- `api.WriteError(...)` (used by auth middleware) returns:
  - `{"error":"<HTTP Status Text>","message":"<err.Error()>","field":"<optional>"}` with mapped status.
- `api.RespondError(...)` (used by several handlers) returns:
  - for validation: `400 {"error":"<actual error string>"}`
  - otherwise: `{ "error": "internal server error" }` **even when status is 401/403/404/etc**

### Router-mounted endpoints (from `backend/cmd/api/main.go`)

#### Health
- **GET** `/healthz` -> `200` plain text `ok`
- **GET** `/readyz` -> `200` empty; `503` plain text
- **GET** `/internal/health` -> `200|503 {"status":"ok|error","checks":{"db":"...","redis":"..."}}`

#### Auth (public + protected under `/api/v1/auth`)
Public:
- **POST** `/auth/register`
  - Body: `{email,password,first_name,last_name}`
  - `201` `{user?,access_token,refresh_token}` (user is present)
- **POST** `/auth/login`
  - Body: `{email,password}`
  - `200` `{user,access_token,refresh_token}`
- **POST** `/auth/token/refresh`
  - Body: `{refresh_token}`
  - `200` `{access_token,refresh_token}` (no user)
- **POST** `/auth/logout`
  - Body: `{refresh_token}`
  - `204` (always)
- **POST** `/auth/password-reset`
  - Body: `{email}`
  - `202 {"message":"if the email exists, a reset link has been sent"}`
- **POST** `/auth/password-reset/confirm`
  - Body: `{token,new_password}`
  - `200 {"message":"password reset successful"}`
- **POST** `/auth/guest`
  - `201` `{user,access_token,refresh_token}`

Protected:
- **GET** `/auth/me` -> `200 User`
- **PATCH** `/auth/me` body optional `{first_name?,last_name?,avatar_url?}` -> `200 User`
- **DELETE** `/auth/me` -> `204`
- **POST** `/auth/change-password` body `{old_password,new_password}` -> `200 {"message":"password changed"}`
- **POST** `/auth/guest/convert` body `{email,password,first_name,last_name}` -> `200 {user,access_token,refresh_token}`
- **POST** `/auth/claim-account` body `{password,first_name,last_name}` -> `200 {user?,access_token,refresh_token}`

User schema (from `internal/models`, returned by auth endpoints):
- `User` => `{id,email,first_name,last_name,is_active,is_verified,is_guest,avatar_url?,created_at,updated_at}`

#### Protected feature routes (mounted under `/api/v1` + `middleware.Auth`)

Groups:
- `POST /groups`
- `GET /groups?limit&offset`
- `GET /groups/{id}`
- `PATCH /groups/{id}`
- `DELETE /groups/{id}`
- `POST /groups/{id}/members` body `{role}`
- `POST /groups/join` body `{code}`
- `DELETE /groups/{id}/members/{user_id}`
- `PATCH /groups/{id}/members/{user_id}` body `{role}`
- `GET /groups/{id}/pending-claims`
- `POST /groups/{id}/pending-claims/{claim_id}/approve`
- `POST /groups/{id}/pending-claims/{claim_id}/reject`

Lists:
- `POST /lists` body `{group_id,name,type}`
- `GET /lists?group_id&limit&offset`
- `GET /lists/{id}`
- `PATCH /lists/{id}` body `{name,type}`
- `DELETE /lists/{id}`
- `POST /lists/{id}/items` body `{name,quantity,unit}`
- `GET /lists/{id}/items?limit&offset`
- `PATCH /lists/{id}/items/{item_id}` body partial `{name?,quantity?,unit?,checked?,position?}`
- `DELETE /lists/{id}/items/{item_id}`
- `POST /lists/{id}/reorder` body `{item_ids:[uuid]}`

Templates:
- `POST /templates` body `{group_id,name}`
- `GET /templates?group_id&limit&offset`
- `GET /templates/{id}`
- `PATCH /templates/{id}` body `{name}`
- `DELETE /templates/{id}`
- `POST /templates/{id}/apply` body `{list_name}`
- `POST /chore-templates` body `{group_id,name,rotation_type,frequency}`
- `GET /chore-templates?group_id&limit&offset`
- `GET /chore-templates/{id}`
- `PATCH /chore-templates/{id}` body `{name,rotation_type,frequency}`
- `DELETE /chore-templates/{id}`

Chores:
- `POST /chores` body `{group_id,name,description?,rotation_type,frequency,is_active}`
- `GET /chores?group_id&limit&offset`
- `GET /chores/{id}`
- `PATCH /chores/{id}` body `{name,description?,rotation_type,frequency,is_active}`
- `DELETE /chores/{id}`
- `POST /chores/{id}/rotate`
- `POST /chores/{id}/complete` body `{notes?}`
- `POST /chores/{id}/skip`
- `GET /chores/{id}/assignments?limit&offset`

Finance:
- `POST /expenses` body `{group_id,payer_id,amount(int64),description,category,currency,date(time),split_user_ids:[uuid]}`
- `GET /expenses?group_id&limit&offset`
- `GET /expenses/{id}`
- `PATCH /expenses/{id}` body partial `{payer_id?,amount?,description?,category?,currency?,date?}`
- `DELETE /expenses/{id}`
- `POST /expenses/{id}/splits` body `{user_id,amount}`
- `PATCH /expenses/{id}/splits/{split_id}` body `{user_id?,amount?,is_settled?}`
- `DELETE /expenses/{id}/splits/{split_id}`
- `POST /expenses/{id}/settle` body `{from_user_id,to_user_id,amount}`
- `DELETE /expenses/{id}/settle/{settlement_id}`
- `POST /recurring-expenses` body `{group_id,payer_id,amount,description,category,frequency,next_due,is_active}`
- `GET /recurring-expenses?group_id&limit&offset`
- `GET /recurring-expenses/{id}`
- `PATCH /recurring-expenses/{id}` body partial `{payer_id?,amount?,description?,category?,frequency?,next_due?,is_active?}`
- `DELETE /recurring-expenses/{id}`

Recipes & Collections:
- `POST /recipes` body `{title,description,prep_time,cook_time,servings,image_url,is_public}`
- `GET /recipes?limit&offset`
- `GET /recipes/{id}`
- `PATCH /recipes/{id}` body partial `{title?,description?,prep_time?,cook_time?,servings?,image_url?,is_public?}`
- `DELETE /recipes/{id}`
- `POST /recipes/{id}/share` body `{shared_with_user_id,permission}`
- `POST /collections` body `{name}`
- `GET /collections?limit&offset`
- `GET /collections/{id}`
- `PATCH /collections/{id}` body `{name?}`
- `DELETE /collections/{id}`
- `POST /collections/{id}/recipes` body `{recipe_id}`
- `DELETE /collections/{id}/recipes/{recipe_id}`

Living things:
- `POST /living-things` body `{group_id(string uuid),name,species,location?,image_url?}`
- `GET /living-things?group_id&limit&offset`
- `GET /living-things/{id}`
- `PATCH /living-things/{id}` body partial `{name?,species?,location?,image_url?}`
- `DELETE /living-things/{id}`
- `POST /living-things/{id}/care-schedule` body `{frequency_value,frequency_unit,next_due}`
- `GET /living-things/{id}/care-schedule`
- `PATCH /living-things/{id}/care-schedule` body partial `{frequency_value?,frequency_unit?,next_due?}`
- `POST /living-things/{id}/care-logs` body `{notes?}`
- `GET /living-things/{id}/care-logs?limit&offset`

Assistant:
- `POST /assistant/sessions` body `{title}` (empty becomes `"New Chat"`)
- `GET /assistant/sessions?limit&offset`
- `GET /assistant/sessions/{id}`
- `PATCH /assistant/sessions/{id}` body `{title}`
- `DELETE /assistant/sessions/{id}`
- `POST /assistant/sessions/{id}/messages` body `{content}`
- `GET /assistant/sessions/{id}/messages?limit&offset`

Share target:
- `POST /share-target/lists` body `{group_id(string uuid),text}` -> `201 {list:any,items:[any]}`
- `POST /share-target/recipes` body `{text}` -> `201 Recipe`

### Handler files present but not mounted by `cmd/api/main.go`
The following handlers exist under `backend/internal/api/handlers/` but do not appear mounted in `cmd/api/main.go`:
- `vault.go`, `notification.go`, `activity.go`, `oauth.go`, `metrics.go`, `vapid.go`, `debug.go`, `pprof.go`

