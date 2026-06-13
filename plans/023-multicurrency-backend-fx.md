# Plan 023: Compute group balances in a single base currency, converting foreign-currency expenses at entry time

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat fea883d3..HEAD -- backend/internal/services/finance_service.go backend/internal/repositories/finance_repo.go backend/internal/models/finance.go backend/migrations`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: HIGH (touches the most correctness-sensitive code in the app — group balance math)
- **Depends on**: none (the regression net it relies on already exists: `TestCalculateBalances`, `TestBalancesEquivalence`, `TestSuggestReimbursements`, `TestFinanceService_GetFinanceSummary` in `backend/internal/services/finance_service_test.go`)
- **Category**: direction
- **Planned at**: commit `fea883d3`, 2026-06-13

## Why this matters

Every expense already carries a `currency` column (`expenses.currency`), and the
backend accepts any value (`finance_service.go:82` only checks it is non-empty).
But the balance math is currency-blind: both the production SQL aggregate
(`GetGroupBalanceAggregates`) and the in-memory `calculateBalances` sum raw
`int64` amounts. So an expense in EUR and one in USD would be added as if they
were the same unit — `50 + 50 = 100` of nothing. Today this is masked because the
UI pins every expense to the one group currency, but the system is in an
inconsistent state: it stores per-expense currency it cannot correctly math.

This plan makes the household's currency (`groups.currency`) the **base
currency**, and converts every expense to base at entry time using a captured
FX rate. Balances, splits, and settlements all live in base currency, so the
existing SQL aggregate stays a simple `SUM` — it just sums a new `base_amount`
column. The original amount/currency/rate are preserved for display. This
unlocks the real multi-currency feature (e.g. a flatmate who paid for a group
trip in a foreign currency) without making the balance engine currency-aware
everywhere.

## Current state

Files and their roles:

- `backend/internal/models/finance.go` — `Expense`, `Split`, `Settlement`,
  `BalanceEntry`, `BalanceAggregate` structs.
- `backend/internal/services/finance_service.go` — `CreateExpenseWithSplitMode`
  (write path), `UpdateExpense`, `GetFinanceSummary` (production read path,
  uses the SQL aggregate), `calculateBalances` (in-memory, retained only for the
  equivalence test), `buildSplits`.
- `backend/internal/repositories/finance_repo.go` — `GetGroupBalanceAggregates`
  (the SQL that actually computes production balances), plus all expense
  SELECT/INSERT/UPDATE query sites.
- `backend/migrations/` — golang-migrate SQL, highest existing is
  `000029_add_recurring_expense_splits`.
- `backend/internal/services/finance_service_test.go` — the regression net.

Key excerpt — the write path (`finance_service.go:66-96`):

```go
func (s *FinanceService) CreateExpenseWithSplitMode(ctx context.Context, userID uuid.UUID, expense *models.Expense, splitMode string, splitInputs []ExpenseSplitInput) error {
	// ... permission checks ...
	if expense.Amount <= 0 {
		return api.ErrValidation
	}
	if expense.Currency == "" {
		return api.ErrValidation
	}

	splits, err := buildSplits(expense.Amount, expense.PayerID, splitMode, splitInputs)
	// ... member checks on splits ...
	return s.financeRepo.CreateExpenseWithSplits(ctx, expense, splits)
}
```

Key excerpt — the production balance read path (`finance_service.go:155-180`):
`GetFinanceSummary` calls `s.financeRepo.GetGroupBalanceAggregates(ctx, groupID)`,
then `balancesFromAggregates`. The SQL (`finance_repo.go:494+`) builds per-user
sums; the expense contribution is:

```sql
expense_paid AS (
    SELECT payer_id AS user_id, COALESCE(SUM(amount), 0) AS total
    FROM expenses
    WHERE group_id = $1
    GROUP BY payer_id
),
```

Key excerpt — the in-memory path kept in lockstep (`finance_service.go:490-512`):

```go
func calculateBalances(expenses []models.Expense, splits []models.Split, settlements []models.Settlement) []models.BalanceEntry {
	// ...
	for _, expense := range expenses {
		balance := ensure(expense.PayerID)
		balance.Paid += expense.Amount
	}
	for _, split := range splits {
		balance := ensure(split.UserID)
		balance.Owed += split.Amount
	}
	// settlements ...
}
```

`TestBalancesEquivalence` (`finance_service_test.go:633`) asserts these two
paths return identical results — it is your primary safety net. Both paths must
switch to the new base-currency column together.

The group's base currency is `groups.currency` (migration `000023`, default
`'USD'`), surfaced on `models.Group.Currency`. The service already holds
`s.groupRepo` (used for membership checks).

Conventions to match:
- Money is stored as integer minor units (`int64` cents). Never use float for
  stored amounts.
- Migrations are paired `.up.sql`/`.down.sql`, zero-padded 6-digit prefix. See
  `backend/migrations/000023_add_group_currency.up.sql` (one-line ALTER) and its
  `.down.sql` for the exact style.
- Repo methods return `(T, error)`; errors wrapped with `fmt.Errorf("...: %w", err)`.
- No semicolons after Go final-clause block types (per AGENTS.md).

## The contract this plan establishes (read before coding)

1. **Base currency = `groups.currency`.** All balances, splits, and settlements
   are denominated in it.
2. **`expenses.amount` + `expenses.currency` = the original entered values.**
3. **New `expenses.base_amount` (int64 minor units) + `expenses.fx_rate`
   (NUMERIC) = the conversion to base.** `base_amount = round(amount * fx_rate)`.
   When `currency == group base currency`, `fx_rate = 1` and `base_amount = amount`.
4. **Splits are always in base currency.** `buildSplits` runs on `base_amount`,
   not `amount`. For `exact` split mode, the caller's split inputs MUST already
   be in base currency and sum to `base_amount` (the frontend plan 024 honors
   this). `buildSplits` is otherwise unchanged.
5. **Settlements are always in base currency** (no schema change; document only).
6. **Balances sum `base_amount` for expenses**, and `splits.amount` /
   `settlements.amount` unchanged (already base).

## Commands you will need

| Purpose          | Command (run from `backend/`)            | Expected on success     |
|------------------|------------------------------------------|-------------------------|
| Compile          | `go build ./...`                         | exit 0, no output       |
| Service tests    | `go test ./internal/services/...`        | ok / PASS               |
| Repo tests       | `go test ./internal/repositories/...`    | ok / PASS               |
| Full backend     | `go test ./...`                          | all PASS (pre-existing failures noted below) |
| Migrate up (opt) | `go run ./cmd/migrate up`                | applies cleanly (needs a running Postgres) |

Note: some repo/handler tests need a live Postgres (`docker compose up -d` in
`backend/`). If a test is skipped for lack of DB, that is the pre-existing
baseline, not a regression — record it.

## Scope

**In scope** (the only files you should modify or create):
- `backend/migrations/000030_add_expense_base_amount.up.sql` (create)
- `backend/migrations/000030_add_expense_base_amount.down.sql` (create)
- `backend/internal/models/finance.go`
- `backend/internal/services/finance_service.go`
- `backend/internal/repositories/finance_repo.go`
- `backend/internal/services/finance_service_test.go` (add/extend tests)
- `backend/internal/repositories/finance_repo_test.go` (extend the aggregate test fixture)

**Out of scope** (do NOT touch, even though they look related):
- **Recurring expenses** (`recurring_expenses` table, `CreateRecurringExpense`,
  the recurring-expense cron job). They stay group-currency-only this plan;
  adding FX there is a deferred follow-up (see Maintenance notes).
- **Settlements schema** — they are already base-currency by contract; no column
  change. Do not add a currency column to `settlements`.
- The frontend (`frontend/`) — plan 024 handles all UI/offline changes.
- Any change to the `splits` table schema.

## Git workflow

- Branch: `advisor/023-multicurrency-backend-fx`
- Commit per step; conventional-commit style matching `git log` (e.g.
  `feat: convert expenses to group base currency for balances`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the migration

Create `backend/migrations/000030_add_expense_base_amount.up.sql`:

```sql
-- Base-currency projection of each expense. amount/currency stay the original
-- entered values; base_amount is amount converted to the group's currency at
-- fx_rate (base_amount = round(amount * fx_rate)). Existing rows are all in the
-- group currency, so base_amount = amount and fx_rate = 1.
ALTER TABLE expenses ADD COLUMN base_amount BIGINT NOT NULL DEFAULT 0;
ALTER TABLE expenses ADD COLUMN fx_rate NUMERIC(18,8) NOT NULL DEFAULT 1;

