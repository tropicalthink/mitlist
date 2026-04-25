# Integration Gaps: Schema Mismatches

Sources compared:
- `BACKEND_SURFACE.md`, `FRONTEND_CONSUMPTION.md`, `INTEGRATION_MAP.md`
- Flutter models in `frontend/lib/models/*`
- Backend mounted handler request structs in `backend/internal/api/handlers/*`
- Backend JSON response models in `backend/internal/models/*`

Severity:
- **High**: likely runtime parse crash or request decode failure on a matched endpoint.
- **Medium**: silently defaults client-visible data, or can lose precision/meaning.
- **Low**: extra/missing field is tolerated but the contract is misleading or fragile.

## Summary

No matched success-response schema mismatch was found that should immediately crash Flutter parsing. The bugs found are mostly silent defaults where Flutter fills missing backend fields with local defaults, plus request-side nullable fields that Go decodes into non-pointer strings as zero values.

The highest-risk areas are:
- **Groups**: backend omits `is_personal` and `member_count`; Flutter silently displays `false` and `1`.
- **Lists**: backend omits `item_count`; Flutter silently displays `0`.
- **Recipe collections**: backend omits `recipe_count`; Flutter silently displays `0`.
- **Finance amounts**: backend uses `int64`; Flutter uses `int`. This is usually safe on Flutter native runtimes but is a contract/range mismatch, especially if this app is compiled to web or amounts can exceed JavaScript's precise integer range.
- **Nullable string inputs**: several Flutter request models send `null` keys to backend `string` fields, and Go silently stores `""`.

## Matched Endpoint Findings

### Auth

#### POST `/auth/register`
- Request keys/types/nullability match: `{email,password,first_name,last_name}` as required strings.
- Response matches `TokenPair`: `{access_token,refresh_token,user?}`.
- Nested `User` response matches Flutter required keys and types: UUIDs marshal as strings; Go `time.Time` marshals RFC3339 strings accepted by `DateTime.parse`.
- Severity: none.

#### POST `/auth/login`
- Request keys/types/nullability match: `{email,password}` as required strings.
- Response matches `TokenPair` with required token strings and optional `user`.
- Severity: none.

#### POST `/auth/token/refresh`
- Request keys/types/nullability match: `{refresh_token}` as required string.
- Response matches token-only `TokenPair`; Flutter accepts missing `user`.
- Severity: none.

#### POST `/auth/logout`
- Flutter may omit the body if no refresh token is stored. Backend inventory says body is `{refresh_token}`, but the handler always returns `204` and Flutter ignores the response.
- Severity: none for parsing; **Low** contract ambiguity because the documented required body is not enforced/needed by the client path.

#### POST `/auth/password-reset`
- Request keys/types/nullability match: `{email}` as required string.
- Backend returns `{message}`; Flutter ignores the body.
- Severity: none.

#### POST `/auth/password-reset/confirm`
- Request keys/types/nullability match: `{token,new_password}` as required strings.
- Backend returns `{message}`; Flutter ignores the body.
- Severity: none.

#### POST `/auth/guest`
- No request body on Flutter; backend expects none.
- Response matches `TokenPair`.
- Severity: none.

#### GET `/auth/me`
- Response matches `User`.
- Backend extra internal `password_hash` is tagged `json:"-"` and is not emitted.
- Severity: none.

#### PATCH `/auth/me`
- Request keys match optional `{first_name,last_name,avatar_url}`.
- Flutter `UpdateUserRequest.toJson()` includes keys with `null`; backend pointer fields decode JSON `null` as nil, so omitted and explicit null behave the same.
- Response matches `User`.
- Severity: none.

#### DELETE `/auth/me`
- No response body expected or parsed.
- Severity: none.

#### POST `/auth/change-password`
- Request keys/types/nullability match: `{old_password,new_password}` as required strings.
- Backend returns `{message}`; Flutter ignores the body.
- Severity: none.

#### POST `/auth/guest/convert`
- Request keys/types/nullability match: `{email,password,first_name,last_name}` as required strings.
- Response matches `TokenPair`.
- Severity: none.

#### POST `/auth/claim-account`
- Request keys/types/nullability match: `{password,first_name,last_name}` as required strings.
- Response matches `TokenPair`; Flutter accepts optional `user`.
- Severity: none.

### Groups

