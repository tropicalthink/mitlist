# Plan 029: Recipe → canonical shopping — parse ingredients well, resolve to canonical items

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` unless a reviewer told you they maintain it.
>
> **Read first**: `plans/INTELLIGENCE-NORTH-STAR.md`. Relevant constraint: the
> backend runs **no ML model in the request path**. Ingredient parsing here is
> deterministic Go (rules, not a model); canonical resolution is **SQL alias
> matching** (not a model); the optional semantic tier runs **on-device** (reuses
> plan 028). An ML ingredient-NER parser is explicitly deferred (see Out of scope).
>
> **Drift check (run first)**:
> `git diff --stat 6c0df971..HEAD -- backend/internal/services/recipe_scraping_service.go backend/internal/api/handlers/recipe.go backend/internal/repositories/grocery_repo.go`
> On a mismatch with the excerpts below, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED (touches the recipe→list path; guard with tests)
- **Depends on**: none for tiers 1–2; the optional semantic tier-3 depends on 028
- **Category**: direction (feature) / tech-debt (the regex parser)
- **Planned at**: commit `6c0df971`, 2026-06-13

## Why this matters

Recipes are scraped into `RecipeClipIngredient{RawText, Name, Quantity, Unit}`
where `Name` is **raw scraped text** ("all-purpose flour" / "Mehl" / "harina") —
no link to the canonical grocery catalog. So "add recipe to list"
(`AddToList`/`AddMissingToList`) creates list items that don't dedupe across
recipes, can't be aisle-sorted, and don't unify across languages. The scraper is
already multilingual (it keys on `zutat`, `ingrédient`, `składnik`), so the
multilingual canonical catalog is exactly what's missing.

This plan (1) improves the ingredient **parser** (currently a single regex) and
(2) **resolves** each ingredient to a `canonical_item_id` via the catalog already
in Postgres, so recipe-sourced list items are clean, deduped, and aisle-sortable —
the payoff being a recipe in any language → a tidy, store-ordered shopping list.

## Current state

- `backend/internal/services/recipe_scraping_service.go`:
  - `RecipeClipIngredient` (line ~31): `{RawText, Name string; Quantity float64; Unit string}`.
  - `ParseIngredient(raw string) RecipeClipIngredient` (line ~1382): one regex
    (`ingredientPartsRe`) splits qty/unit/name; falls back to the whole string as
    `Name`. No canonical resolution. Excerpt:
    ```go
    matches := ingredientPartsRe.FindStringSubmatch(work)
    if len(matches) == 4 { /* qty, unit, name */ }
    if result.Name == "" { result.Name = work }
    return result
    ```
- `backend/internal/repositories/grocery_repo.go` — canonical store: queries over
  `canonical_items` and `item_aliases` (group-scoped + `__global__`), version
  tracking via `grocery_versions`. This is where an alias-resolution query goes.
- `backend/internal/api/handlers/recipe.go` — `AddToList` (line ~363) and
  `AddMissingToList` (line ~447) turn a saved recipe's ingredients into list
  items. These are where resolution must populate `canonical_item_id`.
- `backend/internal/services/grocery_service.go` — existing grocery service;
  add the resolver method here.
- For reference, the **Dart** resolver behavior to mirror:
  `frontend/lib/services/scan/canonical_resolver_service.dart` — exact normalized
  alias → fuzzy → (026 classifier). Keep the Go tier-1 = exact normalized alias
  match so the two stay behaviorally aligned (the seed is the shared contract).

Conventions: services in `backend/internal/services/`, repos in
`backend/internal/repositories/`; errors wrapped with `fmt.Errorf("...: %w", err)`;
tests are table-driven `*_test.go` next to the code. `gofmt` clean required.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Build | `cd backend && go build ./...` | exit 0 |
| Test | `cd backend && go test ./...` | PASS |
| Format check | `cd backend && gofmt -l internal/` | no files listed (touched files clean) |
| Targeted test | `cd backend && go test ./internal/services/ -run Ingredient` | PASS |

## Scope

**In scope:**
- `backend/internal/services/recipe_scraping_service.go` — improve `ParseIngredient`; add `CanonicalItemID *string` to `RecipeClipIngredient`.
- `backend/internal/repositories/grocery_repo.go` — add an exact-alias resolution query.
- `backend/internal/services/grocery_service.go` — `ResolveIngredientName` method.
- `backend/internal/api/handlers/recipe.go` — populate `canonical_item_id` in `AddToList`/`AddMissingToList`.
- Corresponding `*_test.go` files.

**Out of scope (do NOT touch):**
- **An ML ingredient-NER parser** (e.g. the Python `ingredient-parser`): it's a
  model and would run per-request on the backend → violates the north-star law.
  Improve the Go rules instead. If ever wanted, it must run as a build-time/batch
  enrichment or a self-host opt-in — a separate plan, not here.
- The on-device app code (the optional semantic tier-3 reuses 028's
  `StaticEmbeddingService` client-side and is a documented follow-on, not built here).
- The scraping/extraction tiers (JSON-LD/microdata/heuristics) — unchanged.

## Git workflow

- Branch: `advisor/029-recipe-canonical-shopping`
- Conventional commits per unit (parser; resolver repo+service; handler wiring).
- Do NOT push.

## Steps

### Step 1: Strengthen `ParseIngredient` (deterministic, multilingual)

Improve the parser without adding a model:
- Expand unit recognition to DE/EN/FR/ES units + abbreviations (g, kg, ml, l, EL,
  TL, Stück, cuillère, cucharada, taza, etc.) via a lookup set, not just the
  current regex group.
- Strip parenthetical notes and trailing prep ("chopped", "gehackt", "haché") from
  `Name` into nothing (drop), keeping `Name` the bare ingredient.
- Keep `RawText` verbatim; keep range handling (lower bound) as today.

Keep the function pure and total (never panics; empty in → empty out).

**Verify**: add table-driven cases (below) then `cd backend && go test ./internal/services/ -run Ingredient` → PASS.

### Step 2: Add an exact-alias resolution query

In `grocery_repo.go`, add
`ResolveAlias(ctx, groupID uuid.UUID, aliasText string) (canonicalItemID uuid.UUID, found bool, err error)`:
SQL `SELECT canonical_item_id FROM item_aliases WHERE (group_id = $1 OR group_id IS NULL/global) AND alias_text = $2 AND deleted_at IS NULL ORDER BY weight DESC LIMIT 1`
(match the existing global-scope convention used elsewhere in this repo). Normalize
`aliasText` the same way the Dart resolver does (lowercase, trim, collapse spaces)
before the query.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 3: `ResolveIngredientName` service method

In `grocery_service.go`, add
`ResolveIngredientName(ctx, groupID uuid.UUID, name string) (*uuid.UUID, error)`:
normalize `name`, call `ResolveAlias`; return the ID when found, `nil` when not
(best-effort — unresolved ingredients still get added as free-text items).

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 4: Populate `canonical_item_id` in AddToList / AddMissingToList

In `recipe.go`, when constructing list items from recipe ingredients, call
`ResolveIngredientName` for each and set the list item's `canonical_item_id` when
resolved. This makes recipe-sourced items dedupe + aisle-sort like scanned/typed
ones. Do not fail the whole request if one ingredient doesn't resolve.

Also add `CanonicalItemID *string` to `RecipeClipIngredient` (JSON
`canonical_item_id,omitempty`) and set it in the scrape path (best-effort, via the
same service) so the clip preview can show resolution too.

**Verify**: `cd backend && go test ./internal/api/handlers/ -run AddToList` and `-run AddMissing` → PASS.

### Step 5: Tests

- `recipe_scraping_service_test.go`: table-driven `ParseIngredient` cases across
  DE/EN/FR/ES — "200 g Mehl" → {qty 200, unit g, name "Mehl"}; "1 cup
  all-purpose flour, sifted" → {1, cup, "all-purpose flour"}; "2 cucharadas de
  aceite" → {2, cucharada(s), "aceite"}; bare "Salz" → {name "Salz"}.
- `grocery_repo`/`grocery_service` test: seed a canonical item + alias, assert
  `ResolveIngredientName` returns its ID for the alias and `nil` for an unknown.
- `recipe.go` handler test: extend the existing `TestRecipe_AddToList` to assert
  the created list items carry `canonical_item_id` when the ingredient matches a
  seeded alias.

**Verify**: `cd backend && go test ./...` → PASS.

## Done criteria

- [ ] `cd backend && go build ./...` exits 0
- [ ] `cd backend && go test ./...` → PASS (new parser + resolver + handler tests included)
- [ ] `cd backend && gofmt -l internal/services internal/repositories internal/api/handlers` lists none of the touched files
- [ ] `RecipeClipIngredient` has `CanonicalItemID *string`; AddToList/AddMissingToList set it best-effort
- [ ] North-star gate: no ML model added to the request path; resolution is SQL alias matching only
- [ ] No files outside the in-scope list modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Drift check shows the cited functions moved/changed and the excerpts no longer match.
- The list-item creation path in `AddToList` doesn't expose a `canonical_item_id`
  field to set (schema gap) — STOP and report; don't invent a migration here.
- `go test ./...` has pre-existing failures unrelated to this change — report the
  baseline before proceeding.

## Maintenance / follow-on

- **Semantic tier-3 (depends on 028):** ingredients the exact-alias step misses
  ("scallions"→spring onion, "Koriander"→cilantro) resolve **on-device** when the
  user reviews the recipe, via 028's `StaticEmbeddingService.nearest`. Add this
  once 028 ships the embedder bundle; keep it client-side to honor the north star.
- Keep the Go tier-1 normalization byte-aligned with the Dart resolver's
  `_normalise` so both resolve identically.
- A future build-time batch could pre-resolve popular recipes' ingredients, but
  never a per-request ML parser on the backend.
