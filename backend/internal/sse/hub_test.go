package sse

import (
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ── helpers ──────────────────────────────────────────────────────────────────

// recvBytes reads one encoded event from ch within timeout, failing the test on timeout.
func recvBytes(t *testing.T, ch chan []byte, timeout time.Duration) []byte {
	t.Helper()
	select {
	case data, ok := <-ch:
		require.True(t, ok, "channel closed unexpectedly")
		return data
	case <-time.After(timeout):
		t.Fatal("timed out waiting for event")
		return nil
	}
}

// recv reads and decodes one event from ch within timeout.
func recv(t *testing.T, ch chan []byte, timeout time.Duration) Event {
	t.Helper()
	data := recvBytes(t, ch, timeout)
	var evt Event
	require.NoError(t, json.Unmarshal(data, &evt))
	return evt
}

// sortedStringSlice converts a []string into a map-set for order-agnostic comparison.
func toSet(ss []string) map[string]struct{} {
	m := make(map[string]struct{}, len(ss))
	for _, s := range ss {
		m[s] = struct{}{}
	}
	return m
}

// ── Step 1: Basic publish / subscribe ────────────────────────────────────────

// TestPublishDelivers verifies that a Publish reaches a subscribed channel.
func TestPublishDelivers(t *testing.T) {
	h := New()
	ch := h.Subscribe("g", "u1")

	want := Event{Type: "x", GroupID: "g"}
	h.Publish("g", want)

	got := recv(t, ch, time.Second)
	assert.Equal(t, want.Type, got.Type)
	assert.Equal(t, want.GroupID, got.GroupID)
}

func TestPublishDeliversSameEncodedBytesToSubscribers(t *testing.T) {
	h := New()
	ch1 := h.Subscribe("g", "u1")
	ch2 := h.Subscribe("g", "u2")

	want := Event{
		Type:    "pinwall:post_created",
		GroupID: "g",
		Payload: json.RawMessage(`{"id":"p1","text":"hello"}`),
	}
	h.Publish("g", want)

	data1 := recvBytes(t, ch1, time.Second)
	data2 := recvBytes(t, ch2, time.Second)
	require.Equal(t, data1, data2)

	var got Event
	require.NoError(t, json.Unmarshal(data1, &got))
	assert.Equal(t, want.Type, got.Type)
	assert.Equal(t, want.GroupID, got.GroupID)
	assert.JSONEq(t, string(want.Payload), string(got.Payload))
}

// TestPublishEmptyGroupNoPanic verifies that publishing to a group with no
// subscribers neither panics nor blocks.
func TestPublishEmptyGroupNoPanic(t *testing.T) {
	h := New()
	done := make(chan struct{})
	go func() {
		defer close(done)
		h.Publish("no-such-group", Event{Type: "x", GroupID: "no-such-group"})
	}()
	select {
	case <-done:
		// good
	case <-time.After(time.Second):
		t.Fatal("Publish to empty group blocked")
	}
}

// TestUnsubscribeClosesChannelAndCleansUp verifies that Unsubscribe:
//   - closes the channel (receive returns ok==false after drain)
//   - removes the group key from h.clients when the last subscriber leaves
func TestUnsubscribeClosesChannelAndCleansUp(t *testing.T) {
	h := New()
	ch := h.Subscribe("g", "u1")

	h.Unsubscribe("g", ch)

	// Drain any buffered events, then confirm closed.
	drained := false
	for {
		_, ok := <-ch
		if !ok {
			drained = true
			break
		}
	}
	assert.True(t, drained, "channel should be closed after Unsubscribe")

	// White-box: group key must be gone.
	h.mu.RLock()
	_, exists := h.clients["g"]
	h.mu.RUnlock()
	assert.False(t, exists, "group key should be removed when last subscriber leaves")
}

// ── Step 2: Non-blocking drop behavior ───────────────────────────────────────

const bufSize = 64

// TestPublishDropsWhenBufferFull verifies that publishing more than bufSize
// events never blocks, and that draining yields at most bufSize events.
func TestPublishDropsWhenBufferFull(t *testing.T) {
	h := New()
	ch := h.Subscribe("g", "u1")

	publishDone := make(chan struct{})
	go func() {
		defer close(publishDone)
		for i := 0; i < bufSize+10; i++ {
			h.Publish("g", Event{Type: "flood", GroupID: "g"})
		}
	}()

	select {
	case <-publishDone:
		// All publishes returned without blocking — good.
	case <-time.After(2 * time.Second):
		t.Fatal("Publish calls blocked (expected non-blocking drops)")
	}

	// Drain what arrived.
	count := 0
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				t.Fatal("channel unexpectedly closed")
			}
			count++
		default:
			goto drained
		}
	}
drained:
	assert.LessOrEqual(t, count, bufSize, "should receive at most bufSize events")
	assert.Greater(t, count, 0, "should receive at least some events")

	// Channel must still be usable (not closed).
	h.Publish("g", Event{Type: "after-flood", GroupID: "g"})
	got := recv(t, ch, time.Second)
	assert.Equal(t, "after-flood", got.Type)
}

