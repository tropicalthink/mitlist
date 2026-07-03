# Plan 001: Make the backend grocery sync endpoints actually work

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- backend/internal/repositories/grocery_repo.go backend/internal/repositories/grocery_repo_test.go backend/internal/api/handlers/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The grocery graph sync API (`GET /groups/{id}/grocery/graph`, `POST .../corrections`, `PATCH .../aisles`) has **never worked in production**. The SQL in the repository references a column named `version` on the `grocery_versions` table, but the migration created that column as `current_version`. Every write endpoint 500s at the version bump, and the read path swallows the SQL error into `MaxVersion=0` — which the Flutter client interprets as "nothing to apply", silently discarding every delta it fetched. Corrections, alias sync, and aisle feedback across household devices are all dead because of these two functions. No test caught this because the only grocery tests are pgxmock-based (they assert against the same wrong SQL string) — so this plan also adds a real-schema integration test to keep it fixed.

## Current state

- `backend/internal/repositories/grocery_repo.go` — the grocery graph repository. The two broken functions (lines 28–49):

```go
// NextVersion increments and returns the per-household monotonic version counter.
func (r *GroceryRepository) NextVersion(ctx context.Context, groupID uuid.UUID) (int64, error) {
	query := `
		INSERT INTO grocery_versions (group_id, version)
		VALUES ($1, 1)
		ON CONFLICT (group_id) DO UPDATE
			SET version = grocery_versions.version + 1
		RETURNING version`
	var v int64
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&v)
	return v, err
}

// CurrentVersion returns the current version for a group (0 if none yet).
func (r *GroceryRepository) CurrentVersion(ctx context.Context, groupID uuid.UUID) (int64, error) {
	query := `SELECT COALESCE(version, 0) FROM grocery_versions WHERE group_id = $1`
	var v int64
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&v)
	if err != nil {
		return 0, nil // no row → version 0
	}
	return v, nil
}
```

- `backend/migrations/000027_add_grocery_graph.up.sql:14-18` — the actual schema:

```sql
CREATE TABLE grocery_versions (
    group_id        UUID        PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    current_version BIGINT      NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

The column is `current_version`; the queries use `version`. There is no later migration renaming either.

- `CurrentVersion` also swallows **all** errors (`return 0, nil`), not just no-rows. The comment claims "no row → version 0" but the code makes every DB failure look like an empty graph. The service consumes it at `backend/internal/services/grocery_service.go:43-47` and stamps `delta.MaxVersion`; the Flutter client at `frontend/lib/repositories/grocery_repository.dart:86-87` early-returns when `max_version == 0`, discarding the delta and never advancing its cursor.

- `backend/internal/repositories/grocery_repo_test.go` — pgxmock unit tests. Any test expecting the old SQL strings must be updated to the corrected SQL.

- `backend/internal/api/handlers/setup_test.go` — a real-Postgres integration harness: `TestMain` connects to `TEST_DATABASE_URL` (default `postgres://mitlist:mitlist@localhost:5432/mitlist_test?sslmode=disable`), runs all migrations, and **skips cleanly if the DB is unavailable**. Helpers: `createTestUser(t, email, password)` (line 216), `buildRequest`/`execRequest` (lines 292-311), `testAuthMiddleware` (line 251), `clearTables(t)` (line 152 — already lists the grocery tables including `grocery_versions`).

- `backend/internal/api/handlers/recipe_test.go:390-402` — the exemplar for seeding grocery fixtures directly:

```go
// so that group must exist before seeding canonical_items / item_aliases.
...
	INSERT INTO canonical_items (id, group_id, name_de, name_en, category, default_unit, is_global, version, created_at, updated_at)
```

- Route registration: `backend/internal/api/handlers/grocery.go:25-29` mounts `GET /groups/{groupID}/grocery/graph`, `POST /groups/{groupID}/grocery/corrections`, `PATCH /groups/{groupID}/grocery/aisles`. The service is `backend/internal/services/grocery_service.go` (`GetGraphDelta`, `RecordCorrection`, `UpdateAisles` — all call `requireMembership` first).

- **Foreign-key caveat you must respect in the test**: `item_aliases.canonical_item_id` and `corrections.resolved_canonical_item_id` are FK-constrained to `canonical_items(id)` (migration lines 44 and 69). The server never seeds `canonical_items`, so your integration test must INSERT a `canonical_items` row itself (as `recipe_test.go` does) before posting a correction that references it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Compile | `cd backend && go build ./...` | exit 0 |
| Start test DB | `cd backend && docker compose up -d` | postgres:16 + redis running |
| Create test DB (first time) | `docker exec -i $(docker ps -qf name=postgres) psql -U mitlist -c "CREATE DATABASE mitlist_test"` | `CREATE DATABASE` (or "already exists" error — fine) |
| Unit tests | `cd backend && go test ./internal/repositories/ -run TestGrocery -v` | PASS |
| Integration tests | `cd backend && go test ./internal/api/handlers/ -run TestGrocery -v` | PASS (not skipped) |

Note: if the handlers test output says `SKIP: test database unavailable`, the DB is not running — that is not a pass. Start docker compose and re-run.

## Scope

**In scope** (the only files you should modify):
- `backend/internal/repositories/grocery_repo.go`
- `backend/internal/repositories/grocery_repo_test.go` (update mock SQL expectations)
- `backend/internal/api/handlers/grocery_integration_test.go` (create)

