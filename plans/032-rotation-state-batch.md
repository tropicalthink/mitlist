# Plan 032: Rebuilding rotation orders on membership change is not N+1

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/services/chore_service.go backend/internal/repositories/chore_repo.go`
> On any change, compare live code to the excerpt below first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`RebuildMemberOrdersForGroup` (invoked whenever a member is added/removed, also as
`SyncMemberOrderForGroup`) loops over every chore in the group and issues one
`GetRotationState` query per chore, then batches the writes. The read side is
1 + C queries (C = chore count) executed serially — an avoidable burst of
round-trips on a membership mutation. The write side already demonstrates the
batch pattern; mirroring it on the read side removes the N+1.

## Current state

```go
// backend/internal/services/chore_service.go:848-875
chores, err := s.choreRepo.ListChoresByGroup(ctx, groupID, 0, 0)
...
var updatedStates []models.ChoreRotationState
for _, chore := range chores {
	state, err := s.choreRepo.GetRotationState(ctx, chore.ID)   // ← one query per chore
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) { continue }
		return fmt.Errorf("failed to get rotation state for chore %s: %w", chore.ID, err)
	}
	state.MemberOrder = memberOrder
	if state.CurrentIndex >= len(state.MemberOrder) { state.CurrentIndex = 0 }
	updatedStates = append(updatedStates, *state)
}
if len(updatedStates) > 0 {
	if err := s.choreRepo.BulkUpdateRotationStates(ctx, updatedStates); err != nil {   // ← already batched
		return fmt.Errorf("batch update rotation states: %w", err)
	}
}
```
`BulkUpdateRotationStates` already exists in `chore_repo.go` — model the new batch
read on it. `GetRotationState` is the per-chore read to replace.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Tests | `cd backend && go test ./internal/services/ ./internal/repositories/` | pass |

## Scope

**In scope**:
- `backend/internal/repositories/chore_repo.go`
- `backend/internal/services/chore_service.go`
- `backend/internal/repositories/chore_repo_test.go` and/or `chore_service_test.go`

**Out of scope**:
- The rotation-state schema and `BulkUpdateRotationStates` (reuse as-is).
- Other callers of `GetRotationState` — leave the single-fetch method for its
  legitimate single-chore callers; only the loop changes.

## Git workflow

- Branch: `advisor/032-rotation-state-batch`
- Conventional commit: `perf(chores): batch rotation-state reads on member-order rebuild`.

## Steps

### Step 1: Add a batch read to the repo

In `chore_repo.go`, add `GetRotationStatesByChoreIDs(ctx, ids []uuid.UUID)
([]models.ChoreRotationState, error)` (or `...ByGroup(ctx, groupID)`) returning
all rotation states for the given chores in one query
(`WHERE chore_id = ANY($1)`). Model the scan on `BulkUpdateRotationStates` and
the existing `GetRotationState` for column list/scan targets.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Replace the per-chore loop with an in-memory join

In `RebuildMemberOrdersForGroup`, fetch all states once (by the group's chore IDs
or by group), build a `map[uuid.UUID]*models.ChoreRotationState`, then iterate the
chores in memory. Preserve the existing semantics: a chore with no rotation state
is skipped (the map lookup misses — equivalent to the old `pgx.ErrNoRows continue`);
`CurrentIndex` clamp unchanged; `MemberOrder` set to `memberOrder`. Feed the same
`updatedStates` slice to `BulkUpdateRotationStates`.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 3: Tests

- Repo test for the batch read (if the repo test harness supports it): returns
  states for the requested IDs, omits IDs with no state.
- Service test: `RebuildMemberOrdersForGroup` updates all chores' member orders
  and skips chores without a rotation state, with the mocked repo asserting the
  batch read is called once (not C times). Extend `chore_service_test.go`.

**Verify**: `cd backend && go test ./internal/services/ ./internal/repositories/ -run Rotation -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "GetRotationState(ctx, chore.ID)" backend/internal/services/chore_service.go` → no matches inside the rebuild loop
- [ ] `grep -n "ByChoreIDs\|RotationStatesByGroup\|ANY(" backend/internal/repositories/chore_repo.go` → the batch read exists
- [ ] Tests prove the batch read is called once and skipped chores are handled
- [ ] `cd backend && go test ./internal/services/ ./internal/repositories/` pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `GetRotationState` semantics differ from the excerpt (e.g. it lazily creates a
  state) — a batch read that only fetches existing rows would change behavior;
  report it.
- The excerpt no longer matches (drift).

## Maintenance notes

- Keep `GetRotationState` for genuine single-chore callers.
- Reviewer: confirm the map-miss path matches the old `pgx.ErrNoRows continue`
  (chores without a rotation state must still be skipped, not error).
