# Plan 001: Close authorization gaps on finance update paths

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- backend/internal/services/finance_service.go backend/internal/services/finance_service_test.go`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

mitlist is a multi-tenant household app where group members share expenses. The *create* and *delete* paths enforce roles correctly: creating an expense with a different payer requires admin, and `DeleteExpense`/`DeleteSplit`/`DeleteRecurringExpense` are admin-only. But the three *update* paths only require plain group membership. Today any group member can: reassign who paid an expense (rewriting financial liability), set a split's amount to zero or a negative value (no validation exists on update), or change a recurring expense's amount/frequency/payer. This breaks the group's financial ledger integrity and is inconsistent with the rules the same service enforces elsewhere.

## Current state

All code is in `backend/internal/services/finance_service.go`. The service has two auth helpers (lines 40–66):

```go
func (s *FinanceService) requireMember(ctx context.Context, groupID, userID uuid.UUID) error   // role "admin" or "member"
func (s *FinanceService) requireAdmin(ctx context.Context, groupID, userID uuid.UUID) error    // role "admin" only
```

**The rule the create path enforces** (`CreateExpenseWithSplitMode`, lines ~87–100):

```go
if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
    return err
}
// Only allow setting a different payer if the user is an admin.
if expense.PayerID != userID {
    if err := s.requireAdmin(ctx, expense.GroupID, userID); err != nil {
        return &api.ValidationError{Message: "payer must be the current user or you must be an admin"}
    }
}
if err := s.requireMember(ctx, expense.GroupID, expense.PayerID); err != nil {
    return &api.ValidationError{Message: "payer must be a member of this group"}
}
if expense.Amount <= 0 {
    return api.ErrValidation
}
```

**Gap 1 — `UpdateExpense` (lines ~180–194)**: only `requireMember`; no payer-change check, no amount validation:

```go
func (s *FinanceService) UpdateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense) error {
    existing, err := s.financeRepo.GetExpenseByID(ctx, expense.ID)
    ...
    if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
        return err
    }
    expense.GroupID = existing.GroupID
    return s.financeRepo.UpdateExpense(ctx, expense)
}
```

**Gap 2 — `UpdateSplit` (lines ~252–273)**: only `requireMember`; no `split.Amount > 0` validation (contrast `buildSplits` at line ~557 which rejects non-positive exact amounts):

```go
if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
    return err
}
split.ExpenseID = existing.ExpenseID
return s.financeRepo.UpdateSplit(ctx, split)
```

**Gap 3 — `UpdateRecurringExpense` (lines ~375–389)**: only `requireMember`:

```go
if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
    return err
}
re.GroupID = existing.GroupID
return s.financeRepo.UpdateRecurringExpense(ctx, re)
```

Compare each with its sibling delete, which uses `requireAdmin` (e.g. `DeleteSplit`, lines ~277–296).

Conventions: error returns use `api.ErrValidation`, `&api.ValidationError{Message: ...}`, `api.ErrPermissionDenied` from `backend/internal/api`. Tests use testify + mocks from `backend/internal/repositories/mocks` — see `finance_service_test.go:19–60` for the exact pattern (`groupRepo.On("GetMembership", ...)` returning `&models.GroupMembership{Role: "member"}` etc.).

## Commands you will need

| Purpose | Command (run in `backend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Build   | `go build ./...`             | exit 0              |
| Tests   | `go test ./internal/services/...` | all pass       |
| Full suite | `go test ./...`           | all pass (suite is green at planned-at commit) |

## Scope

**In scope** (the only files you should modify):
- `backend/internal/services/finance_service.go`
- `backend/internal/services/finance_service_test.go`

**Out of scope** (do NOT touch):
- `backend/internal/api/handlers/finance.go` — handlers delegate auth to the service; no handler change needed.
- `backend/internal/repositories/` — no repo or SQL change.
- Other services with similar `requireMember` patterns — consolidation is plan 007.
- API response shapes.

## Git workflow

