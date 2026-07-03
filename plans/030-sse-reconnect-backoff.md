# Plan 030: The SSE client resets its backoff on connect and never busy-loops

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/services/sse_service.dart`
> On any change, compare the live code to the excerpt below first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (composes with Plan 020 if both land — see notes)
- **Category**: bug
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

The SSE reconnect loop grows its backoff on each failure but never resets it
after a successful connect, so after a long outage pushes backoff to its max
(~60s) the client stays at 60s forever — slow to recover live updates. Separately,
when the server closes the stream **gracefully** (no exception), the connect
function returns normally and the loop immediately re-enters with no delay,
producing a tight reconnect loop that hammers `/events` and drains battery. Both
are small state-machine fixes in one file.

## Current state

Read `frontend/lib/services/sse_service.dart` around the reconnect loop
(`_startLoop` / `_connectOnce`, roughly lines 83–160). The reported shape:

- `backoff` is a local that only grows; there is a comment near line 141 ("Reset
  backoff on successful connect") describing a reset that is **not implemented**.
- `_connectOnce` returns normally when the server closes the stream, so
  `_startLoop` re-enters with no delay (no exception path, no minimum sleep).

Confirm the exact variable names and structure by reading the file before
editing — the fix is behavioral, not line-exact.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test test/services/` | pass |

## Scope

**In scope**:
- `frontend/lib/services/sse_service.dart`
- `frontend/test/services/sse_service_test.dart` (create if feasible — see Test plan)

**Out of scope**:
- `token_refresh_coordinator.dart` — Plan 020 owns the auth-vs-transport
  distinction. If 020 has landed, honor its `transportError`/`authRejected`
  branches; if not, do not change the coordinator here.
- The backend SSE handler.

## Git workflow

- Branch: `advisor/030-sse-reconnect-backoff`
- Conventional commit: `fix(sse): reset backoff on connect and avoid busy reconnect`.

## Steps

### Step 1: Reset backoff after a successful connection

Where a connection is established (before entering the read loop, or immediately
after the stream yields its first event / opens), set `backoff` back to its
initial value. Implement the reset the existing comment promised.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 2: Enforce a minimum delay before reconnecting after a graceful close

When `_connectOnce` returns without an exception (server closed the stream), do
not immediately re-enter. Apply at least the initial backoff delay before the
next attempt (and still grow backoff for repeated failures). Ensure any `break`
on genuine auth failure (or Plan 020's `authRejected`) is preserved so a revoked
session does not reconnect forever.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Confirm cancellation still works

Make sure the loop still exits when the service is disposed / the group changes
(the existing cancellation path). A `Future.delayed` for the backoff must be
cancellable or short enough not to hang disposal.

**Verify**: `cd frontend && flutter test test/services/` → pass (no hang/timeout).

## Test plan

- If `sse_service.dart` can be unit-tested with an injected stream/clock, add
  `sse_service_test.dart` asserting: backoff returns to initial after a
  successful connect, and a graceful close waits ≥ the minimum delay before
  reconnecting. Model on any existing `frontend/test/services/*_test.dart`.
- If the service is not currently structured for injection (hard-coded Dio /
  timers), do NOT refactor it heavily just to test — verify via analyze + code
  review and note in the report that a unit test was not feasible without a
  refactor. State which it was.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] The backoff variable is reset to its initial value on a successful connect (visible in the diff)
- [ ] A minimum delay is applied before reconnecting after a non-exception return
- [ ] `cd frontend && flutter test test/services/` passes with no timeout
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The loop structure differs materially from the description (drift) — describe
  what you found before changing behavior.
- Making the backoff cancellable would require restructuring timer/stream
  ownership across other methods — report the blast radius first.

## Maintenance notes

- Composes with Plan 020: the transport-vs-auth distinction determines whether a
  failure should reconnect (transport) or break (auth). Keep both behaviors when
  both plans have landed.
- Reviewer: confirm disposal doesn't hang on a pending backoff delay.
