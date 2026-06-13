# Plan 003: Characterization tests for money paths and untested services

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- backend/internal/services`
> If `finance_service.go` changed since this plan was written (plans 001/002
> may have landed — that's expected), test the *current* behavior; on any
> other mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (tests only)
- **Depends on**: none (but land before plans 005 and 007, which refactor code this plan characterizes)
- **Category**: tests
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

The money engine (split building, balance calculation, reimbursement suggestion) is the app's reason to exist, yet its edge cases — penny rounding on 3-way splits, percentage sums, settlement effects on balances — are thinly tested, and 11 backend service modules have **zero** tests (`meal_plan_service`, `pinwall_service`, `pinwall_media_service`, `activity_service`, `assistant_service`, `attachment_service`, `calendar_service`, `grocery_service`, `expense_receipt_service`, `list_item_photo_service`, `invite_code`). Plans 005 (summary refactor) and 007 (auth consolidation) will rewrite code in these areas; this plan pins current behavior first so those refactors have a safety net.

## Current state

- Test pattern to follow: `backend/internal/services/finance_service_test.go` — `package services`, testify (`assert`/`require`/`mock`), mocks from `backend/internal/repositories/mocks`, `groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)` style. Read its first 120 lines before writing anything.
- Existing service tests: chore, finance, group, guest, list, notification, oauth, recipe, recipe_scraping, share, template, user. Everything else in `backend/internal/services/` is untested (verify with `ls backend/internal/services/*_test.go`).
- Split engine: `finance_service.go:519` `buildSplits(total int64, payerID uuid.UUID, splitMode string, inputs []ExpenseSplitInput)`; equal mode distributes `total/n` with the first `total%n` inputs getting one extra cent; exact/percentage/shares modes validate inputs. There is an existing `TestBuildSplitsAdvancedModes` — extend, don't duplicate.
- Balance pipeline: `GetFinanceSummary` (`finance_service.go:150–170`) → `calculateBalances(expenses, splits, settlements)` → `suggestReimbursements(balances)` (both package-private helpers in `finance_service.go`; read them before testing).
- `go test ./...` is green at the planned-at commit.

## Commands you will need

| Purpose | Command (run in `backend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Build   | `go build ./...`             | exit 0              |
| Run one package | `go test ./internal/services/... -v -run <Name>` | pass |
| Full suite | `go test ./...`           | all pass            |

## Scope

**In scope** (create/extend test files only — no production code changes):
- `backend/internal/services/finance_service_test.go` (extend)
- `backend/internal/services/meal_plan_service_test.go` (create)
- `backend/internal/services/pinwall_service_test.go` (create)
- `backend/internal/services/calendar_service_test.go` (create)
- `backend/internal/services/activity_service_test.go` (create)
- `backend/internal/repositories/mocks/` — only if a needed mock is missing; follow the existing generation/handwriting pattern found there.

**Out of scope**:
- Any change to non-test `.go` files. If a test reveals a bug, **document it in your final report and in a `// KNOWN BUG:` comment on a skipped test** (`t.Skip`) — do not fix it here.
- Frontend tests (separate effort).
- The remaining untested services (assistant, attachment, grocery, etc.) — nice-to-have; do them only if the five priority files above are done and green.

## Git workflow

- Branch: `test/money-path-characterization` off `new-main-fr`.
- Conventional commits (`test: ...`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Split-engine edge cases

Extend finance tests with table-driven cases for `buildSplits` (call it directly — same package):

- equal: 100/3 → amounts sum to 100, distribution `[34,33,33]` in input order; 100/7; 1/2 (`[1,0]` — assert and flag if a zero split is produced, that's a finding); single participant; payer-in-inputs gets `IsSettled == true`.
- exact: amounts summing ≠ total → error; amount ≤ 0 → error.
- percentage: percentages not summing to expected basis → assert current behavior (read the code for the basis — 100 vs 10000 — before writing).
- shares: 3 users shares 1/1/2 on 100 → sums to 100.

**Verify**: `go test ./internal/services/... -run TestBuildSplits -v` → pass.

### Step 2: Balance + reimbursement characterization

Add `TestCalculateBalances` and `TestSuggestReimbursements` (direct calls, fixtures built from `models.Expense`/`models.Split`/`models.Settlement`):

- Two users, one 100 expense split equally → payer +50, other −50; reimbursement suggests other→payer 50.
- Settlement of 50 zeroes both balances.
- Settled splits (`IsSettled: true`) don't create debt.
- Three users with circular debts → reimbursements minimize transfers (assert whatever current output is; the point is pinning it).

**Verify**: `go test ./internal/services/... -run "TestCalculateBalances|TestSuggestReimbursements" -v` → pass.

### Step 3: GetFinanceSummary through mocks

One test wiring `MockFinanceRepo`/`MockGroupRepo` so `GetFinanceSummary` returns a summary for a 2-user fixture; assert balances and that display names from `ListMemberProfilesByGroup` are applied. This is the characterization gate for plan 005.

**Verify**: `go test ./internal/services/... -run TestFinanceService_GetFinanceSummary -v` → pass.

### Step 4: Happy-path tests for untested services

For each of `meal_plan_service`, `pinwall_service`, `calendar_service`, `activity_service`: read the service file, then write 3–6 tests covering the main create/list path, the permission-denied path (non-member), and one not-found path. Use the finance test mock idiom. If a service depends on a repo interface with no mock in `mocks/`, create one following the existing mock style.

**Verify** after each file: `go test ./internal/services/...` → pass.

## Test plan

This plan *is* the test plan. Target: every new test asserts concrete values, not just "no error".

## Done criteria

- [ ] `go test ./...` exits 0
- [ ] `ls backend/internal/services/*_test.go` shows new files for meal_plan, pinwall, calendar, activity
- [ ] `go test ./internal/services/... -run TestBuildSplits -v` shows ≥ 8 new edge-case subtests
- [ ] `TestFinanceService_GetFinanceSummary` exists and passes
- [ ] No production `.go` file modified (`git status` shows only `*_test.go` and `mocks/` additions)
- [ ] Any bug discovered is recorded as a skipped test with `// KNOWN BUG:` and listed in your report
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A characterization test reveals money math that is *unambiguously* wrong (e.g. balances don't sum to zero across a group) — report it as a new finding rather than encoding it as "expected".
- A service can't be unit-tested because it constructs concrete repos internally (no interface seam) — report which one; adding seams is production-code change, out of scope.
- Mocks appear tool-generated (check for `//go:generate` / mockery markers) and regeneration fails.

## Maintenance notes

- Plans 005 and 007 rely on these tests staying green through their refactors — do not delete or weaken them there.
- The skipped `// KNOWN BUG:` tests are the backlog seed for the next audit cycle.
