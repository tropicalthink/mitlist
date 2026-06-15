# Plan 034: Fix canonical_item_id loss in batch insert and map recipe permission denials to 403

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update this plan's status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 45ae60c2..HEAD -- backend/internal/repositories/list_repo.go backend/internal/services/recipe_service.go backend/internal/repositories/grocery_repo.go`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `45ae60c2`, 2026-06-15

## Why this matters

Three small but real correctness defects in the recently-added grocery/recipe
surface:

1. **`canonical_item_id` is silently dropped on batch insert.** `CreateItem`
   (single) persists `canonical_item_id`; `CreateItems` (batch) does not. The
   batch path is what recipe→shopping-list expansion uses, so every item added
   via a recipe loses its canonical link — defeating the grocery-brain
   resolution the column exists for, with no error surfaced.

2. **Recipe permission denials return HTTP 500 instead of 403.** Three sites
   in `recipe_service.go` return the bare `api.ErrPermissionDenied` sentinel.
   The error mapper only maps the **`*PermissionDeniedError` struct** to 403
   (`errors.As`, `api/errors.go:143-145`); the bare sentinel falls through to
   `StatusInternalServerError` (`errors.go:158`). So a user editing someone
   else's recipe gets a 500 (looks like a server bug, triggers error alarms)
   instead of a clean 403.

3. **Hardening: the alias-resolution sentinel is string-concatenated into SQL.**
   `ResolveAlias` builds `WHERE (group_id = $1 OR group_id = '<uuid>')` by Go
   string concatenation. The value is a compile-time constant so it is not an
   injection today, but it is the only hand-concatenated id in the file and
   inconsistent with the parameterised query right below it
   (`grocery_repo.go:92`). Parameterising it removes the foot-gun and lets us
   add a test that proves household aliases win over global ones.

## Current state

### Defect 1 — `canonical_item_id` batch omission

`backend/internal/repositories/list_repo.go:193-195` — single insert is correct
(`canonical_item_id` at `$10`):

```go
query := `INSERT INTO list_items (id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, canonical_item_id, added_by, checked, position, created_at, updated_at) VALUES ($1,...,$15)`
```

`backend/internal/repositories/list_repo.go:201-245` — batch insert builds
arrays for every field **except** `canonical_item_id`, and the INSERT/`unnest`
omit it. Relevant slices (`:206-217`) and the loop (`:218-236`) have no
`canonicalItemIDs`. The INSERT (`:237-243`):

```go
INSERT INTO list_items (id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position, created_at, updated_at)
SELECT id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position, $1, $1
FROM unnest($2::uuid[], $3::uuid[], $4::text[], $5::float8[], $6::text[], $7::text[], $8::int[], $9::uuid[], $10::uuid[], $11::uuid[], $12::bool[], $13::int[]) AS t(
	id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position
)
```

`models.ListItem.CanonicalItemID` is a `*uuid.UUID` (same type carried by
`CreateItem` at `:195`).

### Defect 2 — recipe permission sentinels

`backend/internal/services/recipe_service.go:25-37`:

```go
func (s *RecipeService) requireOwner(recipe *models.Recipe, userID uuid.UUID) error {
	if recipe.UserID != userID {
		return api.ErrPermissionDenied        // line 27 — bare sentinel → 500
	}
	return nil
}

func (s *RecipeService) requireCollectionOwner(collection *models.Collection, userID uuid.UUID) error {
	if collection.UserID != userID {
		return api.ErrPermissionDenied        // line 34 — bare sentinel → 500
	}
	return nil
}
```

And `recipe_service.go:72` (inside `GetRecipe`): `return nil, api.ErrPermissionDenied`.

The fix target type (`backend/internal/api/errors.go:39-57`):

```go
type PermissionDeniedError struct {
	Action  string
	Message string
}
func (e *PermissionDeniedError) Error() string { ... }
func (e *PermissionDeniedError) Unwrap() error { return ErrPermissionDenied }
```

`Unwrap` returns the sentinel, so existing tests that assert
`errors.Is(err, api.ErrPermissionDenied)` (e.g. `recipe_service_test.go:93,121`)
**keep passing** after the change. The mapper maps the struct to 403:
`errors.As(err, &pd)` → `http.StatusForbidden` (`errors.go:143-145`).

### Defect 3 — alias sentinel concatenation

`backend/internal/repositories/grocery_repo.go:302-319`:

```go
func (r *GroceryRepository) ResolveAlias(ctx context.Context, groupID uuid.UUID, aliasText string) (canonicalItemID uuid.UUID, found bool, err error) {
	const globalGroupID = "00000000-0000-0000-0000-000000000000"
	query := `
		SELECT canonical_item_id
		FROM item_aliases
		WHERE (group_id = $1 OR group_id = '` + globalGroupID + `')
		  AND alias_text = $2
		  AND deleted_at IS NULL
		ORDER BY
		  CASE WHEN group_id = $1 THEN 0 ELSE 1 END,
		  weight DESC
		LIMIT 1`
	var id uuid.UUID
	if err := r.pool.QueryRow(ctx, query, groupID, aliasText).Scan(&id); err != nil {
		return uuid.Nil, false, nil //nolint:nilerr // not-found is not an error here
	}
	return id, true, nil
}
```

