# Plan 033: Recurring expenses and expense edits keep base_amount and splits consistent

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 45ae60c2..HEAD -- backend/internal/jobs/recurring_expense.go backend/internal/services/finance_service.go backend/internal/repositories/finance_repo.go`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `45ae60c2`, 2026-06-15

## Why this matters

Plan 023 added `base_amount`/`fx_rate` columns to `expenses` and made **all
balance math sum `base_amount`** (e.g. `finance_repo.go:511`
`COALESCE(SUM(base_amount), 0)`, `finance_service.go:531`
`balance.Paid += expense.BaseAmount`). Two write paths were missed in that
migration and now silently corrupt balances:

1. **Recurring expenses** (`jobs/recurring_expense.go`) build the `Expense`
   and INSERT it **without** `base_amount`/`fx_rate`. The column default is
   `base_amount = 0`, so every materialised recurring expense credits the
   payer **0** while the splits still debit owers the full amount. A $1000
   monthly rent silently drifts every group balance by $1000/month.

2. **Editing an expense's amount** (`finance_service.go:UpdateExpense`)
   recomputes `base_amount` but **never rebuilds the splits**. The old splits
   (summing to the *old* base_amount) survive, so the payer is credited the new
   amount while owers are debited the old one — the difference is silent
   balance corruption.

After this plan, both paths keep `base_amount` and the splits internally
consistent, so balances stay correct.

## Current state

### Path 1 — recurring expense (the base_amount=0 bug)

`backend/internal/jobs/recurring_expense.go:61-76` — builds the Expense with
no BaseAmount/FxRate:

```go
expense := models.Expense{
	ID:          expenseID,
	GroupID:     re.GroupID,
	PayerID:     re.PayerID,
	Amount:      re.Amount,
	Description: re.Description,
	Category:    re.Category,
	Currency:    re.Currency,
	Date:        now,
	CreatedAt:   now,
	UpdatedAt:   now,
}
```

`backend/internal/jobs/recurring_expense.go:230-233` — the INSERT omits the
two columns:

```go
_, err = tx.Exec(ctx, `
	INSERT INTO expenses (id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at)
	VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
`, expense.ID, expense.GroupID, expense.PayerID, expense.Amount, expense.Description, expense.Category, expense.Currency, "", expense.Date, expense.CreatedAt, expense.UpdatedAt)
```

Splits are built from `re.Amount` (`recurring_expense.go:125` and `:144`
`services.BuildExpenseSplits(re.Amount, ...)`), so they sum to `re.Amount`.

**Key constraint**: recurring expenses have **no FX support**. The
`recurring_expenses` table and `models.RecurringExpense`
(`internal/models/finance.go:95-109`) store `Currency` but **no fx_rate**, and
`CreateRecurringExpense` (`finance_service.go:397`) does no currency
normalisation. The migration `000030_add_expense_base_amount.up.sql` documents
the same assumption: "Existing rows are all in the group currency, so
base_amount = amount and fx_rate = 1." So the correct fix for recurring
materialisation is `fx_rate = 1`, `base_amount = amount` — which keeps
`base_amount` equal to the sum of the splits. (Foreign-currency recurring FX is
a separate future feature; see Maintenance notes.)

### Path 2 — UpdateExpense stale splits (H5)

`backend/internal/services/finance_service.go:209-240`:

```go
func (s *FinanceService) UpdateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense) error {
	existing, err := s.financeRepo.GetExpenseByID(ctx, expense.ID)
	...
	if expense.Amount <= 0 {
		return api.ErrValidation
	}
	expense.GroupID = existing.GroupID
	if err := s.normalizeBaseAmount(ctx, expense); err != nil {
		return err
	}
	return s.financeRepo.UpdateExpense(ctx, expense)   // <-- splits never touched
}
```

`normalizeBaseAmount` (`finance_service.go:108-123`) sets `BaseAmount`/`FxRate`
correctly. The repo `UpdateExpense` (`finance_repo.go:117-132`) updates only the
`expenses` row. The split-sum invariant that `buildSplits` enforces at
creation (`finance_service.go:621`, exact mode validates sum == total) is **not**
re-checked on edit. The update handler (`api/handlers/finance.go:198-257`)
sends no split inputs — only scalar expense fields — so the **original split
mode is not available**; splits must be **rescaled proportionally** to the new
base_amount instead of rebuilt from a mode.

### Conventions

- Money is `int64` minor units. `fx_rate` is `float64`. `base_amount = round(amount * fx_rate)` (see `normalizeBaseAmount`, `finance_service.go:121`, uses `math.Round`).
- Same-currency expenses use `fx_rate = 1`, `base_amount = amount`.
- Repo write methods that touch multiple tables use a pgx transaction with `defer tx.Rollback(ctx)` then `tx.Commit(ctx)` — see `finance_repo.go:603` `CreateExpenseWithSplits` and `:135` `DeleteExpense`.
- Tests use `testify/mock`; the job test mocks `recurringExpenseRepo` — see `internal/jobs/recurring_expense_test.go`.

## Commands you will need

| Purpose   | Command                                                        | Expected on success |
|-----------|---------------------------------------------------------------|---------------------|
| Build     | `cd backend && go build ./...`                                | exit 0              |
| Vet       | `cd backend && go vet ./...`                                  | exit 0              |
| Job tests | `cd backend && go test ./internal/jobs/...`                   | all pass            |
| Svc tests | `cd backend && go test ./internal/services/...`              | all pass            |
| All tests | `cd backend && go test ./...`                                 | all pass            |

## Scope

**In scope** (the only files you should modify):
- `backend/internal/jobs/recurring_expense.go`
- `backend/internal/jobs/recurring_expense_test.go`
- `backend/internal/services/finance_service.go`
- `backend/internal/repositories/finance_repo.go`
- `backend/internal/services/finance_service_test.go` (add cases; create only if it does not exist — check first with `ls`)

**Out of scope** (do NOT touch):
- The `recurring_expenses` schema / migrations — do not add an `fx_rate` column. This plan deliberately treats recurring expenses as base-currency (see Maintenance notes).
- The expense **create** path (`CreateExpenseWithSplitMode`) — it already sets base_amount correctly.
- Any change to the `UpdateExpense` HTTP request shape in `api/handlers/finance.go` — clients depend on it.

## Git workflow

- Branch: `advisor/033-recurring-expense-base-amount`
- Commit per step; conventional-commit style (repo uses `fix(...)`, `feat(...)`, `refactor(...)` — see `git log`). Example: `fix(finance): set base_amount on recurring expense materialisation`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Set base_amount/fx_rate when materialising a recurring expense

In `backend/internal/jobs/recurring_expense.go`, in `processRecurringExpense`,
add the two fields to the `models.Expense` literal (after `Amount: re.Amount,`):

```go
		Amount:      re.Amount,
		BaseAmount:  re.Amount, // recurring expenses are base-currency; fx_rate=1
		FxRate:      1,
