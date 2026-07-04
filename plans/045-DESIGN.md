# Plan 045 Design: Household Dashboard Landing Surface

## Recommendation

Go, but as an incremental replacement inside the existing `/home` hub rather than
as a new tab. The app already has the right cached providers for a read-only
"what needs attention" dashboard, and the current home route is already the
household landing surface. Build v1 as a compact dashboard band above pinwall and
activity, then promote it only if usage proves it should dominate the page.

## 1. Dashboard Job

The dashboard should answer one question: "What needs household attention right
now?" Recommended priority order:

1. Chores needing action: overdue first, then due today.
   Existing data: `cachedCurrentChoresByGroupProvider(groupId)` in
   `frontend/lib/providers/chore_provider.dart`.

2. Money needing action: non-zero household balance and reimbursement pressure.
   Existing data: `cachedFinanceSummaryByGroupProvider(groupId)` and backend
   `GET /finance/summary`.

3. Lists needing action: active shopping/general lists and unpurchased work.
   Existing data: `cachedListsByGroupProvider(groupId)`. Gap: list rows expose
   list count/preview, not a household-level unchecked-item count.

4. Tonight's meal: dinner, then breakfast/lunch fallback.
   Existing data: `todayMealPlansProvider(groupId)` and
   `weekMealPlansSummaryProvider(groupId)`.

5. Upcoming schedule: next calendar item or today's count.
   Existing data: backend `GET /calendar` aggregates meal plans, chores,
   recurring expenses, one-time expenses, and pinwall reminders. Gap: no cached
   dashboard provider yet.

6. Presence/context: who is currently around.
   Existing data: `presentMembersProvider((groupId, meId))`, SSE-backed.
   Treat this as ambient context, not a top-priority alert.

## 2. Reuse vs Rebuild

Reuse the data calculations and visual language, but do not directly promote
`_BoardStatsCard`. It is tightly coupled to the pinwall board's physical cork
metaphor, pushpins, draggable positions, and ticket/index-card styling.

Plan 039 should extract shared note/stat presentation primitives where it makes
sense. The dashboard can depend on those primitives for labels, icon rows, and
tap-through behavior, but its layout should be a separate dashboard component
under `frontend/lib/widgets/hub/` or `frontend/lib/widgets/dashboard/`.

Recommendation: build a new `HouseholdAttentionDashboard` composed from shared
row/tile primitives after Plan 039, not a direct move of `_BoardStatsCard`.

## 3. Data Completeness

Chores: complete for v1. The cached current chore provider has pending
assignment due dates/statuses and supports overdue/due-today counts offline.

Finance: complete for v1. The cached finance summary has balances and
reimbursements. The backend endpoint exists at `GET /finance/summary`.

Lists: partial. The cached list provider gives list metadata, type, count, and
preview. It can support "N active lists" in v1. A true "N unchecked items" signal
needs either a cached aggregate or a lightweight backend summary. Estimated
effort: S-M depending on whether Drift already has enough list-item cache for all
lists.

Meals: complete for v1, network-backed with provider cache behavior. The
dashboard can show today's selected meal and route to meal plan or recipe detail.

Calendar: partial. Backend aggregation exists, but there is no cached dashboard
provider in the current inventory. Estimated effort: M to add a cached calendar
repository/provider, S if v1 uses a network-only `calendarProvider` fallback.

Presence: complete but optional. It is SSE/live state and should disappear
gracefully offline.

## 4. Location and Navigation

Keep `/home` as the route and keep `HouseholdHubScreen` as the entry point.
Replace neither bottom navigation nor route structure. Insert the dashboard as
the first content band after household resolution and before the existing pinwall
section/activity wall.

Routing impact: none for v1. Existing tap-throughs can use current route names:
`chores`, `money`, `lists`, `mealPlan`, `recipeDetail`, and later `calendar`.

Do not add a new tab. The bottom nav already has feature tabs; a dashboard tab
would compete with Home instead of clarifying it.

## 5. Offline Behavior

The dashboard should render cached data first and mark stale states quietly.
Recommended behavior:

- Chores, finance, lists: render cached provider values immediately; show neutral
  zero/empty states when no cache exists.
- Meals: show today's cached/provider value when available; otherwise "Nothing
  planned" rather than a spinner-heavy dashboard.
- Calendar: omit from v1 unless a cached provider exists.
- Presence: hide when empty/offline; do not show it as stale.

Refresh should reuse `HouseholdHubScreen._onRefresh`, which already invalidates
finance, lists, current chores, pinwall posts, and meal-plan providers, then
best-effort refreshes repositories.

## 6. Build Slices

1. V1 read-only attention band (M): add `HouseholdAttentionDashboard` to
   `/home`, backed by cached chores, finance, lists, and today's meal. Tap rows
   through to existing tabs/routes. Depends on Plan 039 only if shared stat-row
   primitives are desired; otherwise can build directly.

2. V1 tests (S): widget test for the dashboard with provider overrides, modeled
   on the pinwall board test from Plan 043.

3. V2 list-item aggregate (S-M): add unchecked-item count across active lists,
   preferably from Drift cache first; add backend summary only if cache coverage
   is insufficient.

4. V3 calendar tile (M): add cached calendar repository/provider or extend an
   existing one, then show the next event/today count.

5. V4 personalization (M-L): sort signals by the current user: assigned chores,
   balances involving me, lists I recently touched, and meals I cook.

Dependency order: Plan 039 → V1 component extraction if shared primitives are
used; Plan 037 is not required for dashboard v1 but should not be mixed into the
same PR because the expenses screen refactor has separate risk.

## Decision

Build it, but only as a small home dashboard first. The existing providers make a
useful v1 cheap enough, and the current home route is already the correct place.
Avoid a new tab and avoid copying `_BoardStatsCard` wholesale.
