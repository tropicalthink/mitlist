package services

import (
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/sse"
)

func TestPublishDomainEventUsesScopedMinimalPayload(t *testing.T) {
	hub := sse.New()
	groupID := uuid.New()
	entityID := uuid.New()
	ch := hub.Subscribe(groupID.String(), "")
	defer hub.Unsubscribe(groupID.String(), ch)

	publishDomainEvent(hub, "expense:updated", groupID, map[string]string{"expense_id": entityID.String()})

	select {
	case raw := <-ch:
		var event sse.Event
		require.NoError(t, json.Unmarshal(raw, &event))
		require.Equal(t, "expense:updated", event.Type)
		require.Equal(t, groupID.String(), event.GroupID)
		var payload map[string]string
		require.NoError(t, json.Unmarshal(event.Payload, &payload))
		require.Equal(t, map[string]string{"expense_id": entityID.String()}, payload)
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for domain event")
	}
}

// recordedEvent is a published domain event, its payload decoded.
type recordedEvent struct {
	Type    string
	GroupID string
	Payload map[string]string
}

// recordEvents returns a hub to give a service and a function returning
// every event published on it so far, in order.
func recordEvents(t *testing.T) (*sse.Hub, func() []recordedEvent) {
	t.Helper()
	hub := sse.New()
	var mu sync.Mutex
	var events []recordedEvent
	hub.OnPublish(func(e sse.Event) {
		var payload map[string]string
		_ = json.Unmarshal(e.Payload, &payload)
		mu.Lock()
		defer mu.Unlock()
		events = append(events, recordedEvent{Type: e.Type, GroupID: e.GroupID, Payload: payload})
	})
	return hub, func() []recordedEvent {
		mu.Lock()
		defer mu.Unlock()
		return append([]recordedEvent(nil), events...)
	}
}

func eventTypes(events []recordedEvent) []string {
	types := make([]string, len(events))
	for i, e := range events {
		types[i] = e.Type
	}
	return types
}
