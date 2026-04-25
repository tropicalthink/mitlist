# Integration gaps: pagination and filtering

Scope: backend endpoints that accept `limit`/`offset` or other query filters, checked against Flutter service and screen usage.

## Backend pagination contract

- Shared helper: most handlers use `parsePagination`, which reads query params named `limit` and `offset`, parses them as integers, defaults `limit` to `50`, caps `limit` at `500`, and clamps negative `offset` to `0` (`backend/internal/api/handlers/common.go:85-101`).
- Repositories also clamp `limit` to `50..500` (`backend/internal/repositories/pagination.go:3-20`).
- Response shape is a bare JSON array for list endpoints. There is no `total`, `next_offset`, `has_more`, or cursor metadata visible in the handlers, so the frontend can only infer additional pages by requesting another `offset` and checking result length.

## Mounted backend endpoints with query params

| Endpoint | Query params | Backend behavior | Frontend usage | Gap |
|---|---|---|---|---|
| `GET /groups` | `limit:int`, `offset:int` | Uses `parsePagination` (`group.go:46-60`). | `GroupService.listGroups({limit=50, offset=0})` sends matching params (`group_service.dart:33-45`). Screens call default first page (`groups_list_screen.dart:52-55`, `chores_screen.dart:62-66`, `expenses_screen.dart:118-122`, `vault_screen.dart:81-85`). | Param names/types match. No pagination UI or offset advancement found. |
| `GET /lists` | `group_id:uuid`, `limit:int`, `offset:int` | Requires non-empty valid `group_id`; uses `parsePagination` (`list.go:60-86`). | `ListService.listLists(groupId, {limit=50, offset=0})` sends matching params (`list_service.dart:22-28`). `ListsScreen` can call with `widget.groupId ?? ''` (`lists_screen.dart:62-65`). | Param names/types match when `groupId` is valid. `ListsScreen` may omit required `group_id` by sending `''`; no pagination UI. |
| `GET /lists/{id}/items` | `limit:int`, `offset:int` | Uses `parsePagination` (`list.go:200-220`). | `ListService.listItems(listId, {limit=50, offset=0})` sends matching params (`list_service.dart:50-54`); provider exposes only default first page (`list_provider.dart:14-16`). | Param names/types match. No screen/provider wiring for additional pages found. |
| `GET /templates` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; uses `parsePagination` (`template.go:54-75`). | No frontend template service or calls found. | Missing frontend integration, including required `group_id` and pagination. |
| `GET /chore-templates` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; manually parses `limit`/`offset` with default `limit=50` (`template.go:217-242`). | No frontend chore-template service or calls found. | Missing frontend integration. Handler does not use shared `parsePagination`, so negative `offset` is not clamped at handler level. |
| `GET /chores` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; uses `parsePagination` (`chore.go:62-83`). | `ChoreService.listChores(groupId, {limit=50, offset=0})` sends matching params (`chore_service.dart:22-28`). `ChoresScreen` uses the first group or `''` (`chores_screen.dart:62-66`). | Param names/types match when `groupId` is valid. Screen may send empty `group_id`; no pagination UI. |
| `GET /chores/{id}/assignments` | `limit:int`, `offset:int` | Manually parses `limit`/`offset` with default `limit=50` (`chore.go:242-267`). | No frontend call found. | Missing frontend integration. Handler does not use shared `parsePagination`, so negative `offset` is not clamped at handler level. |
| `GET /expenses` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; uses `parsePagination` (`finance.go:80-99`). | `FinanceService.listExpenses(groupId, {limit=50, offset=0})` sends matching params (`finance_service.dart:22-28`). `ExpensesScreen` uses the first group or `''` (`expenses_screen.dart:118-122`). | Param names/types match when `groupId` is valid. Screen may send empty `group_id`; no pagination UI. |
| `GET /recurring-expenses` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; manually parses `limit`/`offset` with default `limit=50` (`finance.go:434-459`). | No frontend recurring-expense service or calls found. | Missing frontend integration. Handler does not use shared `parsePagination`, so negative `offset` is not clamped at handler level. |
| `GET /recipes` | `limit:int`, `offset:int` | Uses `parsePagination` (`recipe.go:84-98`). | `RecipeService.listRecipes({limit=50, offset=0})` sends matching params (`recipe_service.dart:22-28`). `RecipesScreen` calls default first page (`recipes_screen.dart:52-72`). | Param names/types match. No pagination UI or offset advancement found. |
| `GET /collections` | `limit:int`, `offset:int` | Uses `parsePagination` (`recipe.go:274-288`). | `RecipeService.listCollections({limit=50, offset=0})` sends matching params (`recipe_service.dart:43-49`), but no caller found outside the service. | Param names/types match in service. UI/provider wiring appears missing. |
| `GET /living-things` | `group_id:uuid`, `limit:int`, `offset:int` | Requires valid `group_id`; uses `parsePagination` (`living.go:114-133`). | `LivingService.listLivingThings(groupId, {limit=50, offset=0})` sends matching params (`living_service.dart:22-28`). `LivingThingsScreen` calls `listLivingThings('')` (`living_things_screen.dart:55-58`). | Param names/types match only when caller provides a valid UUID. Current screen appears to always omit required `group_id`; no pagination UI. |
| `GET /living-things/{id}/care-logs` | `limit:int`, `offset:int` | Uses `parsePagination` (`living.go:362-380`). | No frontend list-care-logs call found; frontend only posts care logs (`living_service.dart:44-50`). | Missing frontend read integration and pagination. |
| `GET /assistant/sessions` | `limit:int`, `offset:int` | Uses `parsePagination` (`assistant.go:77-89`). | No frontend assistant service or calls found. | Missing frontend integration. |
| `GET /assistant/sessions/{id}/messages` | `limit:int`, `offset:int` | Uses `parsePagination` (`assistant.go:197-215`). | No frontend assistant service or calls found. | Missing frontend integration. |

