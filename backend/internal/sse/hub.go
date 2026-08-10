package sse

import (
	"encoding/json"
	"sync"
)

// Event is a message broadcast to SSE subscribers.
type Event struct {
	Type    string          `json:"type"`
	GroupID string          `json:"group_id"`
	Payload json.RawMessage `json:"payload"`
}

// Hub manages per-group SSE client channels and derives presence from them.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]map[chan []byte]client // groupID -> (client channel -> metadata)
	users   map[string]int                    // userID -> active connections
	ips     map[string]int                    // client IP -> active connections
	maxUser int
	maxIP   int
}

// These limits are deliberately small: an SSE stream is a long-lived
// connection, so a handful of streams is enough for a user while still
// preventing a single browser or address from exhausting the process.
const (
	DefaultMaxConnectionsPerUser = 8
	DefaultMaxConnectionsPerIP   = 32
)

type client struct {
	userID string
	ip     string
}

// New creates a ready-to-use Hub.
func New() *Hub {
	return &Hub{
		clients: make(map[string]map[chan []byte]client),
		users:   make(map[string]int),
		ips:     make(map[string]int),
		maxUser: DefaultMaxConnectionsPerUser,
		maxIP:   DefaultMaxConnectionsPerIP,
	}
}

// NewWithLimits creates a hub with explicit per-user and per-IP limits. A
// non-positive limit disables that dimension and is useful for trusted
// internal callers and focused tests.
func NewWithLimits(maxUser, maxIP int) *Hub {
	h := New()
	h.maxUser = maxUser
	h.maxIP = maxIP
	return h
}

// Subscribe registers a buffered channel for events on groupID, owned by userID.
// userID may be empty for anonymous connections; it only affects presence.
// The caller must call Unsubscribe when done to avoid leaks.
func (h *Hub) Subscribe(groupID, userID string) chan []byte {
	ch, _ := h.subscribe(groupID, userID, "", false)
	return ch
}

// TrySubscribe atomically checks and reserves a connection against the hub's
// per-user and per-IP limits. The returned boolean is false when either limit
// is exhausted. The caller must Unsubscribe an accepted channel exactly once.
func (h *Hub) TrySubscribe(groupID, userID, ip string) (chan []byte, bool) {
	return h.subscribe(groupID, userID, ip, true)
}

func (h *Hub) subscribe(groupID, userID, ip string, enforceLimits bool) (chan []byte, bool) {
	ch := make(chan []byte, 64)
	h.mu.Lock()
	if enforceLimits {
		if userID != "" && h.maxUser > 0 && h.users[userID] >= h.maxUser {
			h.mu.Unlock()
			return nil, false
		}
		if ip != "" && h.maxIP > 0 && h.ips[ip] >= h.maxIP {
			h.mu.Unlock()
			return nil, false
		}
	}
	if h.clients[groupID] == nil {
		h.clients[groupID] = make(map[chan []byte]client)
	}
	h.clients[groupID][ch] = client{userID: userID, ip: ip}
	if userID != "" {
		h.users[userID]++
	}
	if ip != "" {
		h.ips[ip]++
	}
	h.mu.Unlock()
	return ch, true
}

// Unsubscribe removes and closes a client channel.
func (h *Hub) Unsubscribe(groupID string, ch chan []byte) {
	h.mu.Lock()
	removed := false
	if group, ok := h.clients[groupID]; ok {
		if c, exists := group[ch]; exists {
			removed = true
			delete(group, ch)
			if c.userID != "" {
				h.users[c.userID]--
				if h.users[c.userID] <= 0 {
					delete(h.users, c.userID)
				}
			}
			if c.ip != "" {
				h.ips[c.ip]--
				if h.ips[c.ip] <= 0 {
					delete(h.ips, c.ip)
				}
			}
		}
		if len(group) == 0 {
			delete(h.clients, groupID)
		}
	}
	h.mu.Unlock()
	// Be idempotent. A handler can race request cancellation with a write
	// failure; only the goroutine that actually removed the channel may close
	// it, avoiding a double-close panic and leaked counters.
	if removed {
		close(ch)
	}
}

// Publish sends an event to every subscriber for groupID.
// Slow subscribers are skipped (channel full) to prevent head-of-line blocking.
//
// The read lock is held across the send loop so a concurrent Unsubscribe cannot
// close a channel mid-send (which would panic). Sends are non-blocking, so the
// lock is held only briefly.
func (h *Hub) Publish(groupID string, event Event) {
	data, err := json.Marshal(event)
	if err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()
	for ch := range h.clients[groupID] {
		select {
		case ch <- data:
		default:
		}
	}
}

// OnlineUserIDs returns the distinct set of user IDs with at least one active
// connection to groupID. Order is not guaranteed.
func (h *Hub) OnlineUserIDs(groupID string) []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	seen := make(map[string]struct{})
	for _, c := range h.clients[groupID] {
		if uid := c.userID; uid != "" {
			seen[uid] = struct{}{}
		}
	}
	ids := make([]string, 0, len(seen))
	for uid := range seen {
		ids = append(ids, uid)
	}
	return ids
}

// PresenceEvent builds the current "presence:state" event for groupID. It is
// the single source of truth for the presence wire shape ({"user_ids":[...]}),
// used both for broadcasting and for the per-connection re-sync in the handler.
func (h *Hub) PresenceEvent(groupID string) (Event, error) {
	payload, err := json.Marshal(map[string][]string{"user_ids": h.OnlineUserIDs(groupID)})
	if err != nil {
		return Event{}, err
	}
	return Event{Type: "presence:state", GroupID: groupID, Payload: payload}, nil
}

// BroadcastPresence publishes the current set of online user IDs to every
// subscriber of groupID as a `presence:state` event. Call it after a client
// subscribes or unsubscribes so every viewer sees who is currently on the board.
func (h *Hub) BroadcastPresence(groupID string) {
	ev, err := h.PresenceEvent(groupID)
	if err != nil {
		return
	}
	h.Publish(groupID, ev)
}
