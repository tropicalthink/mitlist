# Plan 031: Activate dormant signals — predictive restock (phase 1) + pantry subtraction (phase 2)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` unless a reviewer told you they maintain it.
>
> **Read first**: `plans/INTELLIGENCE-NORTH-STAR.md`. This plan is naturally
> compliant: everything runs **on-device** off data already in Drift. No models,
> no network, no cost.
>
> **Drift check (run first)**:
> `git diff --stat 6c0df971..HEAD -- frontend/lib/storage/app_database.dart frontend/lib/services/scan/suggestion_service.dart frontend/lib/screens/lists/list_detail_screen.dart`
> On a mismatch with the excerpts below, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M (phase 1) + M (phase 2)
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction (feature) — activates data already collected
- **Planned at**: commit `6c0df971`, 2026-06-13

## Why this matters

The app already records two rich signals and **reads neither**:

1. **`purchase_history`** — written on every check-off
   (`list_repository.dart` `_doPurchaseSignal`, with timestamp + quantity),
   synced, stored in Drift with `getRecentPurchases` already implemented — but
   **no feature consumes it**. The buy cadence is flowing into a dead end.
2. **`products`** (`minStock`/`inStock` in `list_models.dart`) — a stock table
   present since the first migration, used only as a passive FK; no "running low"
   or pantry feature reads it.

