package models

import (
	"time"

	"github.com/google/uuid"
)

// OAuthAccount links a user to an external OAuth provider.
type OAuthAccount struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	Provider       string     `json:"provider"`
	ProviderUserID string     `json:"provider_user_id"`
	AccessToken    *string    `json:"access_token,omitempty"`
	RefreshToken   *string    `json:"refresh_token,omitempty"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
}

// PasswordResetToken stores tokens for password reset flows.
type PasswordResetToken struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	Token     string     `json:"token"`
	ExpiresAt time.Time  `json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
}

// PushSubscription stores a web push subscription for a user.
type PushSubscription struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Endpoint  string    `json:"endpoint"`
	P256dh    string    `json:"p256dh"`
	Auth      string    `json:"auth"`
	CreatedAt time.Time `json:"created_at"`
}
