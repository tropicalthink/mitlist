package services

import (
	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/services/jwt"
)

// JWTService defines the interface for JWT operations.
type JWTService interface {
	GenerateTokenPair(userID string, roles []string) (string, string, error)
	ValidateAccessToken(token string) (*jwt.Claims, error)
	ValidateRefreshToken(token string) (*jwt.Claims, error)
	RevokeRefreshToken(jti string) error
}

// PasswordService defines the interface for password hashing.
type PasswordService interface {
	Hash(password string) (string, error)
	Compare(hash, password string) bool
}

// MailService defines the interface for sending emails.
type MailService interface {
	Send(to, subject, body string, isHTML bool) error
	SendTemplate(to, subject, tmplStr string, data any) error
}

// PushService defines the interface for push notifications.
type PushService interface {
	SendToUser(userID uuid.UUID, payload string) error
	BroadcastToGroup(groupID uuid.UUID, payload string) error
}

// AIClient defines the interface for AI generation.
type AIClient interface {
	Generate(prompt string, model string) (string, error)
	GenerateStructured(prompt string, model string, schema map[string]any) (map[string]any, error)
}
