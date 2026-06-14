package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
	"github.com/google/uuid"
	"golang.org/x/oauth2/google"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// notifPrefRepo is the minimal repo interface needed to check opt-out preferences.
type notifPrefRepo interface {
	GetPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
	GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error)
}

// Service provides push notification operations.
type Service struct {
	cfg       *config.Config
	log       *logger.Logger
	authRepo  *repositories.AuthRepository
	groupRepo repositories.GroupRepo
	notifRepo notifPrefRepo

	fcmOnce  sync.Once
	fcmCreds *google.Credentials
	fcmErr   error
}

// New creates a new push notification service.
func New(cfg *config.Config, log *logger.Logger, authRepo *repositories.AuthRepository, groupRepo repositories.GroupRepo, notifRepo notifPrefRepo) *Service {
	return &Service{cfg: cfg, log: log, authRepo: authRepo, groupRepo: groupRepo, notifRepo: notifRepo}
}

// SendToUser sends a push notification to all subscriptions/devices for a user.
func (s *Service) SendToUser(userID uuid.UUID, payload string) error {
	ctx := context.Background()

	// Web push (VAPID)
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
			s.log.Warn().Err(err).Str("user_id", userID.String()).Str("endpoint", sub.Endpoint).Msg("web push failed")
			if resp != nil {
				_ = resp.Body.Close()
			}
			continue
		}
		_ = resp.Body.Close()
	}

	// FCM (mobile)
	if s.cfg.FirebaseProjectID != "" && s.cfg.FirebaseServiceAccount != "" {
		tokens, err := s.authRepo.ListDeviceTokensByUser(ctx, userID)
		if err != nil {
			s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to list device tokens")
		} else {
			for _, dt := range tokens {
				if err := s.sendFCM(ctx, dt.Token, payload); err != nil {
					s.log.Warn().Err(err).Str("user_id", userID.String()).Str("token", dt.Token[:min(8, len(dt.Token))]).Msg("FCM send failed")
				}
			}
		}
	}

	return nil
}

// BroadcastToGroup broadcasts a push notification to all members of a group.
func (s *Service) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	return s.broadcastExcluding(groupID, uuid.Nil, payload)
}

// BroadcastToGroupExcluding broadcasts to all group members except excludeUserID.
// Pass uuid.Nil as excludeUserID to broadcast to everyone.
func (s *Service) BroadcastToGroupExcluding(groupID, excludeUserID uuid.UUID, payload string) error {
	return s.broadcastExcluding(groupID, excludeUserID, payload)
}

func (s *Service) broadcastExcluding(groupID, excludeUserID uuid.UUID, payload string) error {
	ctx := context.Background()
	members, err := s.groupRepo.ListMembershipsByGroup(ctx, groupID)
	if err != nil {
		s.log.Error().Err(err).Str("group_id", groupID.String()).Msg("broadcast: failed to list group members")
		return err
	}

	var prefs map[uuid.UUID]*models.NotificationPreference
	if s.notifRepo != nil {
		prefs, err = s.notifRepo.GetPreferencesByGroup(ctx, groupID)
		if err != nil {
			s.log.Warn().Err(err).Str("group_id", groupID.String()).Msg("broadcast: failed to load preferences")
		}
	}

	targetUserIDs := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		if m.UserID == excludeUserID {
			continue
		}
		if prefs != nil {
			if pref, ok := prefs[m.UserID]; ok && !pref.PushEnabled {
				continue
			}
		}
		targetUserIDs = append(targetUserIDs, m.UserID)
	}
	if len(targetUserIDs) == 0 {
		return nil
	}

	subsByUser, err := s.authRepo.ListPushSubscriptionsByUserIDs(ctx, targetUserIDs)
	if err != nil {
		s.log.Error().Err(err).Msg("broadcast: failed to list push subscriptions")
		return err
	}

	var tokensByUser map[uuid.UUID][]models.DeviceToken
	if s.cfg.FirebaseProjectID != "" && s.cfg.FirebaseServiceAccount != "" {
		tokensByUser, err = s.authRepo.ListDeviceTokensByUserIDs(ctx, targetUserIDs)
		if err != nil {
			s.log.Error().Err(err).Msg("broadcast: failed to list device tokens")
		}
	}

	for _, userID := range targetUserIDs {
		for _, sub := range subsByUser[userID] {
			resp, sendErr := webpush.SendNotification(
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
			if sendErr != nil {
				s.log.Warn().Err(sendErr).Str("user_id", userID.String()).Str("endpoint", sub.Endpoint).Msg("web push failed")
				if resp != nil {
					_ = resp.Body.Close()
				}
				continue
			}
			_ = resp.Body.Close()
		}
		for _, dt := range tokensByUser[userID] {
			if err := s.sendFCM(ctx, dt.Token, payload); err != nil {
				s.log.Warn().Err(err).Str("user_id", userID.String()).Str("token", dt.Token[:min(8, len(dt.Token))]).Msg("FCM send failed")
			}
		}
	}
	return nil
}

// fcmTokenSource lazily initialises the Google credential from the service account JSON.
func (s *Service) fcmTokenSource(ctx context.Context) (*google.Credentials, error) {
	s.fcmOnce.Do(func() {
		creds, err := google.CredentialsFromJSON(
			ctx,
			[]byte(s.cfg.FirebaseServiceAccount),
			"https://www.googleapis.com/auth/firebase.messaging",
		)
		s.fcmCreds = creds
		s.fcmErr = err
	})
	return s.fcmCreds, s.fcmErr
}

type fcmMessage struct {
	Message struct {
		Token        string            `json:"token"`
		Notification *fcmNotification  `json:"notification,omitempty"`
		Data         map[string]string `json:"data,omitempty"`
	} `json:"message"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

func (s *Service) sendFCM(ctx context.Context, deviceToken, rawPayload string) error {
	creds, err := s.fcmTokenSource(ctx)
	if err != nil {
		return fmt.Errorf("FCM credentials: %w", err)
	}

	tok, err := creds.TokenSource.Token()
	if err != nil {
		return fmt.Errorf("FCM token: %w", err)
	}

	// Parse the notification payload to extract title/body.
	var parsed struct {
		Title string          `json:"title"`
		Body  string          `json:"body"`
		Data  json.RawMessage `json:"data"`
	}
	_ = json.Unmarshal([]byte(rawPayload), &parsed)

	var msg fcmMessage
	msg.Message.Token = deviceToken
	if parsed.Title != "" || parsed.Body != "" {
		msg.Message.Notification = &fcmNotification{
			Title: parsed.Title,
			Body:  parsed.Body,
		}
	}
	if len(parsed.Data) > 0 {
		var dataMap map[string]string
		if err := json.Unmarshal(parsed.Data, &dataMap); err == nil {
			msg.Message.Data = dataMap
		}
	}
	// Always include the raw payload so the app can handle it.
	if msg.Message.Data == nil {
		msg.Message.Data = map[string]string{}
	}
	msg.Message.Data["payload"] = rawPayload

	body, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("FCM marshal: %w", err)
	}

	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.cfg.FirebaseProjectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("FCM HTTP %d", resp.StatusCode)
	}
	return nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
