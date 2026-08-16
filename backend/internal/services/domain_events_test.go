package services

import (
	"encoding/json"
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
