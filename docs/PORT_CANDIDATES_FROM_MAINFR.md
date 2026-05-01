# Port Candidates from `git/mainfr`

## Context

Fetched `git/mainfr` is old Mitlist on a different stack:

- Backend: `be/` Python/FastAPI + Alembic
- Frontend: `fe/` Vue/TypeScript
- Current app: `backend/` Go + `frontend/` Flutter

Do not merge or cherry-pick `git/mainfr` wholesale. Treat it as product and implementation reference material. Port behavior, tests, UX patterns, and data-shape lessons into the current Go/Flutter architecture.

## Product Filter

Current Mitlist should remain a household coordination layer:

- Fast capture over exact tracking
- Lists, recipes, meal plans, chores, and money should reinforce each other
- Mobile-first, low-friction flows
- No ERP-style inventory, document vault, or household admin sprawl

Use this filter before porting anything from `git/mainfr`.

## Port First

### 1. Recipe Scraping Robustness

Source areas:

- `be/app/services/recipe_scraping_service.py`
- `be/app/api/v1/endpoints/recipes.py`
- `fe/src/services/recipeService.ts`
- `fe/src/types/recipe.ts`
- Recent commits around `feat(recipe-scraping): enhance recipe data extraction with robust multi-tier merging`

Why:

Recipe clipping is one of the highest-value Mitlist features and directly enables recipe -> list -> meal plan flows.

Port as:

- Improve current Go scraper with old multi-tier extraction ideas.
- Preserve the current simpler dependency posture; do not recreate a fragile 400-site scraper stack.
- Add regression fixtures for JSON-LD, microdata, OpenGraph/meta fallback, and malformed recipe pages.
- Ensure scraped ingredients remain structured but preserve raw text.

Acceptance:

- Existing Go recipe tests pass.
- New scraper fixtures cover successful merge, partial extraction, and fallback behavior.
- Flutter recipe creation/detail screens display the richer scraped fields.

### 2. Offline Queue and Connectivity UX

Source areas:

- `fe/src/stores/offline.ts`
- `fe/src/utils/offlineQueue.ts`
- `fe/src/utils/queryPersister.ts`
- `fe/src/components/OfflineIndicator.vue`
- Commits around `offline-support`

Why:

Mitlist is used in stores, kitchens, and shared-household contexts where mobile connectivity is unreliable.

Port as:

- Flutter-first offline indicator.
- Queue low-risk writes such as list item toggles, list item creation, and chore completion.
- Keep conflict handling conservative: show retry/error state rather than silently overwriting server state.
- Reuse current Drift/local cache patterns where possible.

Acceptance:

- User sees a clear offline/syncing/error status.
- Toggling list items while offline is queued and retried.
- Failed retries produce a recoverable UI state.

### 3. Auth and Error Feedback

Source areas:

- `be/app/api/auth/*`
- `be/app/core/error_handlers.py`
- `fe/src/utils/apiErrorMessage.ts`
- `fe/src/types/errors.ts`
- Recent commit `feat(auth): enhance error logging and user feedback during authentication`

Why:

Auth failures and session expiry are high-friction moments. Better error mapping improves the whole app without adding scope.

Port as:

- Map backend error codes into stable Flutter user-facing messages.
- Improve login/signup/session-expired flows.
- Keep logs useful for debugging without exposing secrets.

Acceptance:

- Login/signup failures show specific, plain-language errors.
- Session expiry routes users predictably.
- Backend tests cover representative auth error paths.

### 4. Notification Digest and Preferences

Source areas:

- `be/app/services/push_notification_service.py`
- `be/app/api/v1/endpoints/push_notifications.py`
- `be/app/jobs/*`
- `fe/src/stores/notifications.ts`
- `fe/src/services/pushNotificationService.ts`

Why:

Current Go/Flutter app already has notification preferences, but delivery and digest behavior need hardening.

Port as:

- Preference-aware delivery for chores, list activity, expenses, and meal-plan changes.
- Weekly digest based on current Go data sources.
- Keep pinwall/activity lightweight: highlights, not a full audit timeline.

