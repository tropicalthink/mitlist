# Plan 025: SSE broadcasts serialize each event once, not once per client

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/sse/hub.go backend/internal/api/handlers/sse.go`
> On any change, compare the excerpts below to live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

The SSE hub fans one `Event` struct out to all N subscriber channels, and each
subscriber goroutine independently runs `json.Marshal(event)` on it. So a single
broadcast to a group with N live viewers does N identical marshals. On a busy
board (presence ticks every 25s plus every post/chore/expense mutation) this is
O(clients) wasted CPU and allocations per event, across every group. Marshalling
once at the publish boundary makes broadcast cost O(1) in serialization.

## Current state

The hub already stores the per-event `Payload` as `json.RawMessage` (so the inner
payload isn't re-encoded), but the **outer** `{type, group_id, payload}` wrapper
is re-marshalled per client in the handler:

```go
// backend/internal/sse/hub.go:8-13
type Event struct {
	Type    string          `json:"type"`
	GroupID string          `json:"group_id"`
	Payload json.RawMessage `json:"payload"`
}

// hub.go:61-70  (Publish fans the struct out unchanged)
func (h *Hub) Publish(groupID string, event Event) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for ch := range h.clients[groupID] {
		select {
		case ch <- event:
		default:
		}
	}
}
```

```go
// backend/internal/api/handlers/sse.go:151-161  (per-client marshal)
case event, open := <-ch:
	if !open { return }
	data, err := json.Marshal(event)   // ← runs once PER client PER event
	if err != nil { continue }
	if !write(fmt.Sprintf("data: %s\n\n", data)) { return }
```
The periodic presence tick at `sse.go:135-140` also marshals per connection, but
that is one marshal per connection per 25s tick (inherent to per-connection
keep-alive) — the broadcast path (above) is the real duplication.

## Commands you will need

| Purpose | Command                                | Expected |
|---------|----------------------------------------|----------|
| Build   | `cd backend && go build ./...`         | exit 0   |
| Vet     | `cd backend && go vet ./...`           | exit 0   |
| Tests   | `cd backend && go test ./internal/sse/ ./internal/api/handlers/` | all pass |

## Scope

**In scope**:
- `backend/internal/sse/hub.go`
- `backend/internal/api/handlers/sse.go`
- `backend/internal/sse/hub_test.go` (extend or create)

**Out of scope**:
- The per-connection presence keep-alive marshal at `sse.go:135-140` — leave it;
  it is not the O(clients) path.
- Changing the wire format — the bytes sent to clients must be byte-identical.

## Git workflow

- Branch: `advisor/025-sse-marshal-once`
- Conventional commit: `perf(sse): marshal broadcast events once at publish`.

## Steps

### Step 1: Carry pre-encoded bytes through the channel

Two viable shapes — pick the one that touches least code:

**Option A (recommended): pre-encode in `Publish`.** Change the client channel
element type from `Event` to `[]byte` (the full `data: ...` line, or just the
marshalled event JSON). Marshal once at the top of `Publish` and send the same
byte slice to every channel. The handler then writes the bytes directly with no
marshal. This requires changing `chan Event` → `chan []byte` in the Hub map,
`Subscribe`, `Unsubscribe`, and the handler's receive.

**Option B (smaller diff): add a pre-marshalled field.** Keep `Event` but add an
unexported `encoded []byte`; populate it once in `Publish` before the fan-out;
the handler writes `event.encoded` if non-nil, else falls back to marshalling.

Prefer Option A — it makes the "encode once" invariant structural. Whichever you
pick, the `PresenceEvent`/`BroadcastPresence` path (`hub.go:93-110`) must produce
the same encoded bytes it does today.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 2: Handler writes pre-encoded bytes

In `sse.go`, the broadcast `case event, open := <-ch:` branch writes the
pre-encoded bytes (`data: %s\n\n` with the bytes) and no longer calls
`json.Marshal`. Keep the closed-channel check.

**Verify**: `grep -n "json.Marshal(event)" backend/internal/api/handlers/sse.go`
→ no matches on the broadcast path.

### Step 3: Tests

Extend `backend/internal/sse/hub_test.go` (or create it) to assert that a single
`Publish` delivers the same bytes to two subscribers and that the decoded event
round-trips to the original `{type, group_id, payload}`. If a hub test file does
not exist, model it on any `backend/internal/**/*_test.go` using the standard
library `testing` package.

**Verify**: `cd backend && go test ./internal/sse/ -run . -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "json.Marshal(event)" backend/internal/api/handlers/sse.go` → no matches (broadcast path no longer per-client marshals)
- [ ] `cd backend && go test ./internal/sse/ ./internal/api/handlers/` all pass
- [ ] The wire bytes are unchanged (a decode round-trip test passes)
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `Event` or its channel type is referenced by code outside `sse/` and the
  handler (grep `chan Event` and `sse.Event` across `backend/`) in a way that a
  type change would break widely — then prefer Option B and report the callers.
- A handler test asserts on the marshalled shape in a way the change breaks —
  reconcile the expected bytes, do not weaken the assertion.

## Maintenance notes

- If a future event type needs per-client personalization (e.g. per-user
  payloads), the "encode once" invariant breaks for that type — handle it as a
  separate non-broadcast path rather than reverting this.
- Reviewer: confirm byte-for-byte wire parity and that the slow-consumer
  non-blocking send semantics are preserved.
