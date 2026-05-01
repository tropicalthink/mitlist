# New App Roadmap — Refined

## Product North Star

Build a household coordination app that connects **lists, recipes, meal plans, chores, and money** into one coherent, fast, mobile-first experience. Every feature should make other features more useful. No silos. Not an ERP.

## What We Learned from Old Mitlist

**The good:**
- Recipe scraping was a killer feature — users loved clipping URLs
- List cost summary → expense generation was genuinely useful (items had prices)
- Bulk item creation, item reordering, templates — fast capture patterns
- Guest accounts with claiming — smooth onboarding

**The bloat:**
- 5-tier recipe scraping with `recipe-scrapers` (400+ sites) was fragile and broke often
- Chore time tracking, financial audit logs, 5 analytics endpoints — underused
- Voting-based member removal — over-engineered
- `common_item_concepts` + i18n translations — required ongoing curation
- Vault/document storage — separate product entirely

## What We Learned from Grocy

**The good:**
- **Cross-module integration is the killer feature** — recipes feed shopping lists, meal plans generate shopping needs
- "Add missing to shopping list" from recipes — genuinely useful
- Calendar aggregation (meal plan + chores + stock due dates) — household coordination at a glance
- Self-production recipes (baking consumes flour, produces bread) — clever but too complex for us