**Out of scope** (do NOT touch, even though they look related):
- `backend/migrations/*` — do NOT rename the column in a migration; the schema (`current_version`) is the source of truth, the Go code is what's wrong. Deployed databases already have `current_version`.
- `backend/internal/services/grocery_service.go` — transactions/validation are Plan 014.
- Any frontend file — the client-side upload guard is Plan 005.
- `GetDelta` pagination — Plan 014.

## Git workflow

- Branch: `advisor/001-fix-grocery-sync-spine`
- Commit style: conventional commits, e.g. `fix(grocery): align version queries with grocery_versions schema` (matches repo history, e.g. `fix(lists): preserve order of restored pending offline items`)
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the two SQL queries in `grocery_repo.go`

In `NextVersion`, replace the query with:

```go
	query := `
		INSERT INTO grocery_versions (group_id, current_version)
		VALUES ($1, 1)
		ON CONFLICT (group_id) DO UPDATE
			SET current_version = grocery_versions.current_version + 1,
			    updated_at = now()
		RETURNING current_version`
```

In `CurrentVersion`, replace the query and the error handling so only a missing row maps to 0:

```go
	query := `SELECT current_version FROM grocery_versions WHERE group_id = $1`
	var v int64
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&v)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return v, nil
```

Add the `errors` and `github.com/jackc/pgx/v5` imports if not already present in the file.

**Verify**: `cd backend && go build ./...` → exit 0

### Step 2: Update pgxmock expectations

Open `backend/internal/repositories/grocery_repo_test.go`. Any `ExpectQuery`/`ExpectExec` matching the old `version` SQL must be updated to the new `current_version` SQL. If no test touches `NextVersion`/`CurrentVersion`, add unit tests for both: happy path (row exists → value returned), no-row (`pgx.ErrNoRows` → `0, nil`), and DB error (→ error propagated, not swallowed).

**Verify**: `cd backend && go test ./internal/repositories/ -v` → PASS

### Step 3: Add the real-schema integration test

Create `backend/internal/api/handlers/grocery_integration_test.go`. Model the setup on `recipe_test.go` (user + group + membership fixtures, direct `canonical_items` INSERT) and use `execRequest` from `setup_test.go`. Cover this round-trip:

1. `clearTables(t)`; create a user, a group, a membership; INSERT one `canonical_items` row (a fixed UUID, `group_id` = the test group, `is_global=false`).
2. `GET /groups/{gid}/grocery/graph?since_version=0` → 200, `max_version == 0`, all arrays empty.
3. `POST /groups/{gid}/grocery/corrections` with `{"raw_text":"vollmilch","kind":"alias","canonical_item_id":"<the seeded UUID>","lang":"de"}` → 200, body `{"version": 1}`.
4. `GET .../graph?since_version=0` → 200, `max_version == 1`, `corrections` has 1 row, `item_aliases` has 1 row with `alias_text == "vollmilch"` (the service lowercases/trims).
5. `GET .../graph?since_version=1` → 200, `max_version == 1`, `corrections` and `item_aliases` empty (cursor semantics).
6. `PATCH /groups/{gid}/grocery/aisles` with one entry `{"aisles":[{"canonical_item_id":"<UUID>","aisle":"dairy","sort_order":3}]}` → 200, `{"version": 2}`.
7. Negative auth case: a second user NOT in the group gets 403/404 (whatever `requireGroupMember` returns — assert the non-200 the other handler tests assert for non-members; check `recipe_test.go` for the exact expected status).

**Verify**: `cd backend && go test ./internal/api/handlers/ -run TestGrocery -v` → PASS, and the output must NOT contain `SKIP`

### Step 4: Full backend verification

**Verify**: `cd backend && go build ./... && go test ./internal/repositories/ ./internal/services/ ./internal/api/handlers/` → exit 0 (AGENTS.md notes some pre-existing failures elsewhere in `go test ./...`; the three packages above must pass)

## Test plan

- Unit: `NextVersion` first-call (insert path → 1), increment path (→ N+1); `CurrentVersion` row/no-row/error cases — in `grocery_repo_test.go` with pgxmock.
- Integration: the 7-step round-trip above in `grocery_integration_test.go` — this is the regression gate that would have caught the column mismatch.
- Pattern to follow: `recipe_test.go` for fixtures; `setup_test.go` `execRequest` for HTTP.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./...` exits 0
- [ ] `grep -n '"version"' backend/internal/repositories/grocery_repo.go` shows no SQL referencing a bare `version` column on `grocery_versions` (the `version` columns on other tables in `GetDelta` are correct and unchanged)
- [ ] `go test ./internal/api/handlers/ -run TestGrocery -v` passes without SKIP
- [ ] `go test ./internal/repositories/` passes
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The `grocery_versions` DDL does not say `current_version` (a rename migration landed since planning).
- The integration harness cannot connect to Postgres even after `docker compose up -d` and creating `mitlist_test`.
- The corrections POST in step 3.3 fails with a foreign-key violation **even though** you seeded the `canonical_items` row — that means the FK/ID model shifted and Plan 005's scope is bleeding into this one.
- Fixing the tests requires changing `grocery_service.go` behavior (not just SQL strings).

## Maintenance notes

- Plan 014 (transactions + pagination + validation) builds directly on this; its tests extend `grocery_integration_test.go`.
- Plan 005 changes what canonical ids the client sends; the integration test's seeded-UUID approach stays valid either way.
- Reviewer should scrutinize: that `CurrentVersion` now propagates real errors — callers in `grocery_service.go` already handle an error return, so no service change is needed.
- Deferred: the `updated_at = now()` addition to `NextVersion` is a drive-by correctness nicety; if it breaks a mock expectation unexpectedly, dropping it is acceptable.