UPDATE expenses SET base_amount = amount WHERE base_amount = 0;
```

Create `backend/migrations/000030_add_expense_base_amount.down.sql`:

```sql
ALTER TABLE expenses DROP COLUMN IF EXISTS fx_rate;
ALTER TABLE expenses DROP COLUMN IF EXISTS base_amount;
```

**Verify**: `go build ./...` → exit 0 (migration files don't affect build; this
just confirms nothing else broke). If a Postgres is available:
`go run ./cmd/migrate up` then `go run ./cmd/migrate down` (one step) apply
cleanly.

### Step 2: Extend the `Expense` and `BalanceAggregate` models

In `backend/internal/models/finance.go`, add to `Expense`:

```go
	BaseAmount int64   `json:"base_amount"`
	FxRate     float64 `json:"fx_rate"`
```

(`fx_rate` is display/transport only — never use it for stored-amount math; the
stored truth is the integer `BaseAmount`.)

`BalanceAggregate.ExpensePaid` keeps its name but will now be fed from
`SUM(base_amount)` — update its doc comment accordingly.

**Verify**: `go build ./...` → exit 0.

### Step 3: Convert at the write path

In `CreateExpenseWithSplitMode` (`finance_service.go`), after the existing
`expense.Amount <= 0` / `expense.Currency == ""` checks:

1. Load the group's base currency:
   `group, err := s.groupRepo.GetGroupByID(ctx, expense.GroupID)` (confirm the
   exact getter name by grepping `func (.*GroupRepo) Get` in
   `backend/internal/repositories/group_repo.go`; if no by-ID getter exists,
   STOP and report).
2. Normalize the rate:
   - If `expense.Currency == group.Currency`: set `expense.FxRate = 1` and
     `expense.BaseAmount = expense.Amount`.
   - Else: require `expense.FxRate > 0` (return `api.ErrValidation` otherwise),
     and set `expense.BaseAmount = int64(math.Round(float64(expense.Amount) * expense.FxRate))`.
3. Change the split call to run on base:
   `splits, err := buildSplits(expense.BaseAmount, expense.PayerID, splitMode, splitInputs)`.

Apply the identical normalization in `UpdateExpense` (`finance_service.go:183+`)
before it persists.

Add `"math"` to the imports.

**Verify**: `go build ./...` → exit 0.

### Step 4: Persist and read the new columns in the repo

In `backend/internal/repositories/finance_repo.go`, find every expense query.
Run this to enumerate them: `grep -n "FROM expenses\|INTO expenses\|UPDATE expenses\|expenses (" backend/internal/repositories/finance_repo.go`.

For each:
- **INSERT** (in `CreateExpenseWithSplits` and any one-time-expense insert): add
  `base_amount, fx_rate` to the column list and bind `expense.BaseAmount`,
  `expense.FxRate`.
- **SELECT** (`GetExpenseByID`, `ListExpenses`, `ListAllExpenses`, any
  date-range list): add `base_amount, fx_rate` to the selected columns and to
  the `rows.Scan`/`row.Scan` targets (`&e.BaseAmount, &e.FxRate`).
- **UPDATE** (`UpdateExpense` repo method): set `base_amount = $n, fx_rate = $n`.

Then change the aggregate SQL in `GetGroupBalanceAggregates`: in the
`expense_paid` CTE, replace `SUM(amount)` with `SUM(base_amount)`. Leave
`split_owed`, `settled_out`, `settled_in` unchanged.

**Verify**: `go build ./...` → exit 0. If Postgres is available:
`go test ./internal/repositories/... -run GetGroupBalanceAggregates` → PASS.

### Step 5: Keep the in-memory path in lockstep

In `calculateBalances` (`finance_service.go:490+`), change the expense loop to
sum base:

```go
	for _, expense := range expenses {
		balance := ensure(expense.PayerID)
		balance.Paid += expense.BaseAmount
	}
