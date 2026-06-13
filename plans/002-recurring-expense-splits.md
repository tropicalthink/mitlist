# Plan 002: Make recurring expenses generate real splits

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- backend/internal/jobs/recurring_expense.go backend/internal/services/finance_service.go backend/internal/models/finance.go backend/internal/repositories backend/migrations backend/internal/api/handlers/finance.go`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (migration + money math)
- **Depends on**: plans/001-finance-write-authorization.md (touches the same service file; land 001 first to avoid conflicts)
- **Category**: bug
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

Recurring expenses (rent, internet, streaming) are exactly the expenses households most need to split — but the cron job that materializes them creates only **one split: the payer's own, pre-settled**. Net effect: a recurring expense never produces any debt for anyone. It's bookkeeping theater. The recurring-expense model stores no participant/split-mode information at all, so the job *cannot* split correctly today. This plan adds participant storage and makes the job reuse the same split-building logic as one-off expenses.

## Current state

**The job** — `backend/internal/jobs/recurring_expense.go`, `processRecurringExpense` (lines ~60–120):

```go
split := models.Split{
    ID:        uuid.New(),
    ExpenseID: expense.ID,
    UserID:    re.PayerID,
    Amount:    re.Amount,
    IsSettled: true,
    CreatedAt: now,
}
...
if err := j.repo.ProcessRecurringExpense(ctx, &expense, &split, re.ID, re.NextDue, nextDue); err != nil {
```

**The repo tx** — `backend/internal/repositories/` (`recurringExpenseRepoImpl.ProcessRecurringExpense`, in the recurring-expense repo file; grep `func (r *recurringExpenseRepoImpl) ProcessRecurringExpense`): one tx inserting the expense, inserting the single split, then guarding idempotency with `UPDATE recurring_expenses SET next_due = $1 ... WHERE id = $2 AND is_active = true AND next_due = $3` and erroring if `RowsAffected() == 0`. **Keep this idempotency guard exactly as is.**

**The model** — `backend/internal/models/finance.go:69–81`:

```go
type RecurringExpense struct {
    ID          uuid.UUID `json:"id"`
    GroupID     uuid.UUID `json:"group_id"`
    PayerID     uuid.UUID `json:"payer_id"`
    Amount      int64     `json:"amount"`
    Description string    `json:"description"`
    Category    string    `json:"category"`
    Currency    string    `json:"currency"`
    Frequency   string    `json:"frequency"`
    NextDue     time.Time `json:"next_due"`
    IsActive    bool      `json:"is_active"`
    CreatedAt   time.Time `json:"created_at"`
}
```

**The schema** — `backend/migrations/000001_init_schema.up.sql:282` `CREATE TABLE recurring_expenses (...)` — no split columns. Latest migration is `000028_add_list_items_canonical_item`; migrations use golang-migrate paired `.up.sql`/`.down.sql` files.

**The split engine to reuse** — `backend/internal/services/finance_service.go`:

- `type ExpenseSplitInput struct { UserID uuid.UUID; Amount int64; Shares int64; Percentage int64 }` (line 25)
- `func buildSplits(total int64, payerID uuid.UUID, splitMode string, inputs []ExpenseSplitInput) ([]models.Split, error)` (line 519) — handles `"equal"`, `"amount"/"exact"`, `"percentage"`, `"shares"`; deterministic penny distribution; auto-settles the payer's split. It is package-private in `package services`.

The job lives in `package jobs` and currently has no dependency on `services`. Check `backend/internal/jobs/` imports and the job's constructor wiring in `backend/cmd/api/main.go` before deciding how to expose `buildSplits` (Step 3).

**Create/Update handlers** — `backend/internal/api/handlers/finance.go:614` (`CreateRecurringExpense`) decodes a request into `models.RecurringExpense`; service `CreateRecurringExpense` is at `finance_service.go:341`.

## Commands you will need

| Purpose | Command (run in `backend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Build   | `go build ./...`             | exit 0              |
| Tests   | `go test ./...`              | all pass            |
| Migration syntax check | `docker compose up -d` then `go run ./cmd/migrate up` | applies cleanly (optional; requires local postgres per `backend/README.md`) |

## Scope

**In scope**:
- `backend/migrations/0000NN_add_recurring_expense_splits.up.sql` / `.down.sql` (create; NN = next free number, 000029 at planning time)
- `backend/internal/models/finance.go` (RecurringExpense fields)
- `backend/internal/repositories/` recurring-expense repo + `interfaces.go` (CRUD columns, ProcessRecurringExpense signature)
- `backend/internal/repositories/mocks/` (regenerate/extend mock to match interface)
- `backend/internal/services/finance_service.go` (expose split building; validate split config on create/update)
- `backend/internal/jobs/recurring_expense.go`
- `backend/internal/api/handlers/finance.go` (accept split fields on create/update requests)
- Corresponding `*_test.go` files

**Out of scope**:
- The Flutter frontend — it can keep creating recurring expenses without split fields; the backend must default to the current behavior (payer-only) when no split config is stored. Frontend UI for choosing recurring splits is a follow-up.
- The idempotency mechanism in `ProcessRecurringExpense` — do not weaken the `WHERE ... next_due = $3` guard.
- One-off expense creation paths.

## Git workflow

- Branch: `fix/recurring-expense-splits` off `new-main-fr` (after plan 001 is merged).
- Conventional commits (`feat:`/`fix:`), one per step.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Migration

Create `backend/migrations/000029_add_recurring_expense_splits.up.sql` (use the next free number if 000029 is taken):

```sql
ALTER TABLE recurring_expenses ADD COLUMN IF NOT EXISTS split_mode TEXT NOT NULL DEFAULT 'payer_only';
ALTER TABLE recurring_expenses ADD COLUMN IF NOT EXISTS split_inputs JSONB NOT NULL DEFAULT '[]'::jsonb;
```

`split_inputs` stores an array of `{user_id, amount, shares, percentage}` objects mirroring `ExpenseSplitInput`. Down migration drops both columns. `'payer_only'` is the sentinel for legacy rows → current behavior.

**Verify**: both files exist, are paired, and `go build ./...` → exit 0 (no code change yet).

### Step 2: Model + repo

Add to `RecurringExpense`: `SplitMode string` (`json:"split_mode"`) and `SplitInputs []RecurringSplitInput` (`json:"split_inputs"`), with `RecurringSplitInput` defined in `models/finance.go` as `{UserID uuid.UUID; Amount int64; Shares int64; Percentage int64}` with snake_case JSON tags. Update the recurring-expense repo's INSERT/UPDATE/SELECT column lists to read/write the two new columns (marshal `SplitInputs` to JSONB; pgx handles `[]byte`/`json.Marshal` round-trips — follow whatever JSONB pattern already exists in the repo layer; grep `jsonb` in `backend/internal/repositories/` for an exemplar, e.g. the grocery or pinwall repos).

**Verify**: `go build ./...` → exit 0; `go test ./internal/repositories/...` → pass.

### Step 3: Expose split building to the job

Preferred: add an exported wrapper in `package services`:

```go
// BuildExpenseSplits exposes split computation for jobs.
func BuildExpenseSplits(total int64, payerID uuid.UUID, splitMode string, inputs []ExpenseSplitInput) ([]models.Split, error) {
    return buildSplits(total, payerID, splitMode, inputs)
}
```

Then import `services` from `jobs`. First check for an import cycle: `go list -deps ./internal/services | grep internal/jobs` → must output nothing. If it outputs anything (cycle), STOP condition applies (move `buildSplits` to a new leaf package `internal/services/splitmath` instead, only if the operator approved that fallback).

**Verify**: `go build ./...` → exit 0.

### Step 4: Use stored splits in the job

In `processRecurringExpense`:

- If `re.SplitMode == "" || re.SplitMode == "payer_only" || len(re.SplitInputs) == 0`: keep today's single settled payer split (backward compatible).
- Otherwise: convert `re.SplitInputs` → `[]services.ExpenseSplitInput`, call `services.BuildExpenseSplits(re.Amount, re.PayerID, re.SplitMode, inputs)`, and pass the resulting slice to the repo.
- Change `ProcessRecurringExpense(ctx, &expense, &split, ...)` to take `splits []models.Split` and insert all of them inside the same tx (loop the existing INSERT). Update `interfaces.go` and mocks accordingly.
- If `BuildExpenseSplits` errors (e.g. inputs no longer sum), log via the job's zerolog logger (`j.log.Error()...`) and fall back to the payer-only split rather than skipping the expense — the bill still happened.

**Verify**: `go build ./...` → exit 0; `go test ./internal/jobs/... ./internal/repositories/...` → pass.

### Step 5: Accept split config on create/update

In `finance_service.go` `CreateRecurringExpense` (line ~341) and `UpdateRecurringExpense`: if `re.SplitMode` is set and not `payer_only`, validate it by calling `buildSplits(re.Amount, re.PayerID, re.SplitMode, toExpenseSplitInputs(re.SplitInputs))` and discarding the result — invalid configs (bad mode, sums mismatch, non-member-agnostic checks aside) return the validation error. Also verify every `SplitInputs[i].UserID` is a group member via `s.requireMember(ctx, re.GroupID, input.UserID)` (return `&api.ValidationError{Message: "split user must be a member of this group"}`). Handler `CreateRecurringExpense`/`UpdateRecurringExpense` request structs in `handlers/finance.go` gain the two fields (snake_case JSON, matching model tags).

**Verify**: `go build ./...` → exit 0; `go test ./...` → pass.

### Step 6: Tests

- Service: `TestFinanceService_CreateRecurringExpense_SplitValidation` — valid equal config passes; exact amounts not summing to total → error; non-member in inputs → error; empty mode defaults fine.
- Jobs: extend the existing recurring-expense job tests (or create `recurring_expense_test.go` in `internal/jobs` modeled on existing job tests if present, else on `finance_service_test.go` mock style): equal mode with 3 users on amount 100 produces splits [34,33,33] (payer first by the deterministic rule — assert sum == 100 and payer's split `IsSettled == true`); payer_only mode produces today's single settled split.
- Repo (if repo tests run against a real DB per `finance_repo_test.go:334` pattern): multi-split insert inside `ProcessRecurringExpense` and idempotency guard still returns error on second call.

**Verify**: `go test ./...` → all pass.

## Done criteria

- [ ] `go build ./...` and `go test ./...` exit 0
- [ ] Migration pair exists and `next_due` idempotency guard is unchanged (`grep -n "next_due = \$3" backend/internal/repositories/*.go` still matches)
- [ ] A recurring expense with `split_mode = "equal"` and 2+ inputs produces one split per participant, summing to the amount, payer settled (proven by the new job test)
- [ ] Legacy rows (`split_mode = 'payer_only'`) behave exactly as before (proven by test)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Importing `services` from `jobs` creates an import cycle (see Step 3 check).
- `ProcessRecurringExpense` in the live code no longer matches the described tx shape.
- The mocks in `backend/internal/repositories/mocks/` are generated by a tool you can't identify (look for a `//go:generate` line or mockery config) — hand-editing generated files is fine only if that's what the repo already does; otherwise report.
- Migration numbering conflicts (000029 already exists with different content).

## Maintenance notes

- Frontend follow-up: the recurring-expense creation sheet should offer the same split-mode picker as one-off expenses; until then the API defaults keep old clients working.
- Reviewer should scrutinize: JSONB round-trip of `SplitInputs` (column NULL vs `'[]'`), and that the job's fallback-on-invalid-config path logs loudly.
- If a member listed in `split_inputs` later leaves the group, `BuildExpenseSplits` will still produce a split for them; deciding whether to drop-and-redistribute is deferred (record as a future finding).