**The bloat (we won't copy):**
- Stock tracking with best-before dates, locations, freezing, tare weight — this is ERP territory
- Barcode scanning, thermal printing, Grocycodes — hardware integration
- Quantity unit conversions, min-stock thresholds, stock journals — too much rigor
- Recipe fulfillment against live stock — we don't track stock

## Our Differentiator

**Grocy is a home ERP. Old mitlist was a feature kitchen sink. We are a coordination layer.**

- Fast capture > accurate tracking
- Social coordination > inventory management
- Recipe → List → Money flow > stock rigor
- Mobile-first, one-thumb usable > desktop dashboard

---

## Phase 1: Foundation + Recipe Extraction Upgrade

**Goal:** Make recipe scraping great again. Start connecting data models.

### Outcomes
- Recipe scraper extracts more fields (description, author, rating, nutrition, video, equipment)
- Ingredients are stored structured (`name`, `qty`, `unit`, `raw`) in `recipe_ingredients`
- Steps stored in `recipe_steps`
- `source_url`, `tags`, `image_options` preserved on recipe
- Existing `description` blob migration path defined

### Major Work
- Add `description`, `author`, `rating_value`, `rating_count`, `nutrition_json`, `video_url`, `equipment`, `source_url`, `image_options`, `tags` to recipe model
- Expand scraper tiers to extract new schema.org fields
- Add ingredient parser: `"2 cups flour"` → `{name:"flour", qty:2, unit:"cups", raw:"2 cups flour"}`
- Update recipe handlers to read/write structured ingredients/steps
- Frontend recipe creation sheet uses structured data
- Migration: parse existing `description` blobs into structured fields

### Kill
- Full chore journal with event emission → replaced by "last 3 actions" on chore card
- Manual rotation controls → auto-rotation only

---

## Phase 2: Lists ↔ Products ↔ Recipes

**Goal:** Lists become product-aware. Recipes become actionable.

### Outcomes
- Items can have **prices** (enables list → expense flow)
- Product picker suggests existing products when typing
- "Add recipe to list" with ingredient check/uncheck UI + servings scaling
- "Add missing to list" from recipe/meal plan checks existing lists for duplicates
- Item suggestions from history
- Shopping trip mode combines lists, groups by store/category

### Major Work
- Add `price_cents` to `list_items` (nullable, integer)
- Product picker in list composer (search products by name)
- "Add recipe to list" endpoint: POST `/recipes/{id}/add-to-list` with `list_id`, `servings`, `selected_ingredient_ids`
- Servings scaling: scale quantities when adding scaled recipe to list
- Shopping trip projection endpoint: GET `/shopping/trip?list_ids=...`
- Item suggestions endpoint based on group/user history
- List templates UI (apply template → create list with pre-filled items)

### Integration Flow: Recipe → List
1. User taps "Add to list" on a recipe
2. Modal shows all ingredients with checkboxes, default all checked
3. User can adjust servings (scales quantities live)
4. Each ingredient attempts to match to a product by name; if matched, uses product's default unit/store
5. Unchecked ingredients are omitted
6. POST creates list items with `name`, `quantity`, `unit`, `product_id`, `price_cents` (if product has price)

### Integration Flow: List → Expense (from old mitlist)
1. Items in a list can have prices
2. "Cost summary" action on list shows: total cost, equal share per user, who added what
3. "Generate expense" creates an expense with splits based on who added items
4. Expense is linked to the list (`list_id`)

---

## Phase 3: Meal Plan (The Hub)

**Goal:** Meal plan becomes the central planning tool.

### Outcomes
- Weekly/daily meal plan with slots (breakfast/lunch/dinner)
- Assign recipes to days; assign chores (cook, cleanup) to people
- "Generate shopping list from week" sums all planned meal ingredients → one list
- Calendar view shows: meal plan + chore due dates + recurring expense due dates
- iCal export for external calendars

### Major Work
- Meal plan model: `date`, `slot`, `recipe_id`, `servings`, `assigned_user_id` (cook)
- Meal plan CRUD endpoints
- Meal calendar screen with recipe picker per day/slot
- "Generate shopping list from week" endpoint
- Calendar aggregation endpoint (meal plan + chores + recurring expenses)
- iCal export endpoint

### Integration Flow: Meal Plan → Shopping List
1. User plans meals for the week
2. Taps "Generate shopping list"
3. App sums all ingredients from all planned recipes, scaled to planned servings
4. Checks existing lists for duplicates (deduplicates by product_id or fuzzy name match)
5. Creates a new shopping list or appends to existing one
6. User reviews before confirming

### Integration Flow: Meal Plan → Chore
1. When planning a meal, optionally assign "cook" and "cleanup" as chores
2. These appear in the chore list with due date = meal date
3. Completing the chore is separate from the meal plan

---

## Phase 4: Chores (Simple but Connected)

**Goal:** Chores are trackable and connect to lists when needed.

### Outcomes
- Subtasks (checklist within a chore)
- Skip reason + notes
- "Add supplies to list" from chore detail
- Due reminders via push
- Simple auto-rotation (round-robin)
- "Last 3 actions" on chore card (not full journal)

### Major Work
- `chore_subtasks` migration + CRUD
- Subtask UI in chore detail sheet
- Skip reason field on skip endpoint
- "Add supplies to list" action on chore detail (links to list composer)
- Due reminder job + push notification
- Auto-rotation logic (existing `/chores/{id}/rotate`)

### Kill
- Full chore journal/history with event emission
- Manual rotation controls (advance/reorder/set-current)
- Chore analytics/fairness endpoints

---

## Phase 5: Money (Lists ↔ Expenses)

**Goal:** Shopping has a natural financial close-out.

### Outcomes
- Item prices on lists
- Cost summary dialog (total, equal share, per-user contributions)
- Generate expense from list
- Recurring expense UI
- Settlement suggestions UI
- Receipt upload polish

### Major Work
- Add `price_cents` to `list_items` (already in Phase 2, this is the UI)
- Cost summary endpoint: GET `/lists/{id}/cost-summary`
- Generate expense endpoint: POST `/lists/{id}/generate-expense`
- Recurring expense create/edit UI
- Settlement suggestions panel
- Receipt upload preview

### Integration Flow: List → Expense (detailed)
1. User adds prices to items while shopping (or estimates beforehand)
2. Opens "Cost summary" from list options
3. Dialog shows: total cost, equal share, table of who added what and their balance
4. Taps "Generate expense" → creates expense with `list_id` and splits based on item contributions
5. Expense appears in Money tab
6. Users can settle from the expense detail

---

## Phase 6: Notifications + Pinwall

**Goal:** Reduce manual checking. Make the household feel alive.

### Outcomes
- Push notifications: due chores, list activity, expense created, meal plan changes
- Pinwall stays as simple sticky notes + recent activity highlights
- Weekly digest: "This week: 3 meals planned, $45 in expenses, 2 chores due"

### Major Work
- Notification preference model + handlers
- Push notification delivery for chore due, list item added, expense created, meal plan changed
- Weekly digest job
- Pinwall: add small "Recent activity" strip above notes (last 3 household events)

### Kill
- Full activity timeline with filters
- Group activity journal
- Debug endpoint for scheduled jobs

---

## Phase 7: Polish

**Goal:** Make it feel cohesive, fast, and ready.

### Outcomes
- Consistent empty, loading, error states across all screens
- Mobile layout pass
- Accessibility pass on forms and buttons
- Performance profiling for heavy screens (recipe list, meal calendar)
- E2E happy path tests
- Release checklist

### Major Work
- Empty states for lists, chores, recipes, expenses, meal plan
- Loading skeletons for all main screens
- Error retry patterns
- Mobile viewport review
- Accessibility checklist (labels, focus, contrast)
- E2E test plan for: register → group → list → recipe clip → meal plan → chore → expense → settle

---

## Priority Sequence (Revised)

1. **Recipe scraping upgrade** — structured ingredients, more fields, ingredient parser
2. **Lists + Products** — item prices, product picker, suggestions, templates, shopping trip
3. **Recipe → List integration** — "Add to list" with check/uncheck, servings scaling
4. **Meal Plan** — calendar, weekly planning, generate shopping list from week
5. **Chores** — subtasks, skip reasons, due reminders, "add supplies to list"
6. **Money** — cost summary, generate expense from list, recurring expense UI, settlements
7. **Notifications** — push for all modules, weekly digest
8. **Polish** — states, performance, accessibility, E2E, release

---

## Anti-Patterns (from grocy and old mitlist that we avoid)

| Anti-Pattern | Why We Avoid It |
|---|---|
| Stock/inventory tracking | ERP territory; users don't want to scan barcodes for milk |
| Quantity unit conversions | "1 cup = 236ml" is cognitive overhead; store raw text + simple qty |
| Recipe fulfillment against stock | We don't track stock; "add missing to list" is our equivalent |
| Self-production recipes | Baking → stock is too niche for MVP |
| Financial audit logs | Households don't need audit trails; clear balances are enough |
| Chore time tracking | Users just check "done"; timers add friction |
| Full event journals | Nobody reads 50 "chore completed" entries |
| Attachment quotas | Size limit + error message is sufficient |