#### POST `/groups`
- Request keys/types/nullability match: Flutter sends `{name,description}`; backend decodes `services.CreateGroupInput` with `Name string`, `Description *string`.
- Response mismatch:
  - Backend `Group` emits `{id,name,description?,created_by,created_at,updated_at}`.
  - Flutter `Group.fromJson()` expects `is_personal` and `member_count`, but defaults missing values to `false` and `1`.
  - Backend emits extra `created_by`, which Flutter ignores.
- Severity: **Medium**. This silently changes UI/domain state for every created group.

#### GET `/groups?limit&offset`
- Query parameter types align as integers.
- Response mismatch is the same backend `Group` vs Flutter `Group`: missing `is_personal`, missing `member_count`, extra `created_by`.
- Severity: **Medium**.

#### GET `/groups/{id}`
- Path ID is UUID string on both sides.
- Response mismatch is the same backend `Group` vs Flutter `Group`.
- Severity: **Medium**.

#### PATCH `/groups/{id}`
- Request keys/types/nullability match optional `{name,description}`.
- Response mismatch is the same backend `Group` vs Flutter `Group`.
- Severity: **Medium**.

#### DELETE `/groups/{id}`
- No response body expected or parsed.
- Severity: none.

#### POST `/groups/join`
- Request keys/types/nullability match: `{code}` as required string.
- Response mismatch is the same backend `Group` vs Flutter `Group`.
- Severity: **Medium**.

### Lists

#### POST `/lists`
- Request keys align: `{group_id,name,type}`.
- Type detail: Flutter sends `group_id` as a string UUID; Go decodes into `uuid.UUID`.
- Response mismatch:
  - Backend `List` emits `{id,group_id,name,type,created_at,updated_at}`.
  - Flutter `ItemList.fromJson()` expects `item_count`, but defaults missing values to `0`.
- Severity: **Medium**. Created/listed lists can show `0` items even when the backend does not provide count semantics.

#### GET `/lists?group_id&limit&offset`
- Query keys align; `group_id` is a UUID string.
- Response mismatch is the same backend `List` vs Flutter `ItemList`: missing `item_count`.
- Severity: **Medium**.

#### GET `/lists/{id}`
- Path ID is UUID string on both sides.
- Response mismatch is the same backend `List` vs Flutter `ItemList`: missing `item_count`.
- Severity: **Medium**.

#### DELETE `/lists/{id}`
- No response body expected or parsed.
- Severity: none.

#### POST `/lists/{id}/items`
- Request keys/types/nullability match: `{name,quantity,unit}` as string/int/string.
- Response `ListItem` matches required Flutter keys: `{id,list_id,name,quantity,unit,checked,position,created_at,updated_at}`.
- Severity: none.

#### GET `/lists/{id}/items?limit&offset`
- Query parameter types align as integers.
- Response list item schema matches `ListItem`.
- Severity: none.

#### PATCH `/lists/{id}/items/{item_id}`
- Request keys/types/nullability match partial `{name?,quantity?,unit?,checked?,position?}`.
- Flutter omits null fields; backend pointer fields distinguish omitted values.
- Response list item schema matches `ListItem`.
- Severity: none.

#### DELETE `/lists/{id}/items/{item_id}`
- No response body expected or parsed.
- Severity: none.

#### POST `/lists/{id}/reorder`
- Request keys align: `{item_ids:[string]}` to Go `[]uuid.UUID`.
- No response body expected or parsed.
- Severity: none.

### Chores

#### POST `/chores`
- Request keys align: `{group_id,name,description?,rotation_type,frequency,is_active}`.
- Type detail: Flutter sends `group_id` as string UUID; Go decodes into `uuid.UUID`.
- `description` nullability aligns with Go `*string`.
- Response `Chore` matches Flutter required keys.
- Severity: none.

#### GET `/chores?group_id&limit&offset`
- Query keys/types align.
- Response `Chore` matches Flutter required keys.
- Severity: none.

#### GET `/chores/{id}`
- Path ID is UUID string on both sides.
- Response `Chore` matches Flutter required keys.
- Severity: none.

#### DELETE `/chores/{id}`
- No response body expected or parsed.
- Backend uses `api.RespondJSON(204, nil)`, which writes no JSON body.
- Severity: none.

