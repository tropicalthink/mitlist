# Plan 014: Harden the grocery endpoints — transactions, re-correction, pagination, validation

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- backend/internal/repositories/grocery_repo.go backend/internal/services/grocery_service.go backend/internal/api/handlers/grocery.go`
> Plans 001 and 005 intentionally touch these files first — diffs from those plans are expected; verify their changes are present (Plan 001's `current_version` SQL) rather than treating them as drift. Any OTHER divergence from the excerpts below is a STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/001-fix-grocery-sync-spine.md (integration test harness + working endpoints)
- **Category**: bug / security
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Four hardening gaps in the grocery write/read paths, each small, all in the same three files: (1) multi-statement writes run without a transaction, so a failure mid-sequence bumps the household version counter with no row at that version, or records a correction whose alias never materialised; (2) `UpsertAlias`'s conflict clause never updates `canonical_item_id`, so **re-correcting a word to a different item is silently ignored server-side** — the old mapping just gets heavier; (3) `GetDelta` has no pagination — `since_version=0` streams every row of six tables in one response; (4) request validation is thin (no length caps, enum values reach CHECK constraints and surface as raw 500s, aisle batches are unbounded).

## Current state

- Transactions: the repo already holds a `DBTX` that can begin one — `backend/internal/repositories/dbtx.go:12-17`:

```go
type DBTX interface {
	QueryRow(...) pgx.Row
	Query(...) (pgx.Rows, error)
	Exec(...) (pgconn.CommandTag, error)
	Begin(ctx context.Context) (pgx.Tx, error)
}
```

but `grocery_service.go:83-125` (`RecordCorrection`) calls `NextVersion` → `InsertCorrection` → `UpsertAlias` as three pool-level statements, and `UpdateAisles` (`:134-151`) does `NextVersion` → `UpsertAislesBatch`. Note `pgx.Tx` itself satisfies the three query methods — the repo methods can run on a tx if they receive one.

- Re-correction bug — `grocery_repo.go:321-339` (`UpsertAlias`):

```go
		ON CONFLICT (group_id, alias_text) DO UPDATE
			SET weight    = item_aliases.weight + 1,
			    version   = EXCLUDED.version,
			    updated_at = EXCLUDED.updated_at`
```

Missing: `canonical_item_id = EXCLUDED.canonical_item_id` (and arguably `source`/`lang`). Without it, correcting "melk" from item A to item B leaves the row pointing at A with weight+1.

- Pagination — `grocery_repo.go:56-224` (`GetDelta`): six per-table queries, `WHERE ... version > $2 ORDER BY version`, no `LIMIT` anywhere (verified: one `LIMIT` in the whole file, in `ResolveAlias`).

- Validation — `backend/internal/api/handlers/grocery.go:97-112`: only `raw_text != ""`; `UpdateAisles` (`:57-82`) decodes an unbounded `aisles` array with no field checks. The migration's CHECK constraints (`kind IN ('alias','reject',...)` etc. — read `backend/migrations/000027_add_grocery_graph.up.sql:57-76` for the exact lists) become raw DB errors today. Existing validation convention: `api.ValidationError{Field:, Message:}` (used at `grocery.go:104`).

- Integration test harness: `backend/internal/api/handlers/grocery_integration_test.go` exists after Plan 001 — extend it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Unit | `cd backend && go test ./internal/repositories/ ./internal/services/` | pass |
| Integration | `cd backend && go test ./internal/api/handlers/ -run TestGrocery -v` | PASS, no SKIP (docker compose up -d first) |

## Scope

**In scope**:
- `backend/internal/repositories/grocery_repo.go`
- `backend/internal/services/grocery_service.go`
- `backend/internal/api/handlers/grocery.go`
- `backend/internal/api/handlers/grocery_integration_test.go`
- `backend/internal/repositories/grocery_repo_test.go`, `backend/internal/services/grocery_service_test.go` (mock updates)
- `frontend/lib/repositories/grocery_repository.dart` — **only** the delta-pagination loop in Step 3's client half

**Out of scope**:
- Canonical-id bridging (Plan 005), SSE (Plan 008), purchase-history sync (Plan 018 spike).
- Changing CHECK constraints or migrations.

## Git workflow

- Branch: `advisor/014-backend-grocery-hardening`
- Commit per step; style: `fix(grocery): transactional correction writes` etc.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Transactional writes

Give the repo a tx runner and route the two multi-write services through it:

```go
// WithTx runs fn with a repository bound to a single transaction.
func (r *GroceryRepository) WithTx(ctx context.Context, fn func(txRepo *GroceryRepository) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // rollback after commit is a no-op
	if err := fn(&GroceryRepository{pool: tx}); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
```

