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
// publishListItemEvent is the "list:item_*" event every list item write
// publishes, for the services that write list items without ListService.
func publishListItemEvent(hub *sse.Hub, eventType string, groupID, listID, itemID uuid.UUID) {
	publishDomainEvent(hub, eventType, groupID, map[string]string{
		"list_id": listID.String(), "item_id": itemID.String(),
	})
}

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
