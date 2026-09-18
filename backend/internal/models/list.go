package models

import (
	"time"

	"github.com/google/uuid"
)

// List represents a list within a group.
type List struct {
	ID         uuid.UUID  `json:"id"`
	GroupID    uuid.UUID  `json:"group_id"`
	Name       string     `json:"name"`
	Type       string     `json:"type"`
	ArchivedAt *time.Time `json:"archived_at,omitempty"`
	// RemindAt schedules a one-time household reminder about this list.
	// ReminderSentAt is set once the reminder job delivered it; changing
	// RemindAt clears it so the new time fires again.
	RemindAt       *time.Time `json:"remind_at,omitempty"`
	ReminderSentAt *time.Time `json:"reminder_sent_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	ItemPreview    []string   `json:"item_preview,omitempty"`
}

// ListItem represents an item within a list.
type ListItem struct {
	ID              uuid.UUID  `json:"id"`
	ListID          uuid.UUID  `json:"list_id"`
	Name            string     `json:"name"`
	Quantity        float64    `json:"quantity"`
	Unit            string     `json:"unit"`
	Note            string     `json:"note,omitempty"`
	PriceCents      *int       `json:"price_cents,omitempty"`
	ProductID       *uuid.UUID `json:"product_id,omitempty"`
	StoreID         *uuid.UUID `json:"store_id,omitempty"`
	CanonicalItemID *uuid.UUID `json:"canonical_item_id,omitempty"`
	AddedBy         *uuid.UUID `json:"added_by,omitempty"`
	ClaimedBy       *uuid.UUID `json:"claimed_by,omitempty"`
	ClaimedAt       *time.Time `json:"claimed_at,omitempty"`
	Checked         bool       `json:"checked"`
	Position        int        `json:"position"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type ShoppingLocation struct {
	ID        uuid.UUID `json:"id"`
	GroupID   uuid.UUID `json:"group_id"`
	Name      string    `json:"name"`
	SortOrder int       `json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Product struct {
	ID        uuid.UUID  `json:"id"`
	GroupID   uuid.UUID  `json:"group_id"`
	Name      string     `json:"name"`
	Barcode   string     `json:"barcode,omitempty"`
	Unit      string     `json:"unit,omitempty"`
	StoreID   *uuid.UUID `json:"store_id,omitempty"`
	MinStock  float64    `json:"min_stock"`
	InStock   float64    `json:"in_stock"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}
