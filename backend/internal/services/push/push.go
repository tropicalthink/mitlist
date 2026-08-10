package push

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
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
	authRepo  repositories.AuthRepo
	groupRepo repositories.GroupRepo
	notifRepo notifPrefRepo

	fcmOnce       sync.Once
	fcmCreds      *google.Credentials
	fcmErr        error
	webpushClient webpush.HTTPClient
}

// New creates a new push notification service.
func New(cfg *config.Config, log *logger.Logger, authRepo repositories.AuthRepo, groupRepo repositories.GroupRepo, notifRepo notifPrefRepo) *Service {
	return &Service{
		cfg:           cfg,
		log:           log,
		authRepo:      authRepo,
		groupRepo:     groupRepo,
		notifRepo:     notifRepo,
		webpushClient: &http.Client{Timeout: 10 * time.Second},
	}
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
		s.sendWebPush(ctx, sub, payload)
	}

	// FCM (mobile)
	if s.cfg.FirebaseProjectID != "" && s.cfg.FirebaseServiceAccount != "" {
		tokens, err := s.authRepo.ListDeviceTokensByUser(ctx, userID)
		if err != nil {
			s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to list device tokens")
		} else {
			for _, dt := range tokens {
				if err := s.sendFCMWithRetry(ctx, dt.Token, payload); err != nil {
					s.log.Warn().Err(err).Str("user_id", userID.String()).Str("token", dt.Token[:min(8, len(dt.Token))]).Msg("FCM send failed")
					var permanent *permanentFCMError
					if errors.As(err, &permanent) {
						if delErr := s.authRepo.DeleteDeviceToken(ctx, userID, dt.ID); delErr != nil {
							s.log.Warn().Err(delErr).Str("token_id", dt.ID.String()).Msg("failed to prune invalid FCM token")
						}
					}
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
			s.sendWebPush(ctx, sub, payload)
		}
		for _, dt := range tokensByUser[userID] {
			if err := s.sendFCMWithRetry(ctx, dt.Token, payload); err != nil {
				s.log.Warn().Err(err).Str("user_id", userID.String()).Str("token", dt.Token[:min(8, len(dt.Token))]).Msg("FCM send failed")
				var permanent *permanentFCMError
				if errors.As(err, &permanent) {
					if delErr := s.authRepo.DeleteDeviceToken(ctx, userID, dt.ID); delErr != nil {
						s.log.Warn().Err(delErr).Str("token_id", dt.ID.String()).Msg("failed to prune invalid FCM token")
					}
				}
			}
		}
	}
	return nil
}

// sendWebPush sends a single web-push notification and prunes the subscription on 404/410.
func (s *Service) sendWebPush(ctx context.Context, sub models.PushSubscription, payload string) {
	if err := ValidatePushEndpoint(sub.Endpoint); err != nil {
		s.log.Warn().Err(err).Str("sub_id", sub.ID.String()).Msg("web push endpoint failed send-time validation")
		return
	}
	for attempt := 0; attempt < 2; attempt++ {
		resp, err := webpush.SendNotificationWithContext(
			ctx,
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
				HTTPClient:      s.webpushClient,
			},
		)
		if err != nil {
			s.log.Warn().Err(err).Str("sub_id", sub.ID.String()).Msg("web push failed")
			if resp != nil {
				_ = resp.Body.Close()
			}
			return
		}
		status := resp.StatusCode
		_ = resp.Body.Close()
		if (status == http.StatusTooManyRequests || status >= 500) && attempt == 0 {
			s.log.Warn().Int("status", status).Str("sub_id", sub.ID.String()).Msg("web push transient failure; retrying")
			continue
		}
		if status == http.StatusNotFound || status == http.StatusGone {
			if delErr := s.authRepo.DeletePushSubscription(ctx, sub.ID); delErr != nil {
				s.log.Warn().Err(delErr).Str("sub_id", sub.ID.String()).Msg("failed to prune dead push subscription")
			} else {
				s.log.Info().Str("sub_id", sub.ID.String()).Msg("pruned expired push subscription")
			}
			return
		}
		if status >= 400 {
			s.log.Warn().Int("status", status).Str("sub_id", sub.ID.String()).Msg("web push non-2xx")
		}
		return
	}
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
		Android      *fcmAndroidConfig `json:"android,omitempty"`
		APNS         *fcmAPNSConfig    `json:"apns,omitempty"`
	} `json:"message"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmAndroidConfig struct {
	CollapseKey string `json:"collapse_key"`
}

type fcmAPNSConfig struct {
	Headers map[string]string `json:"headers"`
}

func notificationCollapseKey(data map[string]string) string {
	entityType := data["entity_type"]
	entityID := data["id"]
	if entityType == "" || entityID == "" {
		return ""
	}
	key := entityType + ":" + entityID
	if len(key) > 64 {
		return key[:64]
	}
	return key
}

type permanentFCMError struct {
	status int
}

type transientFCMError struct {
	status int
}

func (e *transientFCMError) Error() string {
	return fmt.Sprintf("FCM HTTP %d (transient provider failure)", e.status)
}

func (s *Service) sendFCMWithRetry(ctx context.Context, deviceToken, rawPayload string) error {
	err := s.sendFCM(ctx, deviceToken, rawPayload)
	var transient *transientFCMError
	if errors.As(err, &transient) {
		s.log.Warn().Int("status", transient.status).Msg("FCM transient failure; retrying")
		return s.sendFCM(ctx, deviceToken, rawPayload)
	}
	return err
}

func (e *permanentFCMError) Error() string {
	return fmt.Sprintf("FCM HTTP %d (device token is no longer registered)", e.status)
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
		var rawData map[string]any
		if err := json.Unmarshal(parsed.Data, &rawData); err == nil {
			msg.Message.Data = make(map[string]string, len(rawData))
			for key, value := range rawData {
				switch typed := value.(type) {
				case string:
					msg.Message.Data[key] = typed
				default:
					encoded, marshalErr := json.Marshal(typed)
					if marshalErr == nil {
						msg.Message.Data[key] = string(encoded)
					}
				}
			}
		}
	}
	// Always include the raw payload so the app can handle it.
	if msg.Message.Data == nil {
		msg.Message.Data = map[string]string{}
	}
	if collapseKey := notificationCollapseKey(msg.Message.Data); collapseKey != "" {
		msg.Message.Android = &fcmAndroidConfig{CollapseKey: collapseKey}
		msg.Message.APNS = &fcmAPNSConfig{Headers: map[string]string{
			"apns-collapse-id": collapseKey,
		}}
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
		responseBody, _ := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
		var providerError struct {
			Error struct {
				Status  string `json:"status"`
				Details []struct {
					ErrorCode string `json:"errorCode"`
				} `json:"details"`
			} `json:"error"`
		}
		_ = json.Unmarshal(responseBody, &providerError)
		for _, detail := range providerError.Error.Details {
			if detail.ErrorCode == "UNREGISTERED" {
				return &permanentFCMError{status: resp.StatusCode}
			}
		}
		if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
			return &transientFCMError{status: resp.StatusCode}
		}
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
