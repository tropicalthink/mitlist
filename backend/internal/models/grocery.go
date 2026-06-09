package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// CanonicalItem is the language-neutral grocery node. Display names are
// per-language; IsGlobal marks shipped base taxonomy vs household-created.
type CanonicalItem struct {
	ID          uuid.UUID  `json:"id"`
	GroupID     uuid.UUID  `json:"group_id"`
	NameDe      string     `json:"name_de"`
	NameEn      string     `json:"name_en"`
	Category    string     `json:"category"`
	DefaultUnit string     `json:"default_unit"`
	ProductID   *uuid.UUID `json:"product_id,omitempty"`
	IsGlobal    bool       `json:"is_global"`
	Version     int64      `json:"version"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	DeletedAt   *time.Time `json:"deleted_at,omitempty"`
}

// ItemAlias maps a normalized shorthand/spelling/OCR form to a canonical item.
// This is the hot lookup path that makes a confirmed correction "stick".
type ItemAlias struct {
	ID              uuid.UUID  `json:"id"`
	GroupID         uuid.UUID  `json:"group_id"`
	CanonicalItemID uuid.UUID  `json:"canonical_item_id"`
	AliasText       string     `json:"alias_text"`
	Lang            string     `json:"lang"`
	Source          string     `json:"source"`
	Weight          int        `json:"weight"`
	Version         int64      `json:"version"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at,omitempty"`
}

// Correction is a unified, append-only correction event. Never updated; a
// materializer projects confirmed corrections into ItemAlias / StoreAisle.
type Correction struct {
	ID                      uuid.UUID       `json:"id"`
	GroupID                 uuid.UUID       `json:"group_id"`
	UserID                  *uuid.UUID      `json:"user_id,omitempty"`
	Scope                   string          `json:"scope"`
	Kind                    string          `json:"kind"`
	RawText                 string          `json:"raw_text"`
	ResolvedCanonicalItemID *uuid.UUID      `json:"resolved_canonical_item_id,omitempty"`
	CorrectedValue          json.RawMessage `json:"corrected_value,omitempty"`
	Source                  string          `json:"source"`
	Version                 int64           `json:"version"`
	CreatedAt               time.Time       `json:"created_at"`
	AppliedAt               *time.Time      `json:"applied_at,omitempty"`
}

// StoreAisle places a canonical item in an aisle for a specific store.
type StoreAisle struct {
	ID              uuid.UUID  `json:"id"`
	GroupID         uuid.UUID  `json:"group_id"`
	StoreID         *uuid.UUID `json:"store_id,omitempty"`
	CanonicalItemID uuid.UUID  `json:"canonical_item_id"`
	Aisle           string     `json:"aisle"`
	SortOrder       int        `json:"sort_order"`
	Confidence      float64    `json:"confidence"`
	Version         int64      `json:"version"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	DeletedAt       *time.Time `json:"deleted_at,omitempty"`
}

// PurchaseHistory is an append-only buy signal feeding suggestions.
type PurchaseHistory struct {
	ID              uuid.UUID  `json:"id"`
	GroupID         uuid.UUID  `json:"group_id"`
	CanonicalItemID *uuid.UUID `json:"canonical_item_id,omitempty"`
	ListItemID      *uuid.UUID `json:"list_item_id,omitempty"`
	Quantity        float64    `json:"quantity"`
	Unit            string     `json:"unit"`
	Version         int64      `json:"version"`
	PurchasedAt     time.Time  `json:"purchased_at"`
}

// ItemCooccurrence is the "bought together" matrix for suggestions.
type ItemCooccurrence struct {
	GroupID    uuid.UUID `json:"group_id"`
	ItemAID    uuid.UUID `json:"item_a_id"`
	ItemBID    uuid.UUID `json:"item_b_id"`
	Count      int       `json:"count"`
	LastSeenAt time.Time `json:"last_seen_at"`
	Version    int64     `json:"version"`
}

// ScanArtifact is scan provenance + retraining corpus. Raw images are uploaded
// only on explicit user consent (ImageRef may be a local-only path).
type ScanArtifact struct {
	ID           uuid.UUID       `json:"id"`
	GroupID      uuid.UUID       `json:"group_id"`
	UserID       *uuid.UUID      `json:"user_id,omitempty"`
	ImageRef     string          `json:"image_ref"`
	Engine       string          `json:"engine"`
	RawJSON      json.RawMessage `json:"raw_json,omitempty"`
	ResolvedJSON json.RawMessage `json:"resolved_json,omitempty"`
	Version      int64           `json:"version"`
	CreatedAt    time.Time       `json:"created_at"`
	SyncedAt     *time.Time      `json:"synced_at,omitempty"`
}

// GroceryGraphDelta is the payload returned by GET /grocery/graph?since_version=N.
// It carries all rows (including tombstones) changed past the client's cursor,
// plus the new max version the client should store.
type GroceryGraphDelta struct {
	MaxVersion       int64              `json:"max_version"`
	CanonicalItems   []CanonicalItem    `json:"canonical_items"`
	ItemAliases      []ItemAlias        `json:"item_aliases"`
	Corrections      []Correction       `json:"corrections"`
	StoreAisles      []StoreAisle       `json:"store_aisles"`
	PurchaseHistory  []PurchaseHistory  `json:"purchase_history"`
	ItemCooccurrence []ItemCooccurrence `json:"item_cooccurrence"`
}
