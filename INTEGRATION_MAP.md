## Integration map (Backend ↔ Flutter)

Legend:
- **MATCHED**: Flutter calls this endpoint (path + method align).
- **PARTIAL**: Flutter calls some, but not all operations/params/fields for this resource.
- **MISSING**: Backend endpoint exists but no corresponding Flutter call found.
- **UNMOUNTED**: Handler exists in backend code but not mounted in `cmd/api/main.go` (so Flutter cannot call it in prod).

Base path alignment:
- Backend default prefix: `/api/v1`
- Flutter baseUrl+prefix: `http://localhost:8000/api/v1`
- **Result**: base prefixes align in dev, assuming backend runs on `:8000`.

Auth alignment:
- Backend accepts `Authorization: Bearer <token>` (or cookie).
- Flutter sends `Authorization: Bearer <token>`.
- Flutter refreshes on `401` via `POST /auth/token/refresh` and retries once.

## Public / Auth
- **POST** `/auth/register` — **MATCHED**
- **POST** `/auth/login` — **MATCHED**
- **POST** `/auth/token/refresh` — **MATCHED**
- **POST** `/auth/logout` — **MATCHED**
- **POST** `/auth/password-reset` — **MATCHED**
- **POST** `/auth/password-reset/confirm` — **MATCHED**
- **POST** `/auth/guest` — **MATCHED**
- **GET** `/auth/me` — **MATCHED**
- **PATCH** `/auth/me` — **MATCHED**
- **DELETE** `/auth/me` — **MATCHED**
- **POST** `/auth/change-password` — **MATCHED**
- **POST** `/auth/guest/convert` — **MATCHED**
- **POST** `/auth/claim-account` — **MATCHED**
- **POST** `/auth/push-subscriptions` — **PARTIAL** (Flutter client implemented; platform registration not wired)
- **GET** `/auth/push-subscriptions` — **PARTIAL** (Flutter client implemented; no UI flow)
- **DELETE** `/auth/push-subscriptions/{id}` — **PARTIAL** (Flutter client implemented; no UI flow)

## Public config
- **GET** `/vapid` — **MATCHED** (backend mounted; Flutter can fetch web-push key when implemented)

## Groups
- **POST** `/groups` — **MATCHED** (Flutter expects extra fields; see gaps)
- **GET** `/groups?limit&offset` — **MATCHED**
- **GET** `/groups/{id}` — **MATCHED**
- **PATCH** `/groups/{id}` — **MATCHED**
- **DELETE** `/groups/{id}` — **MATCHED**
- **POST** `/groups/join` — **MATCHED**
- **POST** `/groups/{id}/members` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **DELETE** `/groups/{id}/members/{user_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **PATCH** `/groups/{id}/members/{user_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **GET** `/groups/{id}/pending-claims` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **POST** `/groups/{id}/pending-claims/{claim_id}/approve` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **POST** `/groups/{id}/pending-claims/{claim_id}/reject` — **PARTIAL** (service method exists; UI/tools wiring pending)

## Lists
- **POST** `/lists` — **MATCHED** (Flutter expects `item_count`; see gaps)
- **GET** `/lists?group_id&limit&offset` — **MATCHED**
- **GET** `/lists/{id}` — **MATCHED**
- **PATCH** `/lists/{id}` — **PARTIAL** (service method exists; UI not wired)
- **DELETE** `/lists/{id}` — **MATCHED**
- **POST** `/lists/{id}/items` — **MATCHED**
- **GET** `/lists/{id}/items?limit&offset` — **MATCHED**
- **PATCH** `/lists/{id}/items/{item_id}` — **MATCHED**
- **DELETE** `/lists/{id}/items/{item_id}` — **MATCHED**
- **POST** `/lists/{id}/reorder` — **MATCHED**

## Templates
- **ALL /templates + /chore-templates endpoints** — **PARTIAL** (Flutter client implemented; UI/tools wiring pending)

## Chores
- **POST** `/chores` — **MATCHED**
- **GET** `/chores?group_id&limit&offset` — **MATCHED**
- **GET** `/chores/{id}` — **MATCHED**
- **PATCH** `/chores/{id}` — **PARTIAL** (service method exists; UI not wired)
- **DELETE** `/chores/{id}` — **MATCHED**
- **POST** `/chores/{id}/rotate` — **MATCHED**
- **POST** `/chores/{id}/complete` — **MATCHED**
- **POST** `/chores/{id}/skip` — **MATCHED**
- **GET** `/chores/{id}/assignments` — **MISSING**

## Finance
- **POST** `/expenses` — **MATCHED**
- **GET** `/expenses?group_id&limit&offset` — **MATCHED**
- **GET** `/expenses/{id}` — **MATCHED**
- **PATCH** `/expenses/{id}` — **PARTIAL** (service method exists; UI not wired)
- **DELETE** `/expenses/{id}` — **MATCHED**
- **POST** `/expenses/{id}/splits` — **MATCHED (write-only)** (Flutter ignores response)
- **PATCH** `/expenses/{id}/splits/{split_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **DELETE** `/expenses/{id}/splits/{split_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **POST** `/expenses/{id}/settle` — **MATCHED (write-only)** (Flutter ignores response)
- **DELETE** `/expenses/{id}/settle/{settlement_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **ALL /recurring-expenses endpoints** — **PARTIAL** (service methods exist; UI/tools wiring pending)

## Recipes & collections
- **POST** `/recipes` — **MATCHED**
- **GET** `/recipes?limit&offset` — **MATCHED**
- **GET** `/recipes/{id}` — **MATCHED**
- **PATCH** `/recipes/{id}` — **PARTIAL** (service method exists; UI not wired)
- **DELETE** `/recipes/{id}` — **MATCHED**
- **POST** `/recipes/{id}/share` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **POST** `/collections` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **GET** `/collections?limit&offset` — **MATCHED**
- **GET** `/collections/{id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **PATCH** `/collections/{id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **DELETE** `/collections/{id}` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **POST** `/collections/{id}/recipes` — **PARTIAL** (service method exists; UI/tools wiring pending)
- **DELETE** `/collections/{id}/recipes/{recipe_id}` — **PARTIAL** (service method exists; UI/tools wiring pending)

## Living things
- **POST** `/living-things` — **MATCHED**
- **GET** `/living-things?group_id&limit&offset` — **MATCHED**
- **GET** `/living-things/{id}` — **MATCHED**
- **PATCH** `/living-things/{id}` — **PARTIAL** (service method exists; UI not wired)
- **DELETE** `/living-things/{id}` — **MATCHED**
- **POST** `/living-things/{id}/care-schedule` — **MATCHED (write-only)** (Flutter ignores response)
- **GET** `/living-things/{id}/care-schedule` — **MISSING**
- **PATCH** `/living-things/{id}/care-schedule` — **MISSING**
- **POST** `/living-things/{id}/care-logs` — **MATCHED (write-only)** (Flutter ignores response)
- **GET** `/living-things/{id}/care-logs` — **MISSING**

## Assistant
- **ALL /assistant/* endpoints** — **MISSING**

## Share target
- **POST** `/share-target/lists` — **MATCHED**
- **POST** `/share-target/recipes` — **MATCHED**

## Unmounted backend handlers
Not callable in production unless mounted:
- Vault (`/vault*`) — **MOUNTED**
- Notifications (`/notifications*`) — **MOUNTED**
- Activity logs (`/activity-logs*`) — **MOUNTED**
- OAuth (`/oauth*` equivalent) — **MOUNTED**
- Metrics/VAPID/Debug/Pprof — **UNMOUNTED** (expected)

