# Plan 031: Joining a group is atomic — single-use invites can't be double-claimed

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/services/group_service.go backend/internal/repositories/group_repo.go`
> On any change, compare live code to the excerpt below first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`JoinGroup` checks `invite.UsedBy != nil` and then, in two separate non-atomic
calls, creates the membership and consumes the invite. Two concurrent requests
with the same single-use code can both pass the used-check and both create
memberships, violating the single-use invariant; and if `ConsumeInvite` fails
after `CreateMembership` succeeds, the user is a member but the invite stays open.
Claiming the invite atomically (conditional update) inside a transaction with the
membership insert enforces the guarantee.

## Current state

```go
// backend/internal/services/group_service.go:207-243
func (s *GroupService) JoinGroup(ctx context.Context, userID uuid.UUID, code string) (*models.Group, error) {
	invite, err := s.groupRepo.GetInviteByCode(ctx, code)
	...
	if invite.UsedBy != nil { return nil, &api.ValidationError{Message: "invite already used"} }
	if time.Now().UTC().After(invite.ExpiresAt) { return nil, &api.ValidationError{Message: "invite expired"} }

	existing, _ := s.groupRepo.GetMembership(ctx, invite.GroupID, userID)
	if existing != nil { return nil, &api.ConflictError{Message: "already a member of this group"} }

	membership := &models.GroupMembership{ GroupID: invite.GroupID, UserID: userID, Role: "member" }
	if err := s.groupRepo.CreateMembership(ctx, membership); err != nil { return nil, err }   // write 1
	if err := s.groupRepo.ConsumeInvite(ctx, invite.ID, userID); err != nil { return nil, err } // write 2 (non-atomic)
	return s.groupRepo.GetGroupByID(ctx, invite.GroupID)
}
```

The repo has a transaction helper used elsewhere. Look for `WithTx` on the
repositories (the grocery repo uses `WithTx(ctx, func(txRepo ...) error)` — grep
`func .*WithTx` under `backend/internal/repositories/`). If `GroupRepository`
has one, use it; if not, see STOP conditions. `ConsumeInvite` currently
unconditionally marks the invite used — Step 2 changes it (or adds a variant) to
claim conditionally.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Tests | `cd backend && go test ./internal/services/ ./internal/repositories/` | pass |

## Scope

**In scope**:
- `backend/internal/services/group_service.go`
- `backend/internal/repositories/group_repo.go`
- `backend/internal/services/group_service_test.go` and/or
  `backend/internal/repositories/group_repo_test.go`

**Out of scope**:
- Invite code generation (Plan 022 owns entropy).
- Membership schema.

## Git workflow

- Branch: `advisor/031-joingroup-transaction`
- Conventional commit: `fix(groups): make join atomic; claim single-use invite conditionally`.

## Steps

### Step 1: Add a conditional invite-claim repo method

In `group_repo.go`, add (or change `ConsumeInvite` to) a method that claims the
invite only if still open, atomically:

```sql
UPDATE group_invites
SET used_by = $2, used_at = now()
WHERE id = $1 AND used_by IS NULL
RETURNING id
```
(Match the real table/column names — grep the migration for the invites table.)
Return whether a row was claimed (e.g. `pgx.ErrNoRows` → already used). This makes
the check-and-set atomic at the DB.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Wrap membership + claim in one transaction

If `GroupRepository` has a `WithTx` helper, wrap `CreateMembership` and the
conditional claim in it inside `JoinGroup`, so both commit or neither does. Order:
claim the invite first (conditional update) — if no row was claimed, return
"invite already used" and do not create membership; then create membership; then
commit. Keep the pre-checks (expiry, existing membership) before the transaction.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 3: Tests

- Repo test: two sequential conditional-claim calls for the same invite → first
  succeeds, second returns already-claimed. (Use the existing repo test harness
  in `group_repo_test.go`; the grocery repo integration test is a model for a
  real-schema DB test if one is needed.)
- Service test: `JoinGroup` with an already-used invite returns the validation
  error and creates no membership (mock the repo; assert `CreateMembership` is
  not called when the claim fails).

**Verify**: `cd backend && go test ./internal/services/ ./internal/repositories/ -run Group -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "used_by IS NULL" backend/internal/repositories/grocery_repo.go backend/internal/repositories/group_repo.go` → the conditional claim exists in group_repo.go
- [ ] `JoinGroup` performs the claim + membership insert inside one transaction (visible in the diff)
- [ ] New tests prove the second concurrent claim fails and no membership is created
- [ ] `cd backend && go test ./internal/services/ ./internal/repositories/` pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `GroupRepository` has no `WithTx` (or equivalent) helper and adding one would
  require touching the repository's construction/wiring broadly — report the
  shape you found; a minimal tx helper may be its own small plan.
- The invites table/columns differ from the assumed names — use the real ones
  from the migration; if the schema has no `used_by`/`used_at`, report it.

## Maintenance notes

- The atomic claim also fixes the "member but invite still open" partial-failure
  case, since both writes are in one transaction.
- Reviewer: confirm the pre-checks that stay outside the transaction (expiry,
  already-member) are still correct and that the conditional claim is the sole
  gate on single-use.
