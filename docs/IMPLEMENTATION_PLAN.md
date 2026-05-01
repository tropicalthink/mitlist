# Implementation Plan — Refined

## Scope

This plan turns the refined roadmap into executable engineering slices. Each slice ships with backend support, Flutter UI, tests, and a short verification note.

## Execution Rules

- Keep each pull-sized slice focused on one user-visible capability.
- Start with backend data contract and service tests when a feature changes behavior.
- Add or update Flutter models and services before screen work.
- Add UI only after the API shape is stable.
- Run backend tests and Flutter analysis before marking a slice done.
- Do not add dependencies unless the feature cannot be implemented cleanly with existing tools.
- Prioritize cross-module integrations: every new feature should connect to at least one existing feature.

---

## Slice 1: Recipe Scraping Upgrade

### Goal

Make recipe scraping extract more fields, parse ingredients into structured data, and preserve metadata currently lost.

### Backend Tasks

- Add migration: extend `recipes` table with `description`, `author`, `rating_value`, `rating_count`, `nutrition_json`, `video_url`, `equipment_json`, `source_url`, `image_options`, `tags`
- Expand `RecipeClipResponse` with new fields
- Expand scraper JSON-LD/Microdata extraction for new schema.org fields
- Add ingredient parser: regex-based extraction of quantity, unit, name from raw text
- Update recipe create/update handlers to accept and store structured ingredients/steps
- Update recipe get/list handlers to return structured data
- Add migration script to parse existing `description` blobs into structured fields
- Add tests for new extraction tiers and ingredient parser

### Frontend Tasks

- Update recipe model to include new fields
- Update recipe creation sheet to display scraped fields (image picker from `image_options`, tags, source URL)
- Update recipe detail sheet to show structured ingredients and steps
- Update recipe list cards to show rating, tags, source domain

### Acceptance Checks

- Scraping a URL populates all available fields
- Ingredients display as structured list (qty + unit + name)
- Steps display as numbered list
- Existing recipes migrate cleanly from description blob
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 2: Lists + Products + Item Prices

### Goal

Lists become product-aware and price-aware. Foundation for list → expense flow.

### Backend Tasks

- Add `price_cents` (nullable int) to `list_items`
- Add product search endpoint: GET `/products?search=...`
- Add item suggestions endpoint: GET `/lists/suggestions?group_id=...`
- Add shopping trip projection endpoint: GET `/shopping/trip?list_ids=...`
- Add shopping trip bulk complete endpoint: POST `/shopping/complete`
- Add list template apply endpoint (backend already exists, verify coverage)
- Add tests for all new endpoints

### Frontend Tasks

- Add price input to list item composer and detail
- Add product picker (search products, autocomplete)
- Add item suggestions chips in list composer
- Add shopping trip screen with store/category grouping
- Add list template UI
- Add "Cost summary" action to list options menu

### Acceptance Checks

- Items can have prices
- Product picker suggests existing products
- Shopping trip combines items from multiple lists
- Bulk complete updates all source items
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 3: Recipe → List Integration

### Goal

Recipes become actionable. Users can add recipe ingredients to lists with control.

### Backend Tasks

- Add endpoint: POST `/recipes/{id}/add-to-list`
  - Params: `list_id`, `servings` (optional, defaults to recipe servings), `ingredient_ids` (optional, defaults to all)
  - Scales quantities based on servings ratio
  - Matches ingredients to products by name; uses product default unit/store
  - Returns created list item IDs
- Add endpoint: POST `/recipes/{id}/missing-to-list`
  - Checks existing lists for items with matching product_id or fuzzy name
  - Returns list of ingredients that would be added vs skipped
- Add tests for scaling, product matching, deduplication

### Frontend Tasks

- "Add to list" action on recipe cards and detail sheet
- Modal: ingredient checklist with check/uncheck, servings spinner
- Preview of what will be added (item name, scaled qty, unit)
- "Add missing to list" action on meal plan and recipe detail

### Acceptance Checks

- Adding recipe to list creates correct items with scaled quantities
- Unchecked ingredients are omitted
- Duplicate checking prevents adding items already on lists
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 4: Meal Plan

### Goal

Weekly meal planning that generates shopping lists and connects to chores.

### Backend Tasks

- Add migration: `meal_plans` table (`id`, `group_id`, `date`, `slot`, `recipe_id`, `servings`, `cook_user_id`, `created_at`)
- Add meal plan CRUD endpoints
- Add endpoint: POST `/meal-plans/generate-shopping-list`
  - Sums all ingredients from planned recipes in date range
  - Scales by planned servings
  - Deduplicates against existing lists
  - Creates or appends to shopping list
