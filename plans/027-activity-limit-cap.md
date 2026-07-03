# Plan 027: The activity-feed endpoint caps its `limit` like every other list endpoint

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/api/handlers/activity.go backend/internal/api/handlers/common.go`
> On any change, compare the excerpts below to live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

Every list endpoint in this API caps `limit` at 500 via the shared
`parsePagination` helper — except the activity feed, which parses `limit`
straight from the query string with only a `> 0` guard and no maximum. A client
can request `?limit=10000000` and force an unbounded scan and serialize of the
activity table: over-fetch and a cheap denial-of-service vector on an otherwise
consistent codebase.

## Current state

```go
// backend/internal/api/handlers/activity.go:42-49
limit := 10
if l := r.URL.Query().Get("limit"); l != "" {
	if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
		limit = parsed        // ← no upper bound
	}
}
events, err := h.service.ListRecentActivity(r.Context(), user, groupID, limit)
```

The shared helper it should mirror:

```go
// backend/internal/api/handlers/common.go:84-101
func parsePagination(r *http.Request) (limit, offset int) {
	limit, _ = strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ = strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 { limit = 50 }
	if limit > 500 { limit = 500 }
	if offset < 0 { offset = 0 }
	return limit, offset
}
```
The activity handler has no `offset` concept (it passes only `limit` to
`ListRecentActivity`), and its default is 10, not 50 — so a straight swap to
`parsePagination` would change the default and add an unused offset. Prefer a
minimal clamp that preserves the default of 10 (see Step 1).

## Commands you will need

| Purpose | Command                                             | Expected |
|---------|-----------------------------------------------------|----------|
| Build   | `cd backend && go build ./...`                      | exit 0   |
| Vet     | `cd backend && go vet ./...`                        | exit 0   |
| Tests   | `cd backend && go test ./internal/api/handlers/ -run Activity` | pass |

## Scope

**In scope**:
- `backend/internal/api/handlers/activity.go`
- `backend/internal/api/handlers/activity_test.go` (extend; create if absent)

**Out of scope**:
- `common.go` `parsePagination` — do not change the shared helper.
- The activity service/repo query — the cap belongs at the handler boundary.

## Git workflow

- Branch: `advisor/027-activity-limit-cap`
- Conventional commit: `fix(activity): cap feed limit to prevent unbounded fetch`.

## Steps

### Step 1: Clamp the limit

Add an upper bound after the `> 0` check, preserving the default of 10 and using
the same ceiling as the rest of the API (500), or a smaller feed-appropriate cap
(e.g. 100). Match the repo's convention — the codebase's shared ceiling is 500,
so use 500 unless the activity feed has a reason to be smaller (it doesn't
obviously). Concretely:

```go
limit := 10
if l := r.URL.Query().Get("limit"); l != "" {
	if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
		limit = parsed
	}
}
if limit > 500 { limit = 500 }
```

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 2: Test

Extend `activity_test.go` (model on existing handler tests in
`backend/internal/api/handlers/*_test.go`). Add a case: request with
`limit=10000000` results in the service being called with `limit == 500` (assert
via the mocked service's captured argument, or assert the response is bounded).
Keep an existing happy-path case for the default.

**Verify**: `cd backend && go test ./internal/api/handlers/ -run Activity -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "limit > 500\|limit > 100" backend/internal/api/handlers/activity.go` → present
- [ ] `cd backend && go test ./internal/api/handlers/ -run Activity` passes, including the over-cap case
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The activity handler no longer matches the excerpt (drift), or the service
  signature has changed to take a pagination struct — then align with the new
  shape and note it.

## Maintenance notes

- If activity later gains offset-based pagination, migrate it to
  `parsePagination` wholesale and drop this ad-hoc clamp.
- Reviewer: confirm the default of 10 is preserved and only the ceiling is added.
