# Integration gaps: backend endpoints with no frontend calls

Sources reviewed:
- `BACKEND_SURFACE.md`
- `FRONTEND_CONSUMPTION.md`
- `INTEGRATION_MAP.md`
- Frontend evidence in `frontend/lib/router.dart`, `frontend/lib/providers/*`, and `frontend/lib/screens/*`

Classification rule used here:
- **Likely gap**: the feature has a frontend screen/provider/service or visible UI affordance, but one or more mounted backend operations are not called.
- **Likely intentional**: the backend exposes an endpoint for infra, future/backlog, admin/internal, or a domain with no visible frontend surface found.

## Mounted backend endpoints with no frontend call

### Health

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `GET /healthz` | Likely intentional | Infra/readiness endpoint outside the Flutter API prefix; no frontend health screen/provider found. |
| `GET /readyz` | Likely intentional | Infra/readiness endpoint outside the Flutter API prefix; no frontend health screen/provider found. |
| `GET /internal/health` | Likely intentional | Internal health endpoint; no frontend admin/ops UI found. |

### Groups

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `POST /groups/{id}/members` | Likely gap | Group UI exists (`GroupsListScreen`, `HouseholdHubScreen`) and `GroupService` covers core group CRUD/join, but has no member add/invite method. Hub has a settings button with empty handler. |
| `DELETE /groups/{id}/members/{user_id}` | Likely gap | Same group surface exists, but no member management provider/service/UI call. |
| `PATCH /groups/{id}/members/{user_id}` | Likely gap | Same group surface exists, but no role editing call or UI was found. |
| `GET /groups/{id}/pending-claims` | Likely gap | Auth supports guest/account claiming, and groups have a household hub, but there is no pending-claims service/provider/UI. |
| `POST /groups/{id}/pending-claims/{claim_id}/approve` | Likely gap | Pending-claim approval is backend-mounted, but no approval UI or service method was found. |
| `POST /groups/{id}/pending-claims/{claim_id}/reject` | Likely gap | Pending-claim rejection is backend-mounted, but no rejection UI or service method was found. |

### Lists

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `PATCH /lists/{id}` | Likely gap | Lists have a screen, provider, create sheet, and detail screen. `ListDetailScreen` has a menu item with `TODO: Navigate to edit list`, but `ListService` has no update-list method. |

### Templates

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `POST /templates` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `GET /templates?group_id&limit&offset` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `GET /templates/{id}` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `PATCH /templates/{id}` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `DELETE /templates/{id}` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `POST /templates/{id}/apply` | Likely intentional | No template screen, provider, service, route, or UI affordance found. |
| `POST /chore-templates` | Likely intentional | Chore UI exists, but no chore-template screen/provider/service/UI affordance was found. |
| `GET /chore-templates?group_id&limit&offset` | Likely intentional | Chore UI exists, but no chore-template screen/provider/service/UI affordance was found. |
| `GET /chore-templates/{id}` | Likely intentional | Chore UI exists, but no chore-template screen/provider/service/UI affordance was found. |
| `PATCH /chore-templates/{id}` | Likely intentional | Chore UI exists, but no chore-template screen/provider/service/UI affordance was found. |
| `DELETE /chore-templates/{id}` | Likely intentional | Chore UI exists, but no chore-template screen/provider/service/UI affordance was found. |

### Chores

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `PATCH /chores/{id}` | Likely gap | Chores have a route, screen, provider, and service. `ChoresScreen` has TODOs for creation/detail sheets, and `ChoreService` has no update method. |
| `GET /chores/{id}/assignments?limit&offset` | Likely gap | Chores UI includes "mine/all" filtering concepts, but no assignment listing provider/service call was found. |

### Finance

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `PATCH /expenses/{id}` | Likely gap | Money screen, provider, and service exist, but `FinanceService` has no update-expense call and the UI only loads/deletes/creates splits/settlements per the inventory. |
| `PATCH /expenses/{id}/splits/{split_id}` | Likely gap | Finance service can create splits, but has no split update call; money UI has settlement/timeline surfaces. |
| `DELETE /expenses/{id}/splits/{split_id}` | Likely gap | Finance service can create splits, but has no split delete call. |
| `DELETE /expenses/{id}/settle/{settlement_id}` | Likely gap | Finance service can create settlements, but has no settlement delete call. |
| `POST /recurring-expenses` | Likely intentional | No recurring-expense screen, provider, service, route, or UI affordance found. |
| `GET /recurring-expenses?group_id&limit&offset` | Likely intentional | No recurring-expense screen, provider, service, route, or UI affordance found. |
| `GET /recurring-expenses/{id}` | Likely intentional | No recurring-expense screen, provider, service, route, or UI affordance found. |
| `PATCH /recurring-expenses/{id}` | Likely intentional | No recurring-expense screen, provider, service, route, or UI affordance found. |
| `DELETE /recurring-expenses/{id}` | Likely intentional | No recurring-expense screen, provider, service, route, or UI affordance found. |

