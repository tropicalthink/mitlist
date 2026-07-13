package models

import (
	"time"

	"github.com/google/uuid"
)

// PinwallPost is a user-authored note in a household pinwall.
type PinwallPost struct {
	ID               uuid.UUID  `json:"id"`
	GroupID          uuid.UUID  `json:"group_id"`
	UserID           uuid.UUID  `json:"user_id"`
	Content          string     `json:"content"`
	CreatedAt        time.Time  `json:"created_at"`
	RemindAt         *time.Time `json:"remind_at,omitempty"`
	ReminderSentAt   *time.Time `json:"reminder_sent_at,omitempty"`
	LinkedEntityType *string    `json:"linked_entity_type,omitempty"`
	LinkedEntityID   *uuid.UUID `json:"linked_entity_id,omitempty"`
	// PosX/PosY place the note on the shared cork board, in the board's fixed
	// logical coordinate space. Nil means the note has never been positioned;
	// the client then lays it out on its grid.
	PosX *float64 `json:"pos_x,omitempty"`
	PosY *float64 `json:"pos_y,omitempty"`
}
