# Task Backlog — Refined

## Status Legend

- `todo`: not started
- `doing`: in progress
- `blocked`: waiting on another task
- `done`: complete and verified

---

## Slice 1: Recipe Scraping Upgrade

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| RS-001 | todo | Add migration: extend `recipes` with description, author, rating, nutrition, video, equipment, source_url, image_options, tags | Backend | Migration up/down passes |
| RS-002 | todo | Expand `RecipeClipResponse` and scraper for new schema.org fields | Backend | Scraper tests pass |
| RS-003 | todo | Add ingredient parser (qty/unit/name from raw text) | Backend | Parser tests pass |
| RS-004 | todo | Update recipe handlers for structured ingredients/steps | Backend | Handler tests pass |
| RS-005 | todo | Add migration script for existing description blobs | Backend | Migration tests pass |
| RS-006 | todo | Update Flutter recipe models | Frontend | Flutter analyze passes |
| RS-007 | todo | Update recipe creation sheet with image picker, tags, source URL | Frontend | Manual UI smoke |
| RS-008 | todo | Update recipe detail sheet with structured ingredients/steps | Frontend | Manual UI smoke |
| RS-009 | todo | Update recipe list cards with rating and tags | Frontend | Manual UI smoke |

---

## Slice 2: Lists + Products + Item Prices

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| LP-001 | todo | Add `price_cents` to `list_items` | Backend | Migration up/down passes |
| LP-002 | todo | Add product search endpoint | Backend | Handler tests pass |
| LP-003 | todo | Add item suggestions endpoint | Backend | Handler tests pass |
| LP-004 | todo | Add shopping trip projection endpoint | Backend | Handler tests pass |
| LP-005 | todo | Add shopping trip bulk complete endpoint | Backend | Handler tests pass |
| LP-006 | todo | Add Flutter product picker to list composer | Frontend | Flutter analyze passes |
| LP-007 | todo | Add item suggestions chips | Frontend | Flutter analyze passes |
| LP-008 | todo | Add price input to list item composer | Frontend | Flutter analyze passes |
| LP-009 | todo | Add shopping trip screen | Frontend | Manual UI smoke |
| LP-010 | todo | Add list template UI | Frontend | Manual UI smoke |
| LP-011 | todo | Add "Cost summary" action to list options | Frontend | Flutter analyze passes |

---

## Slice 3: Recipe → List Integration

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| RL-001 | todo | Add `POST /recipes/{id}/add-to-list` endpoint with scaling | Backend | Handler tests pass |
| RL-002 | todo | Add `POST /recipes/{id}/missing-to-list` deduplication endpoint | Backend | Handler tests pass |
| RL-003 | todo | Add product matching logic for ingredients | Backend | Service tests pass |
| RL-004 | todo | Add "Add to list" action on recipe cards | Frontend | Manual UI smoke |
| RL-005 | todo | Add ingredient checklist modal with servings scaler | Frontend | Manual UI smoke |
| RL-006 | todo | Add "Add missing to list" action | Frontend | Manual UI smoke |

---

## Slice 4: Meal Plan

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| MP-001 | todo | Add `meal_plans` migration | Backend | Migration up/down passes |
| MP-002 | todo | Add meal plan CRUD endpoints | Backend | Handler tests pass |
| MP-003 | todo | Add `POST /meal-plans/generate-shopping-list` endpoint | Backend | Handler tests pass |
| MP-004 | todo | Add calendar aggregation endpoint | Backend | Handler tests pass |
| MP-005 | todo | Add iCal export endpoint | Backend | Handler tests pass |
| MP-006 | todo | Add meal plan calendar screen | Frontend | Manual UI smoke |
| MP-007 | todo | Add recipe picker for calendar days | Frontend | Manual UI smoke |
| MP-008 | todo | Add calendar view with meals + chores + expenses | Frontend | Manual UI smoke |

---

## Slice 5: Chores (Connected)

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| CH-001 | todo | Add `chore_subtasks` migration | Backend | Migration up/down passes |
| CH-002 | todo | Add chore subtask CRUD endpoints | Backend | Handler tests pass |
| CH-003 | todo | Add `skip_reason` to skip endpoint | Backend | Handler tests pass |
| CH-004 | todo | Add due reminder job | Backend | Job tests pass |
| CH-005 | todo | Add subtask UI to chore detail sheet | Frontend | Manual UI smoke |
| CH-006 | todo | Add skip reason input | Frontend | Manual UI smoke |
| CH-007 | todo | Add "Add supplies to list" action | Frontend | Manual UI smoke |
| CH-008 | todo | Add "Last 3 actions" to chore card | Frontend | Flutter analyze passes |

---

## Slice 6: Money (List → Expense)

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| MN-001 | todo | Add `GET /lists/{id}/cost-summary` endpoint | Backend | Handler tests pass |
| MN-002 | todo | Add `POST /lists/{id}/generate-expense` endpoint | Backend | Handler tests pass |
| MN-003 | todo | Add recurring expense processing job | Backend | Job tests pass |
| MN-004 | todo | Add settlement suggestions endpoint | Backend | Handler tests pass |
| MN-005 | todo | Add cost summary dialog UI | Frontend | Manual UI smoke |
| MN-006 | todo | Add recurring expense create/edit UI | Frontend | Flutter analyze passes |
| MN-007 | todo | Add settlement suggestions panel | Frontend | Manual UI smoke |
| MN-008 | todo | Polish receipt upload preview | Frontend | Manual UI smoke |

---

## Slice 7: Notifications + Pinwall

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| NA-001 | todo | Add notification preference model and migration | Backend | Migration tests pass |
| NA-002 | todo | Add notification preference handlers | Backend | Handler tests pass |
| NA-003 | todo | Add push notification delivery for chores, lists, expenses, meal plan | Backend | Service tests pass |
| NA-004 | todo | Add weekly digest job | Backend | Job tests pass |
| NA-005 | todo | Add recent activity endpoint for pinwall | Backend | Handler tests pass |
| NA-006 | todo | Add notification preferences UI | Frontend | Flutter analyze passes |
| NA-007 | todo | Add weekly digest display | Frontend | Flutter analyze passes |
| NA-008 | todo | Add "Recent activity" strip to pinwall | Frontend | Manual UI smoke |

---

## Slice 8: Polish

| ID | Status | Task | Area | Verification |
| --- | --- | --- | --- | --- |
| PF-001 | todo | Add consistent empty states across main screens | Frontend | Visual/manual review |
| PF-002 | todo | Add consistent loading skeletons across main screens | Frontend | Visual/manual review |
| PF-003 | todo | Add error retry patterns | Frontend | Manual UI smoke |
| PF-004 | todo | Run mobile layout pass | Frontend | Manual viewport review |
| PF-005 | todo | Run accessibility pass on forms and buttons | Frontend | Accessibility checklist |
| PF-006 | todo | Add E2E happy-path test | Full stack | Test passes |
| PF-007 | todo | Add release checklist | Docs | Checklist committed |

---

## Immediate Sprint Recommendation

Start with:

1. `RS-001` through `RS-005`: Recipe scraping upgrade (backend)
2. `RS-006` through `RS-009`: Recipe scraping upgrade (frontend)
3. `LP-001` through `LP-005`: Lists + products + prices (backend)
4. `LP-006` through `LP-011`: Lists + products + prices (frontend)

These tasks produce the most visible product value while enabling all downstream integrations.
