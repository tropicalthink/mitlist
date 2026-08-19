package services

import (
	"encoding/json"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/sse"
)

// publishDomainEvent is the common service-side event boundary. Domain events
// intentionally carry identifiers only: consumers can fetch the current
// representation using their existing authorization, and private fields are
// never copied into a long-lived event stream.
func publishDomainEvent(hub *sse.Hub, eventType string, groupID uuid.UUID, payload map[string]string) {
	if hub == nil || groupID == uuid.Nil {
		return
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	hub.Publish(groupID.String(), sse.Event{
		Type:    eventType,
		GroupID: groupID.String(),
		Payload: data,
	})
}