Phase 1 turns purchase cadence into **predictive restock** ("you usually buy milk
every ~6 days — it's been 8"). Phase 2 turns the stock fields into **pantry
subtraction / running-low**. Both are pure on-device reads of data you already
have — high payoff per effort, zero new dependency, fully offline.

## Current state

- `frontend/lib/storage/app_database.dart`:
  - `PurchaseHistoryTable` (line ~227), indexed by `group_id` + `canonical_item_id`.
  - `getRecentPurchases({...})` (line ~1041) — **the existing query with no
    caller.** Read its exact signature before using it.
- `frontend/lib/repositories/list_repository.dart` `_doPurchaseSignal` (~505) —
  the writer (one `purchase_history` row per check-off, carrying canonical id +
  quantity + timestamp).
- `frontend/lib/services/scan/suggestion_service.dart` — existing co-occurrence
  "frequently bought alongside" `SuggestionService.suggest({...})` returning a
  `GrocerySuggestion` (NOTE: this `GrocerySuggestion` differs from the one in
  `grocery_suggestion_service.dart` — keep them distinct; don't cross-import).
  Restock suggestions sit **alongside** this, as another reason-tagged source.
- `frontend/lib/screens/lists/list_detail_screen.dart` `_refreshSuggestions`
  (~172) already blends `grocerySuggestions` + `productSuggestions` into
  `ListComposerBar`. Restock suggestions surface through this same plumbing.
- `frontend/lib/models/list_models.dart` (~272, ~325) — `Product` with
  `minStock`/`inStock`; used for prefill, not for stock logic yet.

Conventions: services in `frontend/lib/services/`, one concern each; providers in
`frontend/lib/providers/`; tests in `frontend/test/services/` (model after
`token_store_test.dart` for plain logic, `outbox_coordinator_test.dart` for
in-memory Drift).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Install | `cd frontend && flutter pub get` | exit 0 |
| Analyze | `cd frontend && flutter analyze lib/ test/` | exit 0 |
| Tests | `cd frontend && flutter test test/services/restock_service_test.dart` | pass |
| Full suite | `cd frontend && flutter test` | no NEW failures vs baseline |

## Scope

**In scope (phase 1):**
- `frontend/lib/services/restock_service.dart` (create)
- `frontend/lib/providers/grocery_provider.dart` (add a `restockServiceProvider`)
- `frontend/lib/screens/lists/list_detail_screen.dart` (blend restock into `_refreshSuggestions` / composer suggestions) **or** a small hub card — pick the composer path (less new UI)
- `frontend/test/services/restock_service_test.dart` (create)
- Possibly one read-only query helper in `app_database.dart` **only if**
  `getRecentPurchases` can't return per-item history grouped (prefer reusing it)

**In scope (phase 2 — do after phase 1 lands):**
- Pantry logic over `products.inStock`/`minStock`: a "running low" source
  (`inStock <= minStock`) and recipe→list subtraction. Fleshed into full steps
  when phase 1 is in.

**Out of scope:**
- Any backend change — this is on-device only. (`purchase_history` already syncs.)
- The co-occurrence `SuggestionService` internals — restock is additive.
- New analytics/insights screens — phase 1 surfaces suggestions, not dashboards.

## Git workflow

- Branch: `advisor/031-activate-dormant-signals`
- Conventional commits per unit (service+test; provider+wiring).
- Do NOT push.

## Steps (phase 1 — predictive restock)

### Step 1: `RestockService` — cadence from purchase history

Create `frontend/lib/services/restock_service.dart`. Pure, testable logic:
- `Future<List<RestockSuggestion>> due({required String groupId, DateTime? now})`:
  read purchase history (via `getRecentPurchases` — reuse it), group rows by
  `canonicalItemId`, and for each item with **≥ 3 purchases** compute the typical
  interval as the **median gap** between consecutive purchase timestamps. An item
  is "due" when `now - lastPurchase >= intervalDays` (optionally with a small
  tolerance). Return items sorted by how overdue they are.
- Keep the median/interval math in a `@visibleForTesting static` pure function
  taking `List<DateTime>` → `Duration?` (null when < 3 points), so tests need no DB.
- Define `class RestockSuggestion { final String canonicalItemId; final String name; final int intervalDays; final int daysSince; }`.
- Exclude items already on the current open list (pass in the current item set, or
  filter at the call site).

**Verify**: `cd frontend && flutter analyze lib/` → exit 0.

### Step 2: Provider + surface in the composer suggestions

- Add `restockServiceProvider` in `grocery_provider.dart` (mirror
  `grocerySuggestionServiceProvider`).
- In `list_detail_screen.dart` `_refreshSuggestions`, when the composer query is
  **empty** (the "what else do we need" moment), fetch `restock.due(...)` and
  include the results in the suggestions shown by `ListComposerBar`, tagged with a
  reason ("usually every N days"). Reuse the existing suggestion rendering; don't
  add a new list section. Keep it behind the same focus/debounce flow already there.

**Verify**: `cd frontend && flutter analyze lib/ test/` → exit 0.

### Step 3: Tests

Create `frontend/test/services/restock_service_test.dart`:
- median-interval pure function: `[]`/one/two points → null; evenly spaced points
  → correct median; irregular gaps → median, not mean.
- "due" logic: an item bought every ~7 days and last bought 9 days ago → due; 3
  days ago → not due; an item with 2 purchases → excluded (insufficient history).
- Optionally an in-memory Drift test seeding `purchase_history` and asserting
  `due(...)` returns the overdue item (model after `outbox_coordinator_test.dart`).

**Verify**: `cd frontend && flutter test test/services/restock_service_test.dart` → pass.

### Step 4: Full gates

**Verify**:
- `cd frontend && flutter analyze lib/ test/` → exit 0.
- `cd frontend && flutter test` → no NEW failures beyond the known
  `frontend_flows_test.dart` issue.

## Test plan

- `restock_service_test.dart` — the cadence math (pure) + "due" logic + optional
  Drift-backed end-to-end. The pure math is the core regression guard.
- Verification: targeted test passes; full suite shows no new failures.

## Done criteria (phase 1)

- [ ] `cd frontend && flutter analyze lib/ test/` exits 0
- [ ] `restock_service_test.dart` exists and passes; median-interval + due logic covered
- [ ] `cd frontend && flutter test` — no NEW failures vs baseline
- [ ] `grep -rn "getRecentPurchases" frontend/lib` now shows a real consumer (RestockService)
- [ ] North-star gate: on-device only, no network/model added
- [ ] No files outside the in-scope list modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Drift check shows `getRecentPurchases`'s signature changed and the excerpt no
  longer matches — re-confirm before using it.
- `getRecentPurchases` cannot return enough history to group per item (e.g. it
  caps results) — report; a new query helper may be needed (in scope, but confirm
  first).
- Surfacing restock would require restructuring `ListComposerBar`'s suggestion
  model beyond adding a tagged source — STOP and report.

## Phase 2 (later): pantry subtraction / running low

Sketch — full steps after phase 1:
- "Running low" source: items where `inStock <= minStock` → suggestions tagged
  "running low", surfaced like restock.
- Recipe→list subtraction: when adding a recipe (plan 029 path), reduce requested
  quantities by `inStock` for matched canonical items.
- Needs a minimal stock-edit affordance (set in_stock/min_stock) — confirm whether
  any UI exposes `products` before building; if none, that UI is part of phase 2.

## Maintenance notes

- Cheapest high-value win in the intelligence set: it reads data already flowing
  into a dead end. No external dependency, no model, fully offline.
- The "≥ 3 purchases" and tolerance thresholds live in `RestockService` — tune in
  one place. Watch for noisy cadence on staples bought irregularly; the median (not
  mean) is deliberate to resist outliers.
- Pairs with the co-occurrence `SuggestionService`: together they make the
  empty-composer state genuinely useful ("you usually need…", "often bought with…").