- Add calendar aggregation endpoint: GET `/calendar?from=...&to=...`
  - Returns meal plan entries + chore due dates + recurring expense due dates
- Add iCal export endpoint: GET `/calendar/ical`
- Add tests for all endpoints

### Frontend Tasks

- Add meal plan calendar screen (weekly view, day slots)
- Recipe picker for calendar days
- "Generate shopping list" action from meal plan
- Calendar view showing meals + chores + expenses

### Acceptance Checks

- Meal plan entries persist date, slot, recipe, servings
- Generating shopping list creates correct items with scaled quantities
- Calendar shows all event types
- iCal export is valid and subscribable
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 5: Chores (Connected)

### Goal

Chores with subtasks, skip reasons, supplies-to-list, and due reminders.

### Backend Tasks

- Add `chore_subtasks` migration (chore_id, title, completed, position)
- Add subtask CRUD endpoints
- Add `skip_reason` field to skip endpoint
- Add "add supplies to list" endpoint or reuse list item creation
- Add due reminder job (query chores with due dates in next 24h, send push)
- Add tests for subtasks, skip reasons, reminders

### Frontend Tasks

- Subtask checklist in chore detail sheet
- Skip reason input when skipping
- "Add supplies to list" action in chore detail
- Due reminder push notification handling

### Acceptance Checks

- Subtasks can be created, toggled, reordered, deleted
- Skip reason is stored and visible
- Supplies action creates list items
- Reminders fire for due chores
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 6: Money (List → Expense)

### Goal

Lists with prices generate expenses. Complete the money vertical slice.

### Backend Tasks

- Add cost summary endpoint: GET `/lists/{id}/cost-summary`
  - Returns total cost, equal share, per-user contributions
- Add generate expense endpoint: POST `/lists/{id}/generate-expense`
  - Creates expense with `list_id` and splits based on who added items
- Add recurring expense processing job (backend may exist, verify and add UI)
- Add settlement suggestions endpoint (backend may exist, verify and add UI)
- Add tests for cost summary, expense generation

### Frontend Tasks

- Cost summary dialog (total, equal share, user balance table)
- "Generate expense" button in cost summary dialog
- Recurring expense create/edit UI
- Settlement suggestions panel
- Receipt upload preview polish

### Acceptance Checks

- Cost summary matches item prices
- Generated expense has correct splits
- Recurring expenses create on schedule
- Settlement math is correct
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 7: Notifications + Pinwall

### Goal

Reduce manual checking. Pinwall feels alive.

### Backend Tasks

- Add notification preference model + migration
- Add notification preference handlers
- Add push notification delivery for:
  - Chore due (24h before, day of)
  - List item added by another user
  - Expense created
  - Meal plan changed
- Add weekly digest job
- Add recent activity endpoint for pinwall (last 10 household events)

### Frontend Tasks

- Notification preferences UI
- Push notification handling
- Weekly digest display
- Pinwall: add "Recent activity" strip above sticky notes

### Acceptance Checks

- Users control notification types
- Push notifications arrive for configured events
- Weekly digest aggregates data correctly
- Pinwall shows recent activity
- `go test ./...` passes
- `flutter analyze` passes

---

## Slice 8: Polish

### Goal

Ship a cohesive, fast, accessible app.

### Frontend Tasks

- Consistent empty states across all screens
- Consistent loading skeletons across all screens
- Error retry patterns
- Mobile layout pass
- Accessibility pass (labels, focus, contrast)

### Backend Tasks

- E2E happy path test
- Performance profiling for heavy endpoints
- Release checklist

### Acceptance Checks

- All screens have empty/loading/error states
- App is usable on small screens
- Forms are accessible
- E2E tests pass
- `go test ./...` passes
- `flutter analyze` passes

---

## Verification Matrix

Each slice must include:

- Backend unit or service tests
- Handler tests for new routes
- Flutter model/service coverage where project patterns exist
- `go test ./...`
- `flutter analyze`
- Migration up/down check when schema changes

## Suggested Order

1. Slice 1: Recipe scraping upgrade
2. Slice 2: Lists + products + item prices
3. Slice 3: Recipe → list integration
4. Slice 4: Meal plan
5. Slice 5: Chores
6. Slice 6: Money
7. Slice 7: Notifications + pinwall
8. Slice 8: Polish
