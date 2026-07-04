# Plan 036: One membership-check implementation in group_service

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/services/group_service.go backend/internal/services/membership.go`
> On any change, compare live code to the excerpts below first; on mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

There are two implementations of the same "is this user a member/admin of this
group?" rule: the package-level `requireGroupMember`/`requireGroupAdmin` in
`membership.go` (used by finance, attachment, pinwall, etc.) and the
`GroupService.requireMembership`/`requireAdmin` methods in `group_service.go`. Two
code paths for one authorization rule means a future change (e.g. a new role) must
be made in both, risking divergent authz. Consolidating reduces that risk. This is
low value but low risk, and authz consistency is worth it.

## Current state

Package-level helpers (return only an error):

```go
// backend/internal/services/membership.go:16-45
func requireGroupMember(ctx, groups GroupMembershipChecker, groupID, userID uuid.UUID) error {
	m, err := groups.GetMembership(ctx, groupID, userID)
	if err != nil { if errors.Is(err, pgx.ErrNoRows) { return &api.PermissionDeniedError{} }; return err }
	if m.Role != "admin" && m.Role != "member" { return &api.PermissionDeniedError{} }
	return nil
}
func requireGroupAdmin(...) error { ... m.Role != "admin" ... }
```

Service methods (return the membership, use a custom message and `isNotFound`):

```go
// backend/internal/services/group_service.go:392-417
func (s *GroupService) requireMembership(ctx, userID, groupID uuid.UUID) (*models.GroupMembership, error) {
	m, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return nil, err
	}
	return m, nil
}
func (s *GroupService) requireAdmin(ctx, userID, groupID uuid.UUID) error { ... }
```

**Important difference**: the service `requireMembership` **returns the
membership object** (callers may inspect `Role`), and it also treats `isNotFound(err)`
(not just `pgx.ErrNoRows`) as "not a member". The package helper returns only an
error and checks only `pgx.ErrNoRows`. So this is not a blind delete — the
consolidation must preserve the membership-returning variant and the `isNotFound`
handling. See Step 1 for the safe direction.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Tests | `cd backend && go test ./internal/services/` | pass |

## Scope

**In scope**:
- `backend/internal/services/membership.go`
- `backend/internal/services/group_service.go`

**Out of scope**:
- The other consumers of the package-level helpers (finance, attachment, pinwall,
  etc.) — do NOT change their call sites; the package helpers keep their current
  error-only signature for them.

## Git workflow

- Branch: `advisor/036-group-membership-helper-dedup`
- Conventional commit: `refactor(groups): single membership-check implementation`.

## Steps

### Step 1: Choose the canonical implementation (preserve membership return)

The safe direction: make the package-level helper the single source of the
role-check logic, and have the `GroupService` methods delegate to it while still
returning the membership. Concretely, refactor so there is one function that does
`GetMembership` + role check, and the service's `requireMembership` calls
`GetMembership` once and reuses the shared role-check predicate — without
double-querying. For example, extract a pure predicate
`func isMember(m *models.GroupMembership) bool` / `isAdmin(...)` and use it in
both `membership.go` and `group_service.go`, so the role rule lives in one place
even though the two callers differ in what they return and in error mapping.

Do **not** make the service method call the package helper AND then re-fetch the
membership (that reintroduces a second query). One `GetMembership`, shared
predicate.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Keep error-mapping behavior intact

The service variant's `isNotFound(err)` handling and its
`"not a member of this group"` message must be preserved (callers/tests may
depend on the message). The package variant keeps its empty-message
`PermissionDeniedError`. Only the **role predicate** is shared; error mapping
stays per-caller.

**Verify**: `cd backend && go vet ./...` → exit 0.

### Step 3: Tests

Run the existing `group_service_test.go`. Add a case if none exists asserting a
non-member is denied and an admin passes `requireAdmin`, to lock the shared
predicate. Model on the existing service tests.

**Verify**: `cd backend && go test ./internal/services/ -run Group -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] The role rule (`Role == "admin"`/`"member"`) is defined in exactly one place (grep shows a single predicate used by both files)
- [ ] `GroupService.requireMembership` still returns `*models.GroupMembership` and preserves the `isNotFound` handling + message
- [ ] `cd backend && go test ./internal/services/` pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Removing either method breaks a caller that depends on its exact return type or
  message — report it; keep both signatures, share only the predicate.
- The consolidation cannot be done without double-querying `GetMembership` —
  then it is not worth it; report and mark the finding low-value.

## Maintenance notes

- This is authz code — a reviewer should confirm no path became more permissive.
- Reviewer: verify no second `GetMembership` query was introduced.
