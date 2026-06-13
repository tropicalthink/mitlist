# Plan 007: Consolidate per-service membership checks into one helper

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- backend/internal/services`
> Plans 001–003 are expected to have touched these files; re-grep the current
> duplication sites (Step 1) rather than trusting the planning-time list.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (mechanical refactor behind green tests)
- **Depends on**: plans/001-finance-write-authorization.md, plans/003-money-path-tests.md
- **Category**: tech-debt
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

Roughly 14 services in `backend/internal/services/` each hand-roll the same membership/admin check against `groupRepo.GetMembership`. That's authorization logic duplicated across every tenant boundary in a multi-tenant app: a fix or rule change (e.g. a new role) must be applied N times, and drift between copies is exactly how the plan-001 class of bug happens. Consolidate to one implementation with one test suite.

## Current state

Canonical copy — `backend/internal/services/finance_service.go:40–66`:

```go
func (s *FinanceService) requireMember(ctx context.Context, groupID, userID uuid.UUID) error {
    m, err := s.groupRepo.GetMembership(ctx, groupID, userID)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return api.ErrPermissionDenied
        }
        return err
    }
    if m.Role != "admin" && m.Role != "member" {
        return api.ErrPermissionDenied
    }
    return nil
}

func (s *FinanceService) requireAdmin(ctx context.Context, groupID, userID uuid.UUID) error {
    // same shape, Role must be "admin"
}
```

Near-identical methods (sometimes named `requireMembership`) exist across the other services — enumerate with:

```
grep -rn "func (s \*.*) require\(Member\|Admin\|Membership\)" backend/internal/services/
```

All services already hold a `groupRepo repositories.GroupRepo` (or access to one); all are in the single `package services` (verify — if any auth-checking service lives outside `package services`, note it and include it via the exported helper).

Conventions: errors from `backend/internal/api` (`api.ErrPermissionDenied`); pgx `ErrNoRows`; tests with testify mocks (`mocks.MockGroupRepo`).

## Commands you will need

| Purpose | Command (run in `backend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Build   | `go build ./...`             | exit 0              |
| Tests   | `go test ./...`              | all pass            |
| Find copies | the grep above           | shrinking list as you migrate |

## Scope

**In scope**:
- New file `backend/internal/services/membership.go` (+ `membership_test.go`)
- Every service file in `backend/internal/services/` containing a `require*` membership/admin method
- No interface, route, or repo changes

**Out of scope**:
- HTTP middleware — do **not** move authorization to the middleware layer; checks stay in services (some service methods derive groupID from the entity, not the route).
- Handlers, repositories, models.
- Behavior changes of any kind — same errors, same role rules. If two services' copies *differ* semantically, that's a STOP condition, not a judgment call.

## Git workflow

- Branch: `refactor/consolidate-membership-checks` off `new-main-fr` (after 001 and 003 merge).
- One commit per migrated service keeps review easy (`refactor: use shared membership check in <service>`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Inventory

Run the grep above; record every file + method + any semantic deviation from the canonical copy (different role sets, different error types, extra logic like guest roles — check `guest_service.go` carefully). If all copies are semantically identical, proceed; otherwise STOP and report the deviations.

### Step 2: Create the shared helper

`backend/internal/services/membership.go`:

```go
// requireGroupMember returns api.ErrPermissionDenied unless userID has role
// "admin" or "member" in groupID.
func requireGroupMember(ctx context.Context, groups repositories.GroupRepo, groupID, userID uuid.UUID) error { ... }

// requireGroupAdmin returns api.ErrPermissionDenied unless userID has role
// "admin" in groupID.
func requireGroupAdmin(ctx context.Context, groups repositories.GroupRepo, groupID, userID uuid.UUID) error { ... }
```

Package-private free functions taking the repo as a parameter — no new struct, no DI changes. Body is the canonical copy verbatim. Write `membership_test.go` covering: member ok, admin ok, unknown role denied, no row denied, repo error propagated (5 tests, testify mocks).

**Verify**: `go build ./...` exit 0; `go test ./internal/services/... -run "requireGroup|Membership" -v` → new tests pass.

### Step 3: Migrate service by service

For each service from the Step 1 inventory: change its `requireMember`/`requireAdmin` method bodies to one-line delegations (`return requireGroupMember(ctx, s.groupRepo, groupID, userID)`), or replace call sites directly and delete the method — prefer delegation first (smaller diff), then optionally inline. After each service:

**Verify**: `go build ./...` && `go test ./...` → green before moving on.

### Step 4: Remove the dead per-service bodies

Once all delegations are in place, the grep from Step 1 should show only one-line delegating methods or direct calls.

**Verify**: `grep -rn "GetMembership" backend/internal/services/ | grep -v membership.go | grep -v _test.go` → only delegation sites or zero raw uses of the role-checking pattern remain (raw `GetMembership` calls that do something *other* than role-gating may legitimately remain — list them in your report).

## Test plan

`membership_test.go` (Step 2) plus the full existing suite — plans 001/003 tests are the regression net proving no behavior changed.

## Done criteria

- [ ] `go build ./...` and `go test ./...` exit 0
- [ ] `membership.go` + `membership_test.go` exist; helper tests pass
- [ ] The Step 1 grep shows no remaining full-body duplicate implementations
- [ ] No handler/repo/model files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any two copies differ semantically (Step 1) — e.g. a service that also accepts a "guest" role.
- Any auth-checking service lives outside `package services`.
- A migration step turns a previously-passing test red and the cause isn't an obvious mechanical slip.

## Maintenance notes

- New services must use `requireGroupMember`/`requireGroupAdmin` — worth adding one line to `AGENTS.md`'s backend section after this lands.
- Reviewer: diff should be almost entirely deletions + one-liners; scrutinize any hunk that isn't.
- Deferred: role model extensibility (guest/viewer roles) — centralizing now makes that change single-site later.
