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

// Hub manages per-group SSE client channels.
type Hub struct {
	mu      sync.RWMutex
	clients map[string]map[chan Event]struct{} // groupID -> set of client channels
}

// New creates a ready-to-use Hub.
func New() *Hub {
	return &Hub{
		clients: make(map[string]map[chan Event]struct{}),
	}
}

// Subscribe registers a buffered channel for events on groupID.
// The caller must call Unsubscribe when done to avoid leaks.
func (h *Hub) Subscribe(groupID string) chan Event {
	ch := make(chan Event, 64)
	h.mu.Lock()
	if h.clients[groupID] == nil {
		h.clients[groupID] = make(map[chan Event]struct{})
	}
	h.clients[groupID][ch] = struct{}{}
	h.mu.Unlock()
	return ch
}

// Unsubscribe removes and closes a client channel.
func (h *Hub) Unsubscribe(groupID string, ch chan Event) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if group, ok := h.clients[groupID]; ok {
		delete(group, ch)
		if len(group) == 0 {
			delete(h.clients, groupID)
		}
	}
	close(ch)
}

// Publish sends an event to every subscriber for groupID.
// Slow subscribers are skipped (channel full) to prevent head-of-line blocking.
func (h *Hub) Publish(groupID string, event Event) {
	h.mu.RLock()
	group := h.clients[groupID]
	h.mu.RUnlock()

	for ch := range group {
		select {
		case ch <- event:
		default:
		}
	}
}
