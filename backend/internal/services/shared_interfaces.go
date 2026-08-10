package services

import (
	"strings"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/jwt"
)

// displayName returns a friendly name for a user, falling back to "A housemate"
// when FirstName is empty (e.g. some OAuth accounts).
func displayName(u *models.User) string {
	if u == nil {
		return "A housemate"
	}
	name := strings.TrimSpace(u.FirstName)
	if name == "" {
		return "A housemate"
	}
	return name
}

// JWTService defines the interface for JWT operations.
type JWTService interface {
	GenerateTokenPair(userID string, roles []string) (string, string, error)
	ValidateAccessToken(token string) (*jwt.Claims, error)
	ValidateRefreshToken(token string) (*jwt.Claims, error)
	RevokeRefreshToken(jti string) error
	RevokeUserSessions(userID uuid.UUID) error
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
	BroadcastToGroupExcluding(groupID, excludeUserID uuid.UUID, payload string) error
}