### Recipes and collections

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `PATCH /recipes/{id}` | Likely gap | `RecipesScreen`, `recipe_provider.dart`, and `RecipeService` exist, but there is no update method or edit UI. |
| `POST /recipes/{id}/share` | Likely gap | Recipe feature exists and share-target UI includes a Recipes destination, but no recipe sharing call was found. |
| `POST /collections` | Likely gap | `RecipeService` can list collections, so the frontend partially acknowledges collections, but has no create call/UI. |
| `GET /collections/{id}` | Likely gap | Collection listing exists in `RecipeService`, but no detail call/screen was found. |
| `PATCH /collections/{id}` | Likely gap | Collection listing exists in `RecipeService`, but no update call/UI was found. |
| `DELETE /collections/{id}` | Likely gap | Collection listing exists in `RecipeService`, but no delete call/UI was found. |
| `POST /collections/{id}/recipes` | Likely gap | Collection listing exists in `RecipeService`, but no add-recipe-to-collection call/UI was found. |
| `DELETE /collections/{id}/recipes/{recipe_id}` | Likely gap | Collection listing exists in `RecipeService`, but no remove-recipe-from-collection call/UI was found. |

### Living things

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `PATCH /living-things/{id}` | Likely gap | `LivingThingsScreen`, `living_provider.dart`, and `LivingService` exist, but there is no update method. The screen has TODOs for creation/detail navigation. |
| `GET /living-things/{id}/care-schedule` | Likely gap | Living-things UI shows "Next care" data, but the service only creates schedules and does not fetch them. |
| `PATCH /living-things/{id}/care-schedule` | Likely gap | Care scheduling is partially represented by service/UI concepts, but no update call exists. |
| `GET /living-things/{id}/care-logs?limit&offset` | Likely gap | `LivingService` can post care logs, but no log-history call or detail screen was found. |

### Assistant

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `POST /assistant/sessions` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `GET /assistant/sessions?limit&offset` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `GET /assistant/sessions/{id}` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `PATCH /assistant/sessions/{id}` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `DELETE /assistant/sessions/{id}` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `POST /assistant/sessions/{id}/messages` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |
| `GET /assistant/sessions/{id}/messages?limit&offset` | Likely intentional | No assistant/chat screen, provider, service, route, or UI affordance found. |

### Share target

| Endpoint | Classification | Evidence |
| --- | --- | --- |
| `POST /share-target/lists` | Likely gap | `ShareTargetScreen` is routed at `/share-target` and offers a Lists destination, but `_onSave` is TODO and no service call exists. |
| `POST /share-target/recipes` | Likely gap | `ShareTargetScreen` offers a Recipes destination, but `_onSave` is TODO and no service call exists. |

## Unmounted backend handlers that frontend attempts to call

### Vault

Backend handler file `vault.go` is listed as present but unmounted in `BACKEND_SURFACE.md` and `INTEGRATION_MAP.md`. Flutter still defines `VaultService`, `vault_provider.dart`, and `VaultScreen`; `VaultScreen` calls `vaultService.listVaultItems(groupId)`.

| Frontend call | Status | Evidence |
| --- | --- | --- |
| `POST /vault` | Unmounted backend handler; frontend attempts to call | `VaultService.createVaultItem` posts to `/vault`, but the backend vault handler is not mounted. |
| `GET /vault?group_id&limit&offset` | Unmounted backend handler; frontend attempts to call | `VaultService.listVaultItems` gets `/vault`; `VaultScreen._loadItems` calls it. |
| `GET /vault/{id}` | Unmounted backend handler; frontend attempts to call | `VaultService.getVaultItem` gets `/vault/{id}`, but the handler is not mounted. |
| `DELETE /vault/{id}` | Unmounted backend handler; frontend attempts to call | `VaultService.deleteVaultItem` deletes `/vault/{id}`, but the handler is not mounted. |

Other unmounted handler files listed in `BACKEND_SURFACE.md` are `notification.go`, `activity.go`, `oauth.go`, `metrics.go`, `vapid.go`, `debug.go`, and `pprof.go`. No frontend calls to those handler families were found.
