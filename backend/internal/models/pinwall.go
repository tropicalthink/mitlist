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
}

