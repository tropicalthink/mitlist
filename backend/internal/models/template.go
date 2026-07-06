package models

import (
	"time"

	"github.com/google/uuid"
)

// Template represents a reusable list template.
type Template struct {
	ID        uuid.UUID `json:"id"`
	GroupID   uuid.UUID `json:"group_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// TemplateItem represents an item within a list template.
type TemplateItem struct {
	ID         uuid.UUID `json:"id"`
	TemplateID uuid.UUID `json:"template_id"`
	Name       string    `json:"name"`
	Quantity   int       `json:"quantity"`
	Unit       string    `json:"unit"`
}

// ChoreTemplate represents a reusable chore template (a saved household routine).
type ChoreTemplate struct {
	ID             uuid.UUID `json:"id"`
	GroupID        uuid.UUID `json:"group_id"`
	Name           string    `json:"name"`
	Description    *string   `json:"description,omitempty"`
	RotationType   string    `json:"rotation_type"`
	Frequency      string    `json:"frequency"`
	PeriodInterval int       `json:"period_interval"`
	PeriodConfig   []string  `json:"period_config,omitempty"`
	TrackDateOnly  bool      `json:"track_date_only"`
	Rollover       bool      `json:"rollover"`
	AssignmentType string    `json:"assignment_type"`
	Category       *string   `json:"category,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// ChoreTemplateItem represents an item within a chore template.
type ChoreTemplateItem struct {
	ID              uuid.UUID `json:"id"`
	ChoreTemplateID uuid.UUID `json:"chore_template_id"`
	Name            string    `json:"name"`
	Description     *string   `json:"description,omitempty"`
}