#### POST `/chores/{id}/complete`
- Request key aligns: `{notes}`.
- Flutter always sends `notes`, possibly `null`; backend decodes `*string`, so null is nil.
- No response body expected or parsed.
- Severity: none.

#### POST `/chores/{id}/rotate`
- No request body expected by Flutter; backend does not decode one.
- No response body expected or parsed.
- Severity: none.

#### POST `/chores/{id}/skip`
- No request body expected by Flutter; backend does not decode one.
- No response body expected or parsed.
- Severity: none.

### Finance

#### POST `/expenses`
- Request keys align: `{group_id,payer_id,amount,description,category,currency,date,split_user_ids}`.
- Type mismatches:
  - Backend `amount` is `int64`; Flutter model uses `int`.
  - Backend UUID fields decode from string UUIDs, which matches Flutter transport.
  - Backend `date` is `time.Time`; Flutter sends ISO-8601 string via `toIso8601String()`.
- Response:
  - Backend `Expense` emits `updated_at`; Flutter ignores it.
  - Flutter does not expect `updated_at`, so there is no parse crash.
- Severity: **Medium** for `amount` range/precision contract mismatch.

#### GET `/expenses?group_id&limit&offset`
- Query keys/types align.
- Response has the same `amount int64` vs Flutter `int` contract mismatch.
- Backend extra `updated_at` is ignored.
- Severity: **Medium**.

#### GET `/expenses/{id}`
- Path ID is UUID string on both sides.
- Response has the same `amount int64` vs Flutter `int` contract mismatch.
- Backend extra `updated_at` is ignored.
- Severity: **Medium**.

#### DELETE `/expenses/{id}`
- No response body expected or parsed.
- Backend uses `api.RespondJSON(204, nil)`, which writes no JSON body.
- Severity: none.

#### POST `/expenses/{id}/splits`
- Request keys align: `{user_id,amount}`.
- Type mismatch: backend `amount` is `int64`; Flutter uses `int`.
- Backend returns `Split`, but Flutter intentionally ignores the response body.
- Severity: **Medium** for amount range/precision; no parse risk because response is write-only in Flutter.

#### POST `/expenses/{id}/settle`
- Request keys align: `{from_user_id,to_user_id,amount}`.
- Type mismatch: backend `amount` is `int64`; Flutter uses `int`.
- Backend returns `Settlement`, but Flutter intentionally ignores the response body.
- Severity: **Medium** for amount range/precision; no parse risk because response is write-only in Flutter.

### Recipes & Collections

#### POST `/recipes`
- Request keys align: `{title,description,prep_time,cook_time,servings,image_url,is_public}`.
- Nullability mismatch:
  - Flutter `CreateRecipeRequest.imageUrl` is nullable and `toJson()` includes `image_url: null` by default.
  - Backend `createRecipeRequest.ImageURL` is a non-pointer `string`.
  - Go JSON decoding of `null` into a string leaves the zero value `""`, silently converting absent image into an empty URL.
- Response:
  - Backend `Recipe` emits extra `user_id`; Flutter ignores it.
  - Backend `image_url` is a required string; Flutter accepts it as `String?`.
- Severity: **Medium**. Silent `null` -> `""` conversion changes semantics and can affect image rendering/caching logic.

#### GET `/recipes?limit&offset`
- Query keys/types align.
- Response `Recipe` matches Flutter required keys; backend extra `user_id` is ignored.
- Severity: none.

#### GET `/recipes/{id}`
- Path ID is UUID string on both sides.
- Response `Recipe` matches Flutter required keys; backend extra `user_id` is ignored.
- Severity: none.

#### DELETE `/recipes/{id}`
- No response body expected or parsed.
- Severity: none.

#### GET `/collections?limit&offset`
- Query keys/types align.
- Response mismatch:
  - Backend `Collection` emits `{id,user_id,name,created_at,updated_at}`.
  - Flutter `RecipeCollection.fromJson()` expects `recipe_count`, but defaults missing values to `0`.
  - Backend extra `user_id` and `updated_at` are ignored.
- Severity: **Medium**. Collection counts will silently display as zero unless the frontend fills them elsewhere.

### Living Things

#### POST `/living-things`
- Request keys align: `{group_id,name,species,location,image_url}`.
- Type detail: backend request uses `group_id` as `string` and parses UUID manually; Flutter sends string UUID.
- Nullability mismatch:
  - Flutter `location` and `image_url` are nullable and are included as `null` keys.
  - Backend request uses non-pointer `string` fields.
  - Go decodes `null` into zero-value `""`, silently converting null/absent values to empty strings.