```

**Verify**: `cd backend && go build ./...` → exit 0

### Step 2: Include base_amount/fx_rate in the recurring INSERT

In `ProcessRecurringExpense` (`recurring_expense.go:230-233`), change the
INSERT to include the two columns, matching the column/placeholder count to
`CreateExpenseWithSplits` (`finance_repo.go:617-620`):

```go
	_, err = tx.Exec(ctx, `
		INSERT INTO expenses (id, group_id, payer_id, amount, base_amount, fx_rate, description, category, currency, notes, date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
	`, expense.ID, expense.GroupID, expense.PayerID, expense.Amount, expense.BaseAmount, expense.FxRate, expense.Description, expense.Category, expense.Currency, "", expense.Date, expense.CreatedAt, expense.UpdatedAt)
```

**Verify**: `cd backend && go build ./...` → exit 0

### Step 3: Assert base_amount in the recurring job tests

In `recurring_expense_test.go`, tighten the existing `ProcessRecurringExpense`
expectations so they confirm the expense carries the right base_amount. Add a
`mock.MatchedBy` on the `*models.Expense` argument (currently
`mock.AnythingOfType("*models.Expense")`) in **at least**
`TestRecurringExpenseJob_PayerOnlyMode` (amount 1000) and
`TestRecurringExpenseJob_EqualSplitMode` (amount 100):

```go
mock.MatchedBy(func(e *models.Expense) bool {
	return e.BaseAmount == e.Amount && e.FxRate == 1 && e.BaseAmount > 0
}),
```

(Replace the corresponding `mock.AnythingOfType("*models.Expense")` argument in
those `repo.On("ProcessRecurringExpense", ...)` calls.)

**Verify**: `cd backend && go test ./internal/jobs/...` → all pass

### Step 4: Add a repo method that updates an expense and replaces its splits

In `backend/internal/repositories/finance_repo.go`, add a new method next to
`UpdateExpense` that does the update + split replacement in one transaction.
Model it on `CreateExpenseWithSplits` (`finance_repo.go:603`) and `DeleteExpense`
(`finance_repo.go:135`, which deletes splits then the expense):

```go
// UpdateExpenseWithSplits updates an expense and replaces all of its splits
// in a single transaction, keeping base_amount and the split sum consistent.
func (r *FinanceRepo) UpdateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error {
	e.UpdatedAt = time.Now().UTC()
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	cmd, err := tx.Exec(ctx, `
		UPDATE expenses
		SET payer_id = $1, amount = $2, base_amount = $3, fx_rate = $4, description = $5, category = $6, currency = $7, notes = $8, date = $9, updated_at = $10
		WHERE id = $11
	`, e.PayerID, e.Amount, e.BaseAmount, e.FxRate, e.Description, e.Category, e.Currency, e.Notes, e.Date, e.UpdatedAt, e.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("expense not found: %w", pgx.ErrNoRows)
	}

	if _, err = tx.Exec(ctx, `DELETE FROM splits WHERE expense_id = $1`, e.ID); err != nil {
		return err
	}
	for i := range splits {
		s := &splits[i]
		if s.ID == uuid.Nil {
			s.ID = uuid.New()
		}
		s.ExpenseID = e.ID
		if s.CreatedAt.IsZero() {
			s.CreatedAt = e.UpdatedAt
		}
		if _, err = tx.Exec(ctx, `
			INSERT INTO splits (id, expense_id, user_id, amount, is_settled, created_at)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, s.ID, s.ExpenseID, s.UserID, s.Amount, s.IsSettled, s.CreatedAt); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
```

If `FinanceRepo` is accessed through an interface in the service (check how
`s.financeRepo` is typed — search `financeRepo` field declaration and any
`*Iface` interface in `finance_service.go` / a repo-interface file), add
`UpdateExpenseWithSplits` to that interface and to any mock used in
`finance_service_test.go`. **If you cannot find where the interface or mock is
defined, STOP and report** rather than guessing.

**Verify**: `cd backend && go build ./...` → exit 0

### Step 5: Rescale splits proportionally in UpdateExpense

In `finance_service.go:UpdateExpense`, after `normalizeBaseAmount` succeeds,
load the existing splits, rescale them to the new `base_amount`, and persist via
the new repo method instead of `UpdateExpense`. Rescaling preserves each split's
share of the total without needing the original split mode:

```go
	expense.GroupID = existing.GroupID
	if err := s.normalizeBaseAmount(ctx, expense); err != nil {
		return err
	}

	// base_amount unchanged → splits already consistent, plain update is enough.
	if expense.BaseAmount == existing.BaseAmount {
		return s.financeRepo.UpdateExpense(ctx, expense)
	}

	// base_amount changed → rescale existing splits proportionally so their
	// sum stays equal to base_amount (the invariant all balance math relies on).
	existingSplits, err := s.financeRepo.ListSplitsByExpense(ctx, expense.ID)
	if err != nil {
		return err
	}
	rescaled := rescaleSplits(existingSplits, existing.BaseAmount, expense.BaseAmount)
	return s.financeRepo.UpdateExpenseWithSplits(ctx, expense, rescaled)
```

Add a package-level helper in `finance_service.go`. It must guarantee
`sum(out) == newTotal` exactly by assigning the rounding remainder to the
largest split (mirror the "largest remainder" approach used in `buildSplits`):

```go
// rescaleSplits proportionally rescales splits from oldTotal to newTotal,
// preserving each split's share and guaranteeing the new amounts sum to
// newTotal. is_settled and user are preserved. Safe when oldTotal == 0
// (falls back to an even split across the same users).
func rescaleSplits(splits []models.Split, oldTotal, newTotal int64) []models.Split {
	out := make([]models.Split, len(splits))
	copy(out, splits)
	if len(out) == 0 {
		return out
	}
	var assigned int64
	largest := 0
	for i := range out {
		var amt int64
		if oldTotal > 0 {
			amt = int64(math.Round(float64(out[i].Amount) * float64(newTotal) / float64(oldTotal)))
		} else {
			amt = newTotal / int64(len(out))
		}
		out[i].Amount = amt
		assigned += amt
		if out[i].Amount > out[largest].Amount {
			largest = i
		}
	}
	// Push the rounding remainder onto the largest split so the sum is exact.
	out[largest].Amount += newTotal - assigned
	return out
}
```

Confirm `math` is already imported in `finance_service.go` (it is — used by
`normalizeBaseAmount`). Confirm `ListSplitsByExpense` exists on the repo
interface (`finance_repo.go:177`); if it is not on the interface the service
uses, add it there and to the mock as in Step 4.

**Verify**: `cd backend && go build ./...` → exit 0

### Step 6: Test the edit-rescale path

Add tests in `finance_service_test.go` (check `ls backend/internal/services/finance_service_test.go`; if absent, create following the structure of an existing `*_service_test.go` in that dir). Cover:
- Editing amount upward: a $100 expense split 2-way ($50/$50) edited to $200 → splits become $100/$100, sum == new base_amount.
- Editing with an odd remainder: $100 → $101 across 2 equal splits → amounts sum to exactly 101 (one split gets the extra cent).
- A `rescaleSplits` unit test with `oldTotal == 0` (the corruption-recovery case) → sum == newTotal.

**Verify**: `cd backend && go test ./internal/services/...` → all pass, new tests included

## Test plan

- New/updated tests: recurring job asserts `BaseAmount == Amount && FxRate == 1` (Step 3); service tests for proportional rescale incl. rounding remainder and `oldTotal==0` (Step 6).
- Structural pattern: job tests follow `recurring_expense_test.go`; service tests follow an existing `*_service_test.go` in `backend/internal/services/`.
- Verification: `cd backend && go test ./...` → all pass.

## Done criteria

ALL must hold:

- [ ] `cd backend && go build ./...` exits 0
- [ ] `cd backend && go vet ./...` exits 0
- [ ] `cd backend && go test ./...` exits 0
- [ ] `grep -n "INSERT INTO expenses" backend/internal/jobs/recurring_expense.go` shows `base_amount, fx_rate` in the column list
- [ ] Recurring job test asserts `BaseAmount`/`FxRate` on the materialised expense
- [ ] `UpdateExpense` rebuilds (rescales) splits when base_amount changes; new service tests prove the split sum equals the new base_amount
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report (do not improvise) if:

- The "Current state" excerpts don't match live code (drift since `45ae60c2`).
- You cannot locate the repo interface / mock that `s.financeRepo` is typed against (Step 4/5) — do not guess its shape.
- `normalizeBaseAmount` no longer sets `fx_rate=1` for same-currency expenses (the recurring base-currency assumption would then be wrong).
- Any verification fails twice after a reasonable fix attempt.
- The fix appears to require touching the `recurring_expenses` schema or the `UpdateExpense` HTTP request shape (both out of scope).

## Maintenance notes

- **Foreign-currency recurring expenses are still 1:1.** This plan sets `fx_rate=1`/`base_amount=amount` for recurring materialisation because the `recurring_expenses` table stores no rate. If recurring expenses ever need real FX, add an `fx_rate` column + a normalisation step mirroring `normalizeBaseAmount`, and update Step 1/2 to use it. Until then, a recurring expense entered in a non-base currency is treated as base-currency.
- A reviewer should scrutinise the rounding-remainder logic in `rescaleSplits` (sum must be exact) and confirm `is_settled` flags survive the rescale.
- Backfill: existing recurring-materialised rows in production may already have `base_amount = 0`. A one-off `UPDATE expenses SET base_amount = amount, fx_rate = 1 WHERE base_amount = 0 AND amount > 0` may be warranted — flagged here, not performed by this plan.
