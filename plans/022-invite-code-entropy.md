# Plan 022: Invite codes have enough entropy to resist enumeration

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat eca86757..HEAD -- backend/internal/services/invite_code.go backend/internal/services/group_service.go`
> If either changed since this plan, compare the excerpts below to the live code
> before proceeding; on mismatch, STOP. Note: the excerpts below were refreshed
> against the 2026-07-04 working tree (which carries uncommitted Batch-2 work in
> `group_service.go` — the `WithTx`/`ClaimInvite` join path from plan 031). If
> that work has since been committed, the committed code should match the
> excerpts; if `JoinGroup` still uses a non-transactional `ConsumeInvite` path,
> you are on a stale tree — STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8aec2a1e`, 2026-07-03
- **Refreshed at**: commit `eca86757` + uncommitted Batch-2 working tree,
  2026-07-04 reconcile. A first execution attempt STOPPED on the Step 2
  condition (case-sensitive compare with no server-side normalization). The
  advisor investigated: the bug is real but latent (all Flutter clients
  `trim().toUpperCase()` before sending; raw API callers hit it), and the fix
  is one line — so it is now **in scope** as Step 2 rather than a STOP. The
  other former STOP (DB column width) is resolved: `group_invites.code` is
  `TEXT` (`backend/migrations/000001_init_schema.up.sql:84`), no width limit.
  No partial work from the first attempt survives; the tree is clean.

## Why this matters

Group invite codes are `ADJ-NOUN-##` drawn from 20 adjectives × 20 nouns × 100
two-digit numbers = **40,000** possibilities. `JoinGroup` accepts any valid,
unused, unexpired code and adds the caller to that group, rate-limited only by a
generous per-user 1000/hour limiter. An authenticated attacker can therefore
enumerate the entire keyspace in roughly 40 hours from one account and join every
group with a live invite — reading its lists, finances, chores, and pinwall. The
friendly word format is fine for display; the fix is to make guessing
computationally pointless by adding real entropy (and, secondarily, to make
brute force expensive with a failed-join limiter).

## Current state

```go
// backend/internal/services/invite_code.go:10-30
func generatePlayfulInviteCode() (string, error) {
	adj, err := pickOne(inviteAdjectives)   // 20 entries
	...
	noun, err := pickOne(inviteNouns)       // 20 entries
	...
	num, err := cryptoRandInt(0, 99)        // 100 values
	...
	code := fmt.Sprintf("%s-%s-%02d", adj, noun, num)
	return strings.ToUpper(code), nil
}
```
Wordlists: `inviteAdjectives` and `inviteNouns` at `invite_code.go:55-99`
(confirm the exact counts with `grep -c '"' ...` if needed). `cryptoRandInt`
already uses `crypto/rand` — the RNG is fine; the keyspace is the problem.

```go
// backend/internal/services/group_service.go:208-247  (JoinGroup, post-plan-031)
func (s *GroupService) JoinGroup(ctx context.Context, userID uuid.UUID, code string) (*models.Group, error) {
	invite, err := s.groupRepo.GetInviteByCode(ctx, code)  // ← raw, un-normalized
	...
	if invite.UsedBy != nil { return ... "invite already used" }
	if time.Now().UTC().After(invite.ExpiresAt) { return ... "invite expired" }
	existing, _ := s.groupRepo.GetMembership(ctx, invite.GroupID, userID)
	if existing != nil { return ... }
	// WithTx: ClaimInvite (conditional single-use) + CreateMembership
```

The case-sensitivity gap, confirmed 2026-07-04: the generator uppercases
(`invite_code.go:29` `strings.ToUpper`), the repo compares exactly
(`group_repo.go:215` `WHERE code = $1`), and neither the handler
(`backend/internal/api/handlers/group.go:203-218` — passes `req.Code` raw) nor
the service normalizes. Shipped Flutter clients all `trim().toUpperCase()`
before sending (e.g. `frontend/lib/sheets/join_household_sheet.dart:112`,
`frontend/lib/screens/auth/join_landing_screen.dart:50`), so today this only
bites raw API callers — but the server must not depend on client behavior.
Step 2 fixes it here.

The only brute-force cost today is the per-user `UserRateLimit` middleware
(`backend/cmd/api/main.go:127`), which is 1000/hr and not join-specific.

## Commands you will need

| Purpose | Command                                     | Expected |
|---------|---------------------------------------------|----------|
| Build   | `cd backend && go build ./...`              | exit 0   |
| Vet     | `cd backend && go vet ./...`                | exit 0   |
| Tests   | `cd backend && go test ./internal/services/`| all pass |

## Scope

**In scope**:
- `backend/internal/services/invite_code.go`
- `backend/internal/services/invite_code_test.go` (create if absent; else extend)
- `backend/internal/services/group_service.go` (Step 2 only: normalize `code` at
  the top of `JoinGroup` — one line plus the `strings` import if absent)
