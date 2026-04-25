package models

import (
	"time"

	"github.com/google/uuid"
)

// Group represents a household or team group.
type Group struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	CreatedBy   uuid.UUID `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// GroupMembership links a user to a group with a role.
type GroupMembership struct {
	ID      uuid.UUID `json:"id"`
	GroupID uuid.UUID `json:"group_id"`
	UserID  uuid.UUID `json:"user_id"`
	Role    string   `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
}

// GroupInvite stores an invite code for joining a group.
type GroupInvite struct {
	ID        uuid.UUID  `json:"id"`
	GroupID   uuid.UUID  `json:"group_id"`
	Code      string     `json:"code"`
	ExpiresAt time.Time  `json:"expires_at"`
	UsedBy    *uuid.UUID `json:"used_by,omitempty"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
}

// PendingClaim stores a claim code that can be used to join a group.
type PendingClaim struct {
	ID         uuid.UUID  `json:"id"`
	GroupID    uuid.UUID  `json:"group_id"`
	Code       string     `json:"code"`
	ExpiresAt  time.Time  `json:"expires_at"`
	ClaimedBy  *uuid.UUID `json:"claimed_by,omitempty"`
	ClaimedAt  *time.Time `json:"claimed_at,omitempty"`
}
