# Plan 005: Bound GetFinanceSummary — aggregate balances in SQL

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- backend/internal/services/finance_service.go backend/internal/repositories/finance_repo.go backend/internal/repositories/interfaces.go`
> Plans 001–003 may have touched `finance_service.go` — expected. On any other
> mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (rewrites balance computation — must be behavior-identical)
- **Depends on**: plans/003-money-path-tests.md (characterization tests MUST be green before and after)
- **Category**: perf
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

`GetFinanceSummary` backs the group balance view — likely the most-loaded finance screen. It currently loads **every expense, every split, and every settlement the group has ever recorded** into memory on every request, then folds them into per-user balances in Go. Cost grows linearly with group history forever; a year of household activity means thousands of rows per render, multiplied by each member refreshing. The balances are simple sums — the database can compute them in three aggregate queries returning one row per member.

## Current state

`backend/internal/services/finance_service.go:150–177`:

```go
func (s *FinanceService) GetFinanceSummary(ctx context.Context, userID, groupID uuid.UUID) (*models.FinanceSummary, error) {
    if err := s.requireMember(ctx, groupID, userID); err != nil { return nil, err }

    expenses, err := s.financeRepo.ListAllExpensesByGroup(ctx, groupID)
    ...
    splits, err := s.financeRepo.ListSplitsByGroup(ctx, groupID)
    ...
    settlements, err := s.financeRepo.ListAllSettlementsByGroup(ctx, groupID)
    ...
    profiles, err := s.groupRepo.ListMemberProfilesByGroup(ctx, groupID)
    ...
    balances := calculateBalances(expenses, splits, settlements)
    applyDisplayNames(balances, profiles)
    return &models.FinanceSummary{
        Balances:       balances,
        Reimbursements: suggestReimbursements(balances),
    }, nil
}
```

Unbounded repo queries (`backend/internal/repositories/finance_repo.go`): `ListAllExpensesByGroup` (:83), `ListSplitsByGroup` (:192, JOIN on expenses), `ListAllSettlementsByGroup` (:291). Amounts are `BIGINT` cents (`int64`) — no float math anywhere; keep it that way.

**Before writing SQL, read `calculateBalances` and `suggestReimbursements` in `finance_service.go`** to extract the exact semantics (how unsettled splits, payer credit, and settlements compose). The SQL must replicate them precisely; the characterization tests from plan 003 (`TestCalculateBalances`, `TestFinanceService_GetFinanceSummary`) define the contract.

Repo conventions: pgx pool queries with `pgx.CollectRows(rows, pgx.RowToStructByName[T])`; interfaces declared in `backend/internal/repositories/interfaces.go`; mocks in `repositories/mocks/`. Repo integration tests exist (`finance_repo_test.go`) — follow their DB-setup pattern.

`ListAllExpensesByGroup` is also used by the export endpoints (`ListAllExpenses`, `finance_service.go:142`) — **do not remove or alter it**.

## Commands you will need

| Purpose | Command (run in `backend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Build   | `go build ./...`             | exit 0              |
| Service tests | `go test ./internal/services/...` | all pass    |
| Repo tests | `go test ./internal/repositories/...` | all pass (may need local postgres: `docker compose up -d`) |
| Full suite | `go test ./...`           | all pass            |

## Scope

**In scope**:
- `backend/internal/repositories/finance_repo.go` (add aggregate method)
- `backend/internal/repositories/interfaces.go` + `mocks/`
- `backend/internal/services/finance_service.go` (`GetFinanceSummary` only)
- `backend/internal/repositories/finance_repo_test.go`, `backend/internal/services/finance_service_test.go`

**Out of scope**:
- The `models.FinanceSummary` response shape — clients depend on it; byte-identical JSON.
- `suggestReimbursements`, `applyDisplayNames`, `calculateBalances` (the in-memory helpers stay; tests still use them).
- Export endpoints and their `ListAll*` queries.
- Any caching layer — aggregation makes it unnecessary at current scale.

## Git workflow

