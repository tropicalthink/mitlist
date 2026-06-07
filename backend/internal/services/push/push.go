package push

import (
	"context"

	"github.com/SherClockHolmes/webpush-go"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Service provides push notification operations.
type Service struct {
	cfg      *config.Config
	log      *logger.Logger
	authRepo *repositories.AuthRepository
}

// New creates a new push notification service.
func New(cfg *config.Config, log *logger.Logger, authRepo *repositories.AuthRepository) *Service {
	return &Service{cfg: cfg, log: log, authRepo: authRepo}
}

// SendToUser sends a push notification to a specific user.
func (s *Service) SendToUser(userID uuid.UUID, payload string) error {
	ctx := context.Background()
	subs, err := s.authRepo.ListPushSubscriptionsByUser(ctx, userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to list push subscriptions")
		return err
	}

	for _, sub := range subs {
		resp, err := webpush.SendNotification(
			[]byte(payload),
			&webpush.Subscription{
				Endpoint: sub.Endpoint,
				Keys: webpush.Keys{
					P256dh: sub.P256dh,
					Auth:   sub.Auth,
				},
			},
			&webpush.Options{
				Subscriber:      s.cfg.VapidSubject,
				VAPIDPublicKey:  s.cfg.VapidPublicKey,
				VAPIDPrivateKey: s.cfg.VapidPrivateKey,
				TTL:             86400,
			},
		)
		if err != nil {
			s.log.Warn().Err(err).Str("user_id", userID.String()).Str("endpoint", sub.Endpoint).Msg("push notification send failed, subscription may be expired")
			if resp != nil {
				_ = resp.Body.Close()
			}
			continue
		}
		_ = resp.Body.Close()
	}

	return nil
}

// BroadcastToGroup broadcasts a push notification to all members of a group.
// This is a stub — per-user push via SendToUser should be used until group broadcast is implemented.
func (s *Service) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	s.log.Warn().Str("group_id", groupID.String()).Str("payload", payload).Msg("push broadcast to group requested but not implemented")
	return nil
}