## Handler files with query params but not mounted

These handlers exist, but `backend/cmd/api/main.go:90-172` mounts feature routes for groups, lists, templates, chores, finance, recipes, living things, assistant, and share target only. Vault, activity logs, and notifications are absent from the mounted route list.

| Endpoint | Query params | Frontend usage | Gap |
|---|---|---|---|
| `GET /vault` | `group_id:uuid`, `limit:int`, `offset:int` | `VaultService.listVaultItems(groupId, {limit=50, offset=0})` calls it (`vault_service.dart:22-28`); `VaultScreen` uses first group or `''` (`vault_screen.dart:81-85`). | Frontend calls an unmounted backend surface. It may also send empty `group_id`; no pagination UI. |
| `GET /activity-logs` | `group_id:uuid`, `limit:int`, `offset:int` | No frontend calls found. | Backend handler is unmounted and frontend integration is missing. |
| `GET /notifications` | `limit:int`, `offset:int` | No API calls found; account screen has only local notification toggle state. | Backend handler is unmounted and frontend integration is missing. |

## Param name/type mismatches

- No direct query-name mismatch was found for implemented Flutter services: frontend uses `limit`, `offset`, and `group_id`, matching backend handlers.
- No direct query-type mismatch was found for implemented services: Flutter method signatures use `int` for `limit`/`offset` and `String` for `groupId`; backend parses integer query strings and UUID string values.
- Practical mismatch: the backend requires `group_id` to be a valid UUID on group-scoped list endpoints, but several frontend screens can pass `''` as a fallback or hard-coded value. Those calls will fail validation rather than returning an empty first page.

## Missing pagination UI and wiring

Evidence from service usage shows only default first-page calls:

- `GroupService.listGroups`, `ListService.listLists`, `ListService.listItems`, `ChoreService.listChores`, `FinanceService.listExpenses`, `RecipeService.listRecipes`, `RecipeService.listCollections`, `LivingService.listLivingThings`, and `VaultService.listVaultItems` all expose `limit=50, offset=0` defaults.
- Searches found no screen call passing non-default `limit` or `offset`; `offset:` appears only in service query parameters and unrelated UI animation/shadow code.
- Main screens load once and replace local state from the first page: groups, lists, household hub list count, chores, expenses, recipes, vault, and living things all call their service methods without offset advancement.

Impact:

- Any backend collection with more than 50 rows is truncated in the current UI.
- There is no visible "load more", infinite scroll, next/previous page control, or Riverpod state carrying `offset`/`hasMore`.
- Since responses are bare arrays, adding pagination UI will need either client-side "request next page until short page" inference or a backend response envelope with pagination metadata.

## Endpoints requiring `group_id` that frontend may omit

| Endpoint | Frontend risk |
|---|---|
| `GET /lists` | `ListsScreen` uses `widget.groupId ?? ''`; an absent route argument sends an invalid empty `group_id`. |
| `GET /chores` | `ChoresScreen` uses `groups.first.id` or `''`; no groups means invalid empty `group_id`. |
| `GET /expenses` | `ExpensesScreen` uses `groups.first.id` or `''`; no groups means invalid empty `group_id`. |
| `GET /living-things` | `LivingThingsScreen` currently calls `listLivingThings('')` unconditionally. |
| `GET /vault` | `VaultScreen` uses `groups.first.id` or `''`; also targets an unmounted backend route. |

No frontend calls were found for `GET /templates`, `GET /chore-templates`, `GET /recurring-expenses`, or `GET /activity-logs`; all require `group_id` if/when integrated.

## Highest-confidence gaps

1. **Missing pagination UI/wiring across current list screens.** Services support `limit` and `offset`, but screens and providers use the default first page only.
2. **Group-scoped endpoints can receive empty `group_id`.** The most concrete case is `LivingThingsScreen`, which always passes `''`; chores, expenses, vault, and some list entry points use `''` fallback.
3. **Several paginated backend endpoints have no frontend integration.** Templates, chore templates, chore assignments, recurring expenses, care logs, assistant sessions/messages, activity logs, and notifications are absent from frontend usage; vault has frontend usage but is not mounted.
4. **A few backend handlers parse pagination inconsistently.** `GET /chore-templates`, `GET /chores/{id}/assignments`, and `GET /recurring-expenses` manually parse `limit`/`offset` instead of `parsePagination`, leaving offset normalization inconsistent with the shared contract.