- `backend/internal/services/group_service_test.go` (one case: lowercase input
  joins successfully)

**Out of scope** (do NOT touch in this plan):
- Existing invite rows in the DB — pre-release app; old short codes can stay
  valid until they expire. No data migration.
- The rate-limiter wiring in `main.go` — a per-code/IP failed-join limiter is a
  worthwhile follow-up but is deferred to keep this plan low-risk (noted in
  Maintenance). Do not add middleware here.

## Git workflow

- Branch: `advisor/022-invite-code-entropy`
- Conventional commit: `fix(groups): raise invite-code entropy to resist enumeration`.

## Steps

### Step 1: Append a high-entropy suffix to the code

Keep the human-friendly `ADJ-NOUN` prefix for readability, but append a
crypto-random suffix that dominates the keyspace. Target ≥ 2^60 possibilities.
Use an unambiguous base32 alphabet (no `0/O/1/I`) and 8 characters (32^8 ≈
2^40 per 8 chars; use enough chars to clear 2^60 — e.g. 12 chars ≈ 2^60, or keep
the two words as extra entropy and add 10 chars). Concretely, replace the
2-digit number with a `randToken(n)` helper backed by `crypto/rand`:

```go
const inviteAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // no 0/O/1/I/L

func randToken(n int) (string, error) {
	b := make([]byte, n)
	for i := range b {
		idx, err := cryptoRandInt(0, len(inviteAlphabet)-1)
		if err != nil { return "", err }
		b[i] = inviteAlphabet[idx]
	}
	return string(b), nil
}
```
Then `code := fmt.Sprintf("%s-%s-%s", adj, noun, token)` with a token length that
clears the target (document the exact bits in a comment). Uppercasing is fine;
ensure the alphabet stays collision-free after `strings.ToUpper`.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Normalize invite-code input in `JoinGroup`

Confirmed during reconcile (see Current state): stored codes are uppercase, the
SQL compare is exact, and nothing server-side normalizes user input. Fix it at
the service boundary so every caller benefits. At the top of `JoinGroup` in
`backend/internal/services/group_service.go` (before `GetInviteByCode`):

```go
code = strings.ToUpper(strings.TrimSpace(code))
```

Do not change the handler, the repo query, or stored data — one normalization
point, at the service, is the whole fix. Add one test case to
`group_service_test.go` following its existing `JoinGroup` table entries
(`group_service_test.go:161` mocks `GetInviteByCode` with an exact string): the
service is called with a lowercase/whitespace-padded code and the mock expects
the uppercased trimmed form.

**Verify**: `cd backend && go test ./internal/services/` → all pass.

### Step 3: Tests

Add/extend `backend/internal/services/invite_code_test.go`:
- Generated code matches the expected shape `^[A-Z]+-[A-Z]+-[A-Z2-9]{N}$`.
- 10,000 generated codes have no duplicate (probabilistic uniqueness sanity).
- The token portion draws only from the intended alphabet.

Model the test file on any existing `backend/internal/services/*_test.go` for
table structure and assertions.

**Verify**: `cd backend && go test ./internal/services/ -run Invite -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "cryptoRandInt(0, 99)" backend/internal/services/invite_code.go` → no matches (the 2-digit number is gone)
- [ ] `grep -n "crypto/rand" backend/internal/services/invite_code.go` → present (entropy source unchanged)
- [ ] New/extended invite tests pass; `go test ./internal/services/ -run Invite` passes
- [ ] The code comment states the achieved entropy in bits (≥ 60)
- [ ] `grep -n "strings.ToUpper(strings.TrimSpace(code))" backend/internal/services/group_service.go` → one match, inside `JoinGroup`
- [ ] A `JoinGroup` test case passes a lowercase/padded code and succeeds
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `JoinGroup` in the tree you are working on does not use the
  `WithTx`/`ClaimInvite` transactional path — you are on a tree that predates
  plan 031's landing; report rather than resolve the conflict yourself.
- Anything beyond the one normalization line seems needed in
  `group_service.go` — scope creep signal; report instead.

Resolved (do not re-raise): the DB column is `TEXT` with no width constraint
(`backend/migrations/000001_init_schema.up.sql:84`), so the longer code fits;
the case-sensitivity finding is now Step 2 of this plan.

## Maintenance notes

- Follow-up (deferred, worth doing): add a failed-join rate limiter keyed on
  IP+user with exponential backoff around `JoinGroup`, so even a larger keyspace
  isn't cheaply probed. Left out here to keep the change low-risk and
  migration-free.
- Reviewer: confirm the new alphabet has no ambiguous characters and the entropy
  math in the comment is correct.