(`pgx.Tx` provides `QueryRow/Query/Exec/Begin`, so it satisfies `DBTX`.) In `RecordCorrection` and `UpdateAisles`, wrap the `NextVersion` → write(s) sequence in `s.repo.WithTx(ctx, func(txRepo ...) { ... })`, keeping `requireMembership` and the SSE publish outside the tx (publish only after commit succeeds). Update pgxmock tests: pgxmock supports `ExpectBegin`/`ExpectCommit`.

**Verify**: `go build ./... && go test ./internal/services/ ./internal/repositories/` → pass

### Step 2: Fix re-correction in `UpsertAlias`

Add to the conflict clause:

```sql
			SET canonical_item_id = EXCLUDED.canonical_item_id,
			    weight    = item_aliases.weight + 1,
			    ...
```

Integration test (extend `grocery_integration_test.go`): correct "melk" → item A (POST), then → item B (POST); GET the delta and assert the single `item_aliases` row for "melk" now has `canonical_item_id == B` and weight 2.

**Verify**: `go test ./internal/api/handlers/ -run TestGrocery -v` → PASS

### Step 3: Paginate `GetDelta`

Server: add a per-table `LIMIT` (constant, e.g. `deltaPageLimit = 500`, declared once) to all six queries, and compute the response's `max_version` as **the highest version actually included** when any table hit its limit (so the client's next `since_version` re-enters where it left off), else the true `CurrentVersion`. Concretely: track `truncated bool` + `maxSeen int64` while scanning; in `GetGraphDelta` use `if truncated { delta.MaxVersion = maxSeen } else { delta.MaxVersion = currentVersion }`. Add `"has_more": truncated` to the delta struct (`models/grocery.go` — new bool field, `json:"has_more"`).

Client (`frontend/lib/repositories/grocery_repository.dart:69-83`): loop `pullDelta` while `has_more == true` (bounded: max 20 iterations, then log a warning), advancing from the freshly stored cursor each round.

Integration test: insert >LIMIT alias rows across versions (loop the corrections POST with distinct raw_texts, or insert directly via SQL for speed), then GET with `since_version=0` and assert `has_more=true`, and that iterating the cursor drains to `has_more=false` with all rows seen exactly once.

**Verify**: `go test ./internal/api/handlers/ -run TestGrocery -v` → PASS; `cd frontend && dart analyze lib/` → exit 0

### Step 4: Input validation at the handler

In `grocery.go`, before calling the service:

- `RecordCorrection`: `raw_text` length ≤ 200 (matches alias-text practical bounds); `kind` ∈ the migration's CHECK list; `scope` ∈ its list; `lang` length ≤ 8. Respond `api.ValidationError` per field, matching line 104's style.
- `UpdateAisles`: `len(req.Aisles) ≤ 200` (a review screen sends at most a receipt's worth); per entry: `aisle` length ≤ 64, `sort_order` in [0, 100000]. Reject the whole batch on first violation with the index in the message.

Read the exact CHECK lists from the migration before hardcoding them, and add a comment naming the migration file as the source.

Integration test: one over-length `raw_text` → 400 with the field name; oversized aisle batch → 400.

**Verify**: `go test ./internal/api/handlers/ -run TestGrocery -v` → PASS; `go vet ./...` → exit 0

## Test plan

Each step carries its own integration case (re-correction, pagination drain, validation 400s) plus mock-level updates for the tx wrapping. Full gate: the three backend packages + handler integration all green.

## Done criteria

- [ ] `grep -n "WithTx" backend/internal/services/grocery_service.go` → both write paths wrapped
- [ ] `grep -n "canonical_item_id = EXCLUDED" backend/internal/repositories/grocery_repo.go` → present
- [ ] `grep -c "LIMIT" backend/internal/repositories/grocery_repo.go` → ≥ 7 (six delta queries + ResolveAlias)
- [ ] `has_more` in `models/grocery.go` and consumed in `grocery_repository.dart`
- [ ] `cd backend && go build ./... && go vet ./...` exit 0; the three test packages pass; integration PASS without SKIP
- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 001 is not DONE (integration harness missing).
- `pgx.Tx` fails to satisfy `DBTX` in this pgx version (compile error at `&GroceryRepository{pool: tx}`) — report the interface mismatch; do not fork the repo struct.
- The pagination change breaks the frontend's `maxVersion == 0` early-return contract (`grocery_repository.dart:86-87`) in a way the loop can't absorb — report; the semantics "0 means nothing" must be preserved for empty groups.
- pgxmock cannot express the tx expectations for an existing test — report which test.

## Maintenance notes

- The `has_more`/cursor contract is now load-bearing for the client loop; document it in the handler comment.
- Plan 005's on-demand canonical upsert must run **inside** the same `WithTx` when both land — whoever merges second checks that.
- Reviewer should scrutinize: SSE publish stays post-commit; `max_version` under truncation is the highest *included* version (off-by-one here silently drops rows).