Acceptance:

- Notification preferences are respected.
- Weekly digest has real aggregate data.
- Tests cover opt-out and digest aggregation.

### 5. Accessibility and Mobile Polish Patterns

Source areas:

- `fe/src/utils/accessibility.ts`
- Vue component tests around pages/forms
- Tailwind/component spacing decisions as visual reference only

Why:

Current Flutter app is close enough to benefit from a polish pass before adding more modules.

Port as:

- Flutter semantics labels for icon-only actions.
- Better focus order in forms and sheets.
- Consistent empty/loading/error states.
- Mobile viewport review for dense screens: lists, expenses, recipes, chores.

Acceptance:

- Main flows are usable with screen reader semantics.
- Text does not overflow at small viewport widths.
- Forms expose clear labels and errors.

## Port Later

### i18n and Locale Coverage

Source areas:

- `fe/src/i18n/`

Reason to defer:

Useful, but it multiplies UI work. Do after MVP flows stabilize.

Port later as:

- Flutter localization structure.
- Start with nav, auth, lists, chores, recipes, and money.
- Avoid translating unstable screens too early.

### Recipe Public Sharing

Source areas:

- `be/app/api/v1/endpoints/recipes.py`
- `fe/src/pages/RecipeSharePage.vue`
- `fe/src/components/recipes/RecipeSharingDialog.vue`

Reason to defer:

Good growth loop, but not required for the household coordination MVP.

Port later as:

- Public read-only recipe links.
- Share controls in recipe detail.
- Expiration/revocation if needed.

### Old Test Scenarios

Source areas:

- `fe/src/tests/`
- `fe/src/pages/__tests__/`
- `be/app/tests/`

Reason to defer:

Worth mining, but direct reuse is not possible across stacks.

Port later as:

- Convert the best scenarios into Go handler/service tests and Flutter widget/integration tests.

## Do Not Port

### Living Things / Plant / Pet Care

Source areas:

- `be/app/api/v1/endpoints/living_things.py`
- `be/app/models/living_thing.py`
- `fe/src/pages/LivingThingsPage.vue`
- `fe/src/types/living-thing.ts`

Reason:

This is a separate product vertical. It pulls Mitlist toward a kitchen-sink household OS instead of a coordination layer.

### Vault / Document Storage

Source areas:

- `be/app/api/v1/endpoints/vault.py`
- `be/app/models/vault.py`
- `fe/src/pages/VaultPage.vue`

Reason:

Document storage is not core to lists, recipes, chores, meal plans, or money coordination. It also increases security and storage obligations.

### Voting / Heavy Household Governance

Source areas:

- `be/app/api/v1/endpoints/voting.py`
- `be/app/models/voting.py`
- `fe/src/types/voting.ts`

Reason:

Overbuilt for shared household coordination. Keep member management simple.

### ERP Inventory and Stock Rigor

Source areas:

- Common item curation
- Barcode-heavy flows
- Stock/min-stock logic
- Unit conversion rigor

Reason:

Conflicts with the current product filter. Mitlist should help people coordinate, not maintain a home ERP.

### Full Audit / Analytics / History Layers

Source areas:

- `be/app/repositories/audit_repository.py`
- `be/app/services/analytics_service.py`
- Broad history endpoints and filtered activity timelines

Reason:

Recent activity highlights are enough. Full audit/history adds backend and UI complexity without clear household value.

## Suggested Execution Order

1. Recipe scraping robustness
2. Auth/error feedback
3. Offline queue and connectivity UX
4. Notification digest and preference enforcement
5. Accessibility/mobile polish
6. i18n
7. Public recipe sharing

## Notes for Implementers

- Port one slice at a time.
- Start with tests or fixtures that capture the old behavior.
- Rebuild in current Go/Flutter style using existing services, repositories, providers, theme tokens, and widgets.
- Do not add dependencies without a concrete need.
- Do not reintroduce old product verticals that were intentionally removed.