- Branch: `perf/finance-summary-aggregate` off `new-main-fr` (after plan 003 merged).
- Conventional commits (`perf: ...`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Pin the contract

Confirm plan 003's tests exist and pass: `go test ./internal/services/... -run "TestCalculateBalances|TestFinanceService_GetFinanceSummary" -v` → pass. If they don't exist, STOP (dependency not met).

### Step 2: Add an aggregate repo method

Add to `FinanceRepo` a method like:

```go
// GetGroupBalanceAggregates returns, per user: total paid (as expense payer),
// total owed (sum of their unsettled splits), settlements sent, settlements received.
func (r *FinanceRepo) GetGroupBalanceAggregates(ctx context.Context, groupID uuid.UUID) ([]models.BalanceAggregate, error)
```

with a `models.BalanceAggregate{UserID uuid.UUID; Paid, Owed, SettledOut, SettledIn int64}` struct (place next to `FinanceSummary` in `models/finance.go` — adding a model type is a permitted incidental edit; note it in the commit). Implement with 3 grouped queries or one query with CTEs, e.g.:

```sql
SELECT u.user_id,
       COALESCE(p.paid, 0)        AS paid,
       COALESCE(o.owed, 0)        AS owed,
       COALESCE(so.sent, 0)       AS settled_out,
       COALESCE(si.received, 0)   AS settled_in
FROM (...) -- derive the exact composition from calculateBalances; do not guess
```

The exact aggregation semantics (settled splits excluded? payer self-split treatment?) **must be transcribed from `calculateBalances`**, not invented.

**Verify**: `go build ./...` → exit 0; new repo integration test comparing aggregates against a fixture inserted via existing repo methods → pass.

### Step 3: Switch `GetFinanceSummary`

Replace the three `ListAll*` calls in `GetFinanceSummary` with the aggregate call; map aggregates into the same `[]models.Balance` structure `calculateBalances` produced (same ordering — check whether `calculateBalances` sorts; replicate). Keep `ListMemberProfilesByGroup` + `applyDisplayNames` + `suggestReimbursements` unchanged.

**Verify**: `go test ./internal/services/... -run TestFinanceService_GetFinanceSummary` → pass *without modifying the test's expected values*.

### Step 4: Equivalence test

Add a repo-level integration test: insert a fixture group (3 users, 5 expenses with mixed split modes, 2 settlements) using existing repo methods, then assert `GetGroupBalanceAggregates`-derived balances equal `calculateBalances(ListAllExpensesByGroup(...), ListSplitsByGroup(...), ListAllSettlementsByGroup(...))` output. This is the strongest gate; if the helpers aren't accessible from the repo test package, put the equivalence test in `internal/services` behind a real-DB build tag matching how `finance_repo_test.go` gates DB tests.

**Verify**: `go test ./...` → all pass.

## Test plan

Steps 1, 3, 4. New tests: aggregate fixture test + equivalence test. Pattern: `finance_repo_test.go:334` (`TestFinanceRepo_CreateRecurringExpense`) for DB setup.

## Done criteria

- [ ] `go build ./...` and `go test ./...` exit 0
- [ ] `grep -n "ListAllExpensesByGroup\|ListSplitsByGroup\|ListAllSettlementsByGroup" backend/internal/services/finance_service.go` shows none of the three inside `GetFinanceSummary` (export paths still use `ListAllExpensesByGroup` elsewhere — that's fine)
- [ ] Characterization tests from plan 003 pass unmodified
- [ ] Equivalence test exists and passes
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 003's tests are absent (Step 1).
- `calculateBalances` semantics can't be expressed in SQL without behavior change (e.g. order-dependent logic) — report the specific rule.
- The repo integration tests can't run because no local Postgres is available and the suite has no skip mechanism — report rather than deleting tests.

## Maintenance notes

- If multi-currency support lands, the aggregate query must group by currency — today balances appear currency-blind; flag this to the reviewer as an existing limitation, unchanged by this plan.
- Reviewer should scrutinize the settled-split handling in the SQL against `calculateBalances` line by line.
- Deferred: pagination on the export `ListAll*` endpoints (acceptable for exports; revisit if groups exceed ~50k expenses).
