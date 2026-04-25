## Frontend consumption inventory (Flutter)

Base URL/prefix is assembled in `frontend/lib/services/api_client.dart` from:
- `ApiConfig.baseUrl`: `http://localhost:8000`
- `ApiConfig.apiPrefix`: `/api/v1`
- Effective `dio.baseUrl`: `http://localhost:8000/api/v1`

Auth:
- Access token stored in SharedPreferences under `access_token`
- Refresh token stored under `refresh_token`
- Sent on every request (if present) as `Authorization: Bearer <token>` (`AuthInterceptor`)
- On `401` responses, `TokenRefreshInterceptor` posts `POST /auth/token/refresh` with body `{"refresh_token": "<refresh>"}` and if `200`:
  - overwrites stored tokens with `response.data['access_token']` and `response.data['refresh_token']`
  - retries the original request once
- If refresh fails or refresh token missing: clears tokens and sets `authStateProvider` to `false`

Error handling patterns:
- `AuthService` and `GroupService` attempt to parse `400` as `data['error']['message']` (expects nested error object) and otherwise map status codes to generic messages.
- Most other services (`ListService`, `ChoreService`, `FinanceService`, `RecipeService`, `LivingService`, `VaultService`) do not parse backend error bodies; they map only a few status codes to generic strings.

## API calls by service

### Auth (`frontend/lib/services/auth_service.dart`)
- **POST** `/auth/register`
  - Body: `RegisterRequest.toJson()` => `{email,password,first_name,last_name}`
  - Expects: `TokenPair.fromJson()` with `{access_token,refresh_token,user?}`
- **POST** `/auth/login`
  - Body: `{email,password}`
  - Expects: `{access_token,refresh_token,user?}`
- **POST** `/auth/token/refresh`
  - Body: `{refresh_token}`
  - Expects: `{access_token,refresh_token}`
- **POST** `/auth/logout`
  - Body: `{refresh_token}` (only if present)
  - Ignores response body; clears tokens regardless
- **POST** `/auth/password-reset`
  - Body: `{email}`
  - Ignores response body
- **POST** `/auth/password-reset/confirm`
  - Body: `{token,new_password}`
  - Ignores response body
- **POST** `/auth/guest`
  - No body
  - Expects: `{access_token,refresh_token,user?}`
- **GET** `/auth/me`
  - Expects: `User.fromJson()` (snake_case fields)
- **PATCH** `/auth/me`
  - Body: `UpdateUserRequest.toJson()` => optional `{first_name,last_name,avatar_url}`
  - Expects: `User`
- **DELETE** `/auth/me`
  - No body
  - Ignores response body; clears tokens
- **POST** `/auth/change-password`
  - Body: `{old_password,new_password}`
  - Ignores response body
- **POST** `/auth/guest/convert`
  - Body: `{email,password,first_name,last_name}`
  - Expects: `{access_token,refresh_token,user?}`
- **POST** `/auth/claim-account`
  - Body: `{password,first_name,last_name}`
  - Expects: `{access_token,refresh_token,user?}`

### Groups (`frontend/lib/services/group_service.dart`)
- **POST** `/groups`
  - Body: `CreateGroupRequest.toJson()` => `{name,description?}`
  - Expects: `Group.fromJson()` (expects extra fields `is_personal`, `member_count`)
- **GET** `/groups?limit&offset`
  - Expects: list of `Group`
- **GET** `/groups/{groupId}`
  - Expects: `Group`
- **PATCH** `/groups/{groupId}`
  - Body: `{name?,description?}`
  - Expects: `Group`
- **DELETE** `/groups/{groupId}`
  - No body
- **POST** `/groups/join`
  - Body: `JoinGroupRequest.toJson()` => `{code}`
  - Expects: `Group`

### Lists (`frontend/lib/services/list_service.dart`)
- **POST** `/lists`
  - Body: `{group_id,name,type}`
  - Expects: `ItemList.fromJson()` (expects `item_count`)