- Response:
  - Backend `LivingThing` emits `location` and `image_url` as strings.
  - Flutter accepts those fields as nullable strings, so parsing does not crash.
- Severity: **Medium**. Null vs empty string changes UI semantics and makes "unset" indistinguishable from intentionally empty.

#### GET `/living-things?group_id&limit&offset`
- Query keys/types align.
- Response `LivingThing` matches Flutter required keys; backend string `location`/`image_url` are accepted as `String?`.
- Severity: none for parsing; **Low** semantic drift remains if backend stores empty strings instead of null.

#### GET `/living-things/{id}`
- Path ID is UUID string on both sides.
- Response `LivingThing` matches Flutter required keys.
- Severity: none for parsing; **Low** semantic drift for empty string optional fields.

#### DELETE `/living-things/{id}`
- No response body expected or parsed.
- Severity: none.

#### POST `/living-things/{id}/care-schedule`
- Request keys align: `{frequency_value,frequency_unit,next_due}`.
- Type detail: backend `next_due` is `time.Time`; Flutter sends ISO-8601 string via `toIso8601String()`.
- Backend returns `CareSchedule`, but Flutter intentionally ignores the response body.
- Severity: none.

#### POST `/living-things/{id}/care-logs`
- Request key aligns: `{notes}`.
- Nullability mismatch:
  - Flutter `LogCareRequest.notes` is nullable and `toJson()` includes `notes: null`.
  - Backend `logCareRequest.Notes` is a non-pointer `string`.
  - Go decodes null into `""`, silently converting absent notes to empty string.
- Backend returns `CareLog`, but Flutter intentionally ignores the response body.
- Severity: **Medium** for silent null-to-empty conversion.

## Cross-Cutting Notes

### Time Formats
- Backend `time.Time` values marshal as RFC3339 strings.
- Flutter uses `DateTime.parse(...)` for responses and `toIso8601String()` for requests.
- No time format mismatch was found on matched endpoints.

### UUIDs
- Backend UUID fields either marshal as JSON strings or decode string UUIDs into `uuid.UUID`.
- Flutter models represent UUIDs as `String`.
- No UUID transport mismatch was found on matched endpoints, assuming values are valid UUID strings.

### Error Envelopes
- Auth and Group services only extract a nested error shape when `data['error']` is an object, but backend error helpers mostly return `error` as a string.
- Current Flutter code falls back to generic messages rather than crashing.
- Severity: **Low** for schema consistency; this is a UX/debuggability issue, not a success-model parse bug.

### Unmounted Vault Calls
- Flutter has `VaultService` calls and `VaultItem` models, and backend has `vault.go` handler/model shapes that mostly align.
- `INTEGRATION_MAP.md` marks Vault as **UNMOUNTED**, so these are not matched production endpoints and were not counted as matched schema mismatches.
- If mounted later, re-check `reminder_date` time parsing and extra backend `created_by`; neither appears to crash `VaultItem.fromJson()`.

## Clean Matched Endpoints

The following matched endpoints showed no request/response schema bug under the current Flutter parsing behavior:
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/token/refresh`
- `POST /auth/password-reset`
- `POST /auth/password-reset/confirm`
- `POST /auth/guest`
- `GET /auth/me`
- `PATCH /auth/me`
- `DELETE /auth/me`
- `POST /auth/change-password`
- `POST /auth/guest/convert`
- `POST /auth/claim-account`
- `DELETE /groups/{id}`
- `POST /lists/{id}/items`
- `GET /lists/{id}/items`
- `PATCH /lists/{id}/items/{item_id}`
- `DELETE /lists/{id}/items/{item_id}`
- `POST /lists/{id}/reorder`
- `POST /chores`
- `GET /chores`
- `GET /chores/{id}`
- `DELETE /chores/{id}`
- `POST /chores/{id}/complete`
- `POST /chores/{id}/rotate`
- `POST /chores/{id}/skip`
- `DELETE /expenses/{id}`
- `GET /recipes`
- `GET /recipes/{id}`
- `DELETE /recipes/{id}`
- `POST /living-things/{id}/care-schedule`

