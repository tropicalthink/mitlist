package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a registered user in the system.
type User struct {
	ID           uuid.UUID `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	FirstName    string    `json:"first_name"`
	LastName     string    `json:"last_name"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	IsActive     bool      `json:"is_active"`
	IsVerified   bool      `json:"is_verified"`
	IsGuest      bool      `json:"is_guest"`
	// TipsEmailsEnabled is the opt-out for the post-sign-up tips series. On
	// by default; the emails carry an unsubscribe link and the account screen
	// has a switch.
	TipsEmailsEnabled bool `json:"tips_emails_enabled"`
	// Guest lifecycle timestamps are maintained server-side. They are omitted
	// from the public user JSON; guests are locked after inactivity and retained
	// for a recovery grace period before cleanup.
	GuestLastSeenAt *time.Time `json:"-"`
	GuestLockedAt   *time.Time `json:"-"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}