- **GET** `/lists?group_id&limit&offset`
  - Expects: list of `ItemList`
- **GET** `/lists/{id}`
  - Expects: `ItemList`
- **DELETE** `/lists/{id}`
  - No body
- **POST** `/lists/{listId}/items`
  - Body: `{name,quantity,unit}`
  - Expects: `ListItem`
- **GET** `/lists/{listId}/items?limit&offset`
  - Expects: list of `ListItem`
- **PATCH** `/lists/{listId}/items/{itemId}`
  - Body: subset of `{name,quantity,unit,checked,position}`
  - Expects: `ListItem`
- **DELETE** `/lists/{listId}/items/{itemId}`
  - No body
- **POST** `/lists/{listId}/reorder`
  - Body: `ReorderItemsRequest` => `{item_ids:[string]}`
  - Expects: no content

### Chores (`frontend/lib/services/chore_service.dart`)
- **POST** `/chores`
  - Body: `{group_id,name,description?,rotation_type,frequency,is_active}`
  - Expects: `Chore`
- **GET** `/chores?group_id&limit&offset`
  - Expects: list of `Chore`
- **GET** `/chores/{id}`
  - Expects: `Chore`
- **DELETE** `/chores/{id}`
  - No body
- **POST** `/chores/{id}/complete`
  - Body: `{notes: <string?>}` (always includes key even if null)
  - Expects: no content
- **POST** `/chores/{id}/rotate`
  - No body
- **POST** `/chores/{id}/skip`
  - No body

### Finance (`frontend/lib/services/finance_service.dart`)
- **POST** `/expenses`
  - Body: `{group_id,payer_id,amount,description,category,currency,date,split_user_ids:[string]}`
  - Expects: `Expense`
- **GET** `/expenses?group_id&limit&offset`
  - Expects: list of `Expense`
- **GET** `/expenses/{id}`
  - Expects: `Expense`
- **DELETE** `/expenses/{id}`
  - No body
- **POST** `/expenses/{expenseId}/splits`
  - Body: `{user_id,amount}`
  - Expects: ignores response body (backend returns Split)
- **POST** `/expenses/{expenseId}/settle`
  - Body: `{from_user_id,to_user_id,amount}`
  - Expects: ignores response body (backend returns Settlement)

### Recipes (`frontend/lib/services/recipe_service.dart`)
- **POST** `/recipes`
  - Body: `{title,description,prep_time,cook_time,servings,image_url?,is_public}`
  - Expects: `Recipe`
- **GET** `/recipes?limit&offset`
  - Expects: list of `Recipe`
- **GET** `/recipes/{id}`
  - Expects: `Recipe`
- **DELETE** `/recipes/{id}`
  - No body
- **GET** `/collections?limit&offset`
  - Expects: list of `RecipeCollection`

### Living things (`frontend/lib/services/living_service.dart`)
- **POST** `/living-things`
  - Body: `{group_id,name,species,location?,image_url?}`
  - Expects: `LivingThing`
- **GET** `/living-things?group_id&limit&offset`
  - Expects: list of `LivingThing`
- **GET** `/living-things/{id}`
  - Expects: `LivingThing`
- **DELETE** `/living-things/{id}`
  - No body
- **POST** `/living-things/{id}/care-schedule`
  - Body: `{frequency_value,frequency_unit,next_due}`
  - Expects: ignores response body (backend returns CareSchedule)
- **POST** `/living-things/{id}/care-logs`
  - Body: `{notes?}` (always includes key)
  - Expects: ignores response body (backend returns CareLog)

### Vault (`frontend/lib/services/vault_service.dart`)
- **POST** `/vault`
  - Body: `{group_id,type,title,content,reminder_date?}`
  - Expects: `VaultItem`
- **GET** `/vault?group_id&limit&offset`
  - Expects: list of `VaultItem`
- **GET** `/vault/{id}`
  - Expects: `VaultItem`
- **DELETE** `/vault/{id}`
  - No body