// ── Step 3: Presence derivation ───────────────────────────────────────────────

// TestOnlineUserIDsDedupAndExcludesAnonymous verifies that OnlineUserIDs:
//   - deduplicates multiple connections with the same userID
//   - excludes empty-string (anonymous) user IDs
func TestOnlineUserIDsDedupAndExcludesAnonymous(t *testing.T) {
	h := New()

	h.Subscribe("g", "u1") // connection 1
	h.Subscribe("g", "u1") // connection 2 — same user, different channel
	h.Subscribe("g", "u2")
	h.Subscribe("g", "") // anonymous

	ids := h.OnlineUserIDs("g")
	require.Len(t, ids, 2, "should deduplicate u1 and exclude anonymous")
	assert.Equal(t, toSet([]string{"u1", "u2"}), toSet(ids))
}

// TestBroadcastPresenceShape verifies that BroadcastPresence emits an event
// with Type=="presence:state" and a Payload decodable as {"user_ids":[...]}.
func TestBroadcastPresenceShape(t *testing.T) {
	h := New()
	ch := h.Subscribe("g", "u1")

	h.BroadcastPresence("g")

	evt := recv(t, ch, time.Second)
	assert.Equal(t, "presence:state", evt.Type)
	assert.Equal(t, "g", evt.GroupID)

	var pld struct {
		UserIDs []string `json:"user_ids"`
	}
	err := json.Unmarshal(evt.Payload, &pld)
	require.NoError(t, err, "Payload must be valid JSON with user_ids field")
	assert.Equal(t, toSet([]string{"u1"}), toSet(pld.UserIDs))
}

// TestUnsubscribeUpdatesPresence verifies that after one of two same-group
// users unsubscribes, OnlineUserIDs drops that user (when they had only one
// connection).
func TestUnsubscribeUpdatesPresence(t *testing.T) {
	h := New()
	ch1 := h.Subscribe("g", "u1")
	h.Subscribe("g", "u2")

	// Confirm both are online.
	ids := h.OnlineUserIDs("g")
	require.Equal(t, toSet([]string{"u1", "u2"}), toSet(ids))

	// u1 disconnects.
	h.Unsubscribe("g", ch1)

	ids = h.OnlineUserIDs("g")
	assert.Equal(t, toSet([]string{"u2"}), toSet(ids), "u1 should be gone after unsubscribe")
}

// ── Step 3b: PresenceEvent builder ───────────────────────────────────────────

// TestPresenceEvent verifies that PresenceEvent returns an event with
// Type=="presence:state" and a Payload whose user_ids match OnlineUserIDs for
// the same group (order-agnostic). BroadcastPresence delegates to it, so the
// wire shape is defined in exactly one place.
func TestPresenceEvent(t *testing.T) {
	h := New()
	h.Subscribe("g", "u1")
	h.Subscribe("g", "u2")
	h.Subscribe("g", "u2") // duplicate — should be deduplicated
	h.Subscribe("g", "")   // anonymous — should be excluded

	ev, err := h.PresenceEvent("g")
	require.NoError(t, err)

	assert.Equal(t, "presence:state", ev.Type)
	assert.Equal(t, "g", ev.GroupID)

	var pld struct {
		UserIDs []string `json:"user_ids"`
	}
	require.NoError(t, json.Unmarshal(ev.Payload, &pld))

	wantIDs := h.OnlineUserIDs("g")
	assert.Equal(t, toSet(wantIDs), toSet(pld.UserIDs),
		"PresenceEvent user_ids must match OnlineUserIDs for the same group")
}

// ── Step 4: Concurrency / race test ──────────────────────────────────────────

// TestConcurrencyRace stresses subscribe/publish/unsubscribe concurrently to
// surface data races and "send on closed channel" panics.
// Run with: go test -race ./internal/sse/...
func TestConcurrencyRace(t *testing.T) {
	h := New()

	const (
		subWorkers = 20
		iterations = 200
		pubWorkers = 4
		deadline   = 10 * time.Second
	)

	ctx := make(chan struct{})
	go func() {
		time.Sleep(deadline)
		close(ctx)
	}()

	var wg sync.WaitGroup

	// Subscriber goroutines: each repeatedly subscribes, drains a few, unsubscribes.
	for i := 0; i < subWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				select {
				case <-ctx:
					return
				default:
				}
				ch := h.Subscribe("g", "user")
				// Drain up to a few events (non-blocking).
				for k := 0; k < 3; k++ {
					select {
					case <-ch:
					default:
					}
				}
				h.Unsubscribe("g", ch)
			}
		}()
	}

	// Publisher goroutines: hammer Publish and BroadcastPresence.
	for i := 0; i < pubWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations*subWorkers/pubWorkers; j++ {
				select {
				case <-ctx:
					return
				default:
				}
				h.Publish("g", Event{Type: "stress", GroupID: "g"})
				if j%10 == 0 {
					h.BroadcastPresence("g")
				}
			}
		}()
	}

	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		// Completed within deadline — good.
	case <-ctx:
		t.Fatal("concurrency test exceeded deadline")
	}
}
