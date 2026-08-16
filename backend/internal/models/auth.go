package models

import (
	"time"

	"github.com/google/uuid"
)

// OAuthAccount links a user to an external OAuth provider.
type OAuthAccount struct {
	ID             uuid.UUID `json:"id"`
	UserID         uuid.UUID `json:"user_id"`
	Provider       string    `json:"provider"`
	ProviderUserID string    `json:"provider_user_id"`
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

// IntegrationCredential is a non-interactive, revocable credential issued to
// an external integration (for example Home Assistant). The raw secret is
// never persisted or returned after creation.
type IntegrationCredential struct {
	ID            uuid.UUID   `json:"id"`
	UserID        uuid.UUID   `json:"user_id"`
	Name          string      `json:"name"`
	TokenPrefix   string      `json:"token_prefix"`
	GroupIDs      []uuid.UUID `json:"group_ids"`
	Scopes        []string    `json:"scopes"`
	CreatedAt     time.Time   `json:"created_at"`
	LastUsedAt    *time.Time  `json:"last_used_at,omitempty"`
	RevokedAt     *time.Time  `json:"revoked_at,omitempty"`
	LastUsedIP    string      `json:"-"`
	LastUserAgent string      `json:"-"`
}