- Branch: `fix/finance-update-authorization` off the current default branch (`new-main-fr`).
- Commit style: conventional commits as in `git log` (e.g. `fix: enforce admin on finance update paths`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Harden `UpdateExpense`

In `UpdateExpense`, after the existing `requireMember` check, add (mirroring `CreateExpenseWithSplitMode`):

1. If `expense.PayerID != existing.PayerID && expense.PayerID != userID`: `requireAdmin(ctx, existing.GroupID, userID)`, returning `&api.ValidationError{Message: "payer must be the current user or you must be an admin"}` on failure.
2. If the payer changed, verify the new payer is a member: `requireMember(ctx, existing.GroupID, expense.PayerID)` → on failure return `&api.ValidationError{Message: "payer must be a member of this group"}`.
3. If `expense.Amount <= 0`: return `api.ErrValidation`.

**Verify**: `go build ./...` → exit 0

### Step 2: Harden `UpdateSplit`

After the `requireMember` check in `UpdateSplit`, add:

1. If `split.Amount <= 0`: return `&api.ValidationError{Message: "split amount must be positive"}`.
2. If `split.UserID != existing.UserID` (reassigning the split to another user): require `requireAdmin(ctx, expense.GroupID, userID)`.

**Verify**: `go build ./...` → exit 0

### Step 3: Harden `UpdateRecurringExpense`

After the `requireMember` check, add:

1. If `re.Amount <= 0`: return `api.ErrValidation`.
2. If `re.PayerID != existing.PayerID && re.PayerID != userID`: `requireAdmin(ctx, existing.GroupID, userID)` with the same ValidationError message as Step 1.

**Verify**: `go build ./...` → exit 0

### Step 4: Tests

In `finance_service_test.go`, add table-driven subtests modeled on `TestFinanceService_CreateExpense` (lines 19–60):

- `TestFinanceService_UpdateExpense`: member updating own-payer expense succeeds; member reassigning payer → permission/validation error; admin reassigning payer succeeds; amount ≤ 0 → `api.ErrValidation`.
- `TestFinanceService_UpdateSplit`: member updating amount to positive value succeeds; amount 0 and −5 → validation error; member reassigning split user → denied; admin reassigning → succeeds.
- `TestFinanceService_UpdateRecurringExpense`: same shape (amount ≤ 0; payer reassignment member vs admin).

Mock setup pattern: `groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)` and `financeRepo.On("GetExpenseByID", ...)` / `On("GetSplitByID", ...)` / `On("GetRecurringExpenseByID", ...)` returning the `existing` fixture.

**Verify**: `go test ./internal/services/... -run TestFinanceService_Update -v` → all new subtests pass

## Test plan

Covered by Step 4. Full regression: `go test ./...` → all pass.

## Done criteria

- [ ] `go build ./...` exits 0
- [ ] `go test ./...` exits 0; new `TestFinanceService_Update*` tests exist and pass
- [ ] `UpdateExpense`, `UpdateSplit`, `UpdateRecurringExpense` each contain an admin check for payer/user reassignment and a positive-amount validation (confirm via reading the diff)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The code at the cited locations doesn't match the excerpts above.
- Existing tests fail in a way that suggests handlers or the Flutter app intentionally rely on members editing payer (e.g. a test named for member-payer-edit passes today) — the product rule may differ from the create path; report instead of choosing.
- `go test ./...` was failing before your changes (record which packages and proceed only with `./internal/services/...` green).

## Maintenance notes

- Plan 007 will extract `requireMember`/`requireAdmin` into a shared helper; these new checks should migrate with it.
- Reviewer should scrutinize: whether the product intends *any* member to edit expense metadata (description/category) — this plan deliberately keeps metadata edits member-level and only gates payer reassignment + amounts; tightening further is a product call.
- `UpdateExpense` does not rebalance existing splits when the amount changes — known gap, deliberately out of scope here; consider a follow-up finding if splits/amount invariants matter.
