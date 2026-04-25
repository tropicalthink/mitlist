package models

import (
	"time"

	"github.com/google/uuid"
)

// List represents a list within a group.
type List struct {
	ID        uuid.UUID `json:"id"`
	GroupID   uuid.UUID `json:"group_id"`
	Name      string    `json:"name"`
	Type      string    `json:"type"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ListItem represents an item within a list.
type ListItem struct {
	ID        uuid.UUID `json:"id"`
	ListID    uuid.UUID `json:"list_id"`
	Name      string    `json:"name"`
	Quantity  int       `json:"quantity"`
	Unit      string    `json:"unit"`
	Checked   bool      `json:"checked"`
	Position  int       `json:"position"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
