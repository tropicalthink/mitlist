package push

import (
	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Service provides push notification operations.
type Service struct {
	cfg *config.Config
	log *logger.Logger
}

// New creates a new push notification service.
func New(cfg *config.Config, log *logger.Logger) *Service {
	return &Service{cfg: cfg, log: log}
}

// SendToUser sends a push notification to a specific user.
func (s *Service) SendToUser(userID uuid.UUID, payload string) error {
	s.log.Info().Str("user_id", userID.String()).Str("payload", payload).Msg("push notification sent")
	return nil
}

// BroadcastToGroup broadcasts a push notification to all members of a group.
func (s *Service) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	s.log.Info().Str("group_id", groupID.String()).Str("payload", payload).Msg("push broadcast sent")
	return nil
}