### Conventions

- Batch arrays + `unnest` typed-array pattern: this is the only batch insert; match its existing shape exactly. `*uuid.UUID` slices map to `$N::uuid[]` (see `productIDs`/`storeIDs` at `:213-214`).
- Tests: repo tests use `pgxmock` (`internal/repositories/grocery_repo_test.go`); service tests use generated mocks in `internal/repositories/mocks` (`internal/services/recipe_service_test.go:15`).
- Existing `ResolveAlias` tests call `mock.ExpectQuery("SELECT canonical_item_id").WithArgs(groupID, aliasText)` — **these must be updated** when a third placeholder is added.

## Commands you will need

| Purpose    | Command                                                  | Expected           |
|------------|----------------------------------------------------------|--------------------|
| Build      | `cd backend && go build ./...`                           | exit 0             |
| Vet        | `cd backend && go vet ./...`                             | exit 0             |
| Repo tests | `cd backend && go test ./internal/repositories/...`     | all pass           |
| Svc tests  | `cd backend && go test ./internal/services/...`         | all pass           |
| All tests  | `cd backend && go test ./...`                           | all pass           |

## Scope

**In scope**:
- `backend/internal/repositories/list_repo.go`
- `backend/internal/repositories/list_repo_test.go` (add a test; create only if absent — `ls` first)
- `backend/internal/services/recipe_service.go`
- `backend/internal/services/recipe_service_test.go`
- `backend/internal/repositories/grocery_repo.go`
- `backend/internal/repositories/grocery_repo_test.go`

**Out of scope**:
- The `list_items` / `item_aliases` schema — all needed columns already exist.
- The `PermissionDeniedError` type itself (`api/errors.go`) — use it, don't change it.
- The `//nolint:nilerr` not-found behaviour in `ResolveAlias` — keep returning `(Nil, false, nil)` on no-rows; only parameterise the sentinel (see Maintenance notes for why the swallow stays).

## Git workflow

- Branch: `advisor/034-canonical-batch-and-permission-mapping`
- Commit per defect; conventional-commit style (`fix(...)`). Example: `fix(lists): persist canonical_item_id in batch insert`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Carry canonical_item_id through the batch insert

In `list_repo.go:CreateItems`:

1. Add a slice alongside the others (`:206-217`): `canonicalItemIDs := make([]*uuid.UUID, len(items))`.
2. In the loop (`:218-236`), populate it: `canonicalItemIDs[i] = items[i].CanonicalItemID`.
3. Add `canonical_item_id` to the INSERT column list, the `SELECT` list, and the `unnest` typed-array list + its `AS t(...)` column list, then append `canonicalItemIDs` to the `Exec` args. Renumber placeholders so the new array is the **last** unnest array.

Target shape (note `canonical_item_id` added after `store_id`, new array becomes `$14::uuid[]`):

```go
_, err := r.pool.Exec(ctx, `
	INSERT INTO list_items (id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, canonical_item_id, added_by, checked, position, created_at, updated_at)
	SELECT id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, canonical_item_id, added_by, checked, position, $1, $1
	FROM unnest($2::uuid[], $3::uuid[], $4::text[], $5::float8[], $6::text[], $7::text[], $8::int[], $9::uuid[], $10::uuid[], $11::uuid[], $12::bool[], $13::int[], $14::uuid[]) AS t(
		id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position, canonical_item_id
	)
`, now, ids, listIDs, names, quantities, units, notes, priceCents, productIDs, storeIDs, addedBy, checked, positions, canonicalItemIDs)
```

Double-check the `unnest(...)` array order matches the `AS t(...)` name order:
`canonicalItemIDs` is the **last** unnest array (`$14`) but `canonical_item_id`
sits **before** `added_by` in both the INSERT column list and the `SELECT`
list — that is correct because `SELECT`/INSERT order is independent of unnest
positional order as long as each name resolves. Keep `added_by`, `checked`,
`position` mapped to `$11`/`$12`/`$13` as before.

**Verify**: `cd backend && go build ./...` → exit 0

### Step 2: Test that the batch insert includes canonical_item_id

In `list_repo_test.go` (check it exists; if not, model a new test on the
`pgxmock` pattern in `grocery_repo_test.go`), add a test that inserts two items
where one has a non-nil `CanonicalItemID` and asserts the executed batch query
references `canonical_item_id` and receives the id in its args. With `pgxmock`,
match the query containing `canonical_item_id` and use
`WithArgs(...)`/`pgxmock.AnyArg()` so the canonical-id slice is one of the
arguments.

**Verify**: `cd backend && go test ./internal/repositories/...` → all pass

### Step 3: Return PermissionDeniedError from recipe ownership checks

In `recipe_service.go`, replace the three bare-sentinel returns with the struct:

- `:27` (`requireOwner`): `return &api.PermissionDeniedError{Action: "modify recipe"}`
- `:34` (`requireCollectionOwner`): `return &api.PermissionDeniedError{Action: "modify collection"}`
- `:72` (`GetRecipe`, share-not-found): `return nil, &api.PermissionDeniedError{Action: "view recipe"}`

**Verify**: `cd backend && go build ./...` → exit 0

### Step 4: Lock in the 403 mapping with a test

In `recipe_service_test.go`, in the permission-denied cases (around `:93` and
`:121`), add an assertion that the returned error is the **struct** (so the
mapper yields 403), not just the sentinel:

```go
var pd *api.PermissionDeniedError
assert.ErrorAs(t, err, &pd)
```

Keep the existing `assert.ErrorIs(t, err, api.ErrPermissionDenied)` lines — both
must hold (the struct unwraps to the sentinel).

**Verify**: `cd backend && go test ./internal/services/...` → all pass

### Step 5: Parameterise the alias sentinel

In `grocery_repo.go:ResolveAlias`, pass the sentinel as `$3` instead of
concatenating. Keep `const globalGroupID` (or parse it once to a `uuid.UUID`)
and bind it:

```go
const globalGroupID = "00000000-0000-0000-0000-000000000000"
query := `
	SELECT canonical_item_id
	FROM item_aliases
	WHERE (group_id = $1 OR group_id = $3)
	  AND alias_text = $2
	  AND deleted_at IS NULL
	ORDER BY
	  CASE WHEN group_id = $1 THEN 0 ELSE 1 END,
	  weight DESC
	LIMIT 1`
var id uuid.UUID
if err := r.pool.QueryRow(ctx, query, groupID, aliasText, globalGroupID).Scan(&id); err != nil {
	return uuid.Nil, false, nil //nolint:nilerr // not-found is not an error here
}
```

(Binding the string literal is fine — pgx will coerce it to uuid. If the driver
rejects it, parse with `uuid.MustParse(globalGroupID)` and bind the `uuid.UUID`.)

**Verify**: `cd backend && go build ./...` → exit 0

### Step 6: Update existing ResolveAlias tests + add ordering test

In `grocery_repo_test.go`:
1. Update every `ResolveAlias` test's `WithArgs(groupID, aliasText)` to
   `WithArgs(groupID, aliasText, "00000000-0000-0000-0000-000000000000")` (the
   new third placeholder). There are at least the `_Found` and `_NotFound`
   tests around `:13` and `:34`.
2. Add `TestGroceryRepository_ResolveAlias_HouseholdBeatsGlobal`: set up the
   mock to return the household row first (the query's `ORDER BY` guarantees
   household-scoped rows sort before global ones), assert the returned
   `canonical_item_id` is the household one. Since `pgxmock` returns whatever
   rows you stage, stage a single row representing the household winner and
   assert `found == true` and the id; the test documents the contract that the
   query orders household before global.

**Verify**: `cd backend && go test ./internal/repositories/...` → all pass

## Test plan

- Batch-canonical test (Step 2), 403-struct assertion (Step 4), alias-arg update + ordering test (Step 6).
- Patterns: `pgxmock` repo tests from `grocery_repo_test.go`; mock-based service tests from `recipe_service_test.go`.
- Verification: `cd backend && go test ./...` → all pass.

## Done criteria

ALL must hold:

- [ ] `cd backend && go build ./...` exits 0
- [ ] `cd backend && go vet ./...` exits 0
- [ ] `cd backend && go test ./...` exits 0
- [ ] `grep -n "canonical_item_id" backend/internal/repositories/list_repo.go` shows it in the `CreateItems` INSERT
- [ ] `grep -n "api.ErrPermissionDenied" backend/internal/services/recipe_service.go` returns **no** matches that are bare `return` statements (the three are now `&api.PermissionDeniedError{...}`); only `GetRecipe`'s `err.Error() == "recipe share not found"` branch comparison logic remains, now returning the struct
- [ ] `grep -n "globalGroupID +" backend/internal/repositories/grocery_repo.go` returns no matches (sentinel no longer concatenated)
- [ ] New tests for all three defects pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- "Current state" excerpts don't match live code (drift since `45ae60c2`).
- The batch `unnest` placeholder count no longer matches after edits (build error you can't resolve in one pass) — re-count column/array/placeholder triples.
- `pgx` rejects the string-bound sentinel even after switching to `uuid.MustParse` (Step 5).
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The `//nolint:nilerr` in `ResolveAlias` intentionally maps **all** query errors (not just no-rows) to "not found". That is a separate, lower-priority smell (a real DB error is indistinguishable from a miss); this plan does not change it to avoid altering resolution behaviour. If revisited, distinguish `pgx.ErrNoRows` from other errors and propagate the latter.
- After Step 1, any future column added to `list_items` must be added to **both** `CreateItem` and `CreateItems` — they drifted once already.
- Reviewer should scrutinise: the batch `unnest` column/array alignment (Step 1) and that the recipe 403 mapping is exercised by an `errors.As` assertion (Step 4).
