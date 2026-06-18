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
	clients map[string]map[chan Event]string // groupID -> (client channel -> userID)
}

// New creates a ready-to-use Hub.
func New() *Hub {
	return &Hub{
		clients: make(map[string]map[chan Event]string),
	}
}

// Subscribe registers a buffered channel for events on groupID, owned by userID.
// userID may be empty for anonymous connections; it only affects presence.
// The caller must call Unsubscribe when done to avoid leaks.
func (h *Hub) Subscribe(groupID, userID string) chan Event {
	ch := make(chan Event, 64)
	h.mu.Lock()
	if h.clients[groupID] == nil {
		h.clients[groupID] = make(map[chan Event]string)
	}
	h.clients[groupID][ch] = userID
	h.mu.Unlock()
	return ch
}

// Unsubscribe removes and closes a client channel.
func (h *Hub) Unsubscribe(groupID string, ch chan Event) {
	h.mu.Lock()
	if group, ok := h.clients[groupID]; ok {
		delete(group, ch)
		if len(group) == 0 {
			delete(h.clients, groupID)
		}
	}
	h.mu.Unlock()
	close(ch)
}

// Publish sends an event to every subscriber for groupID.
// Slow subscribers are skipped (channel full) to prevent head-of-line blocking.
//
// The read lock is held across the send loop so a concurrent Unsubscribe cannot
// close a channel mid-send (which would panic). Sends are non-blocking, so the
// lock is held only briefly.
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

// OnlineUserIDs returns the distinct set of user IDs with at least one active
// connection to groupID. Order is not guaranteed.
func (h *Hub) OnlineUserIDs(groupID string) []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	seen := make(map[string]struct{})
	for _, uid := range h.clients[groupID] {
		if uid != "" {
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
