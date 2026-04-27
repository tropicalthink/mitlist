package models

import (
	"time"

	"github.com/google/uuid"
)

// List represents a list within a group.
type List struct {
	ID          uuid.UUID `json:"id"`
	GroupID     uuid.UUID `json:"group_id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	ItemPreview []string  `json:"item_preview,omitempty"`
}

// ListItem represents an item within a list.
type ListItem struct {
	ID        uuid.UUID  `json:"id"`
	ListID    uuid.UUID  `json:"list_id"`
	Name      string     `json:"name"`
	Quantity  float64    `json:"quantity"`
	Unit      string     `json:"unit"`
	Note      string     `json:"note,omitempty"`
	ProductID *uuid.UUID `json:"product_id,omitempty"`
	StoreID   *uuid.UUID `json:"store_id,omitempty"`
	Checked   bool       `json:"checked"`
	Position  int        `json:"position"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
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
