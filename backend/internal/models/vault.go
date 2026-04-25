package models

import (
	"time"

	"github.com/google/uuid"
)

// VaultItem is a secure item in a group's vault.
type VaultItem struct {
	ID           uuid.UUID  `json:"id"`
	GroupID      uuid.UUID  `json:"group_id"`
	Type         string     `json:"type"`
	Title        string     `json:"title"`
	Content      string     `json:"content"`
	ReminderDate *time.Time `json:"reminder_date,omitempty"`
	CreatedBy    uuid.UUID  `json:"created_by"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

// VaultShare shares a vault item with another user.
type VaultShare struct {
	ID               uuid.UUID `json:"id"`
	VaultItemID      uuid.UUID `json:"vault_item_id"`
	SharedWithUserID uuid.UUID `json:"shared_with_user_id"`
	Permission       string    `json:"permission"`
	CreatedAt        time.Time `json:"created_at"`
}