```

(Splits and settlements are already base — leave them.)

**Verify**: `go build ./...` → exit 0.

### Step 6: Tests (see Test plan) then full suite

**Verify**: `go test ./internal/services/...` → PASS; `go test ./...` → no new
failures vs. the pre-existing baseline.

## Test plan

Model new tests after the existing ones in `finance_service_test.go`.

1. **`TestCalculateBalances` fixtures** — every `models.Expense` literal in this
   test must now set `BaseAmount` (equal to `Amount` for the existing
   single-currency cases) or the equivalence/sum assertions will see `0`. Update
   each fixture: `BaseAmount: <same as Amount>`.

2. **`TestBalancesEquivalence` fixtures** — same: set `BaseAmount` on every
   expense fixture so both paths agree. This test passing is the core guarantee.

3. **New: `TestCreateExpense_ForeignCurrencyConvertsToBase`** in
   `finance_service_test.go`, modeled on `TestFinanceService_CreateExpense`:
   - Group currency `USD`. Create an expense `Amount: 5000` (50.00),
     `Currency: "EUR"`, `FxRate: 1.10`. Assert the persisted expense has
     `BaseAmount == 5500` and the equal-split shares sum to `5500`.
   - Foreign currency with `FxRate <= 0` returns `api.ErrValidation`.
   - Same-currency expense (`Currency == group currency`) forces `FxRate == 1`
     and `BaseAmount == Amount` even if a different rate was passed in.

   (Use the existing mock-repo pattern in this file; capture the `*models.Expense`
   passed to the repo's `CreateExpenseWithSplits` to assert `BaseAmount`.)

4. **`TestFinanceRepo_GetGroupBalanceAggregates`** (`finance_repo_test.go:539`) —
   if it seeds expenses directly, add `base_amount` to the seed inserts (set to
   the same value as `amount` for its single-currency fixture) so the aggregate
   still matches.

**Verify**: `go test ./internal/services/... ./internal/repositories/...` →
all PASS, including the new test.

## Done criteria

ALL must hold:

- [ ] `go build ./...` exits 0
- [ ] `go test ./internal/services/...` PASS (incl. new
      `TestCreateExpense_ForeignCurrencyConvertsToBase`)
- [ ] `go test ./...` shows no new failures vs. the pre-existing baseline
- [ ] `grep -n "SUM(base_amount)" backend/internal/repositories/finance_repo.go`
      returns the `expense_paid` CTE line
- [ ] `grep -n "base_amount" backend/migrations/000030_add_expense_base_amount.up.sql`
      returns matches; the `.down.sql` drops both columns
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts don't match the live code (drift since `fea883d3`).
- `backend/internal/repositories/group_repo.go` has no by-ID group getter to
  read the base currency (Step 3.1) — report what getters exist instead.
- `TestBalancesEquivalence` cannot be made green after updating fixtures — this
  means the two balance paths have diverged; do not paper over it.
- Step 4 reveals an expense query site you cannot confidently update (e.g. a
  `SELECT *` that maps columns positionally elsewhere) — report it.
- The migration's `UPDATE` would touch rows where `currency != group currency`
  already exist (i.e. mixed-currency data predates this plan) — report; the
  backfill assumption (all existing rows are group-currency, rate 1) would be
  wrong and those `base_amount` values would need a real conversion.

## Maintenance notes

- **Recurring expenses are deliberately excluded.** When FX is added there, the
  cron job that materializes recurring expenses into real expenses must compute
  `base_amount`/`fx_rate` at materialization time using the rate-of-the-day, and
  the same `recurring_expenses` currency column already exists (migration
  `000017`).
- **FX rate source is the caller's responsibility.** This plan does not fetch
  rates from any external service — consistent with the app's offline-first,
  no-telemetry, self-host ethos. The frontend (plan 024) supplies the rate
  (user-entered, defaulting to last-known or 1.0). If automatic rate lookup is
  ever added, it belongs behind an opt-in setting, never a hard dependency.
- **Reviewer scrutiny**: confirm `TestBalancesEquivalence` still passes (the SQL
  and in-memory paths agree), and that `base_amount` — not `amount` — is what
  every balance/aggregate path sums. A single missed `SUM(amount)` reintroduces
  the currency-blind bug.
- The `exact` split-mode contract (inputs already in base currency) is enforced
  by convention, not code — plan 024 must respect it; a future hardening could
  validate it server-side.
