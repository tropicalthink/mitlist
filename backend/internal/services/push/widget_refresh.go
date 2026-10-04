package push

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

// WidgetRefreshType is the data "type" of the silent push that tells a
// device to refresh its home screen widgets (plans/047, contract C6).
const WidgetRefreshType = "widget_refresh"

// widgetRefreshMessage is data-only: no notification block, so neither
// platform shows anything. Android gets it at normal priority; iOS as a
// background push, which Apple throttles to a few an hour per app.
func widgetRefreshMessage(deviceToken string, groupID uuid.UUID) fcmMessage {
	collapse := "widgets:" + groupID.String()
	var msg fcmMessage
	msg.Message.Token = deviceToken
	msg.Message.Data = map[string]string{"type": WidgetRefreshType, "group_id": groupID.String()}
	msg.Message.Android = &fcmAndroidConfig{CollapseKey: collapse, Priority: "normal"}
	msg.Message.APNS = &fcmAPNSConfig{
		Headers: map[string]string{
			"apns-push-type":   "background",
			"apns-priority":    "5",
			"apns-collapse-id": collapse,
		},
		Payload: map[string]any{"aps": map[string]any{"content-available": 1}},
	}
	return msg
}

// SendWidgetRefresh sends the widget refresh push to every mobile device of
// userIDs. It is best effort: failures are logged, and a device whose token
// is no longer registered is pruned as for notifications.
func (s *Service) SendWidgetRefresh(ctx context.Context, userIDs []uuid.UUID, groupID uuid.UUID) {
	if len(userIDs) == 0 || s.cfg.FirebaseProjectID == "" || s.cfg.FirebaseServiceAccount == "" {
		return
	}
	tokensByUser, err := s.authRepo.ListDeviceTokensByUserIDs(ctx, userIDs)
	if err != nil {
		s.log.Warn().Err(err).Str("group_id", groupID.String()).Msg("widget refresh: failed to list device tokens")
		return
	}
	for userID, tokens := range tokensByUser {
		for _, dt := range tokens {
			msg := widgetRefreshMessage(dt.Token, groupID)
			err := s.postFCM(ctx, msg)
			var transient *transientFCMError
			if errors.As(err, &transient) {
				err = s.postFCM(ctx, msg)
			}
			if err == nil {
				continue
			}
			s.log.Warn().Err(err).Str("user_id", userID.String()).Msg("widget refresh push failed")
			var permanent *permanentFCMError
			if errors.As(err, &permanent) {
				if delErr := s.authRepo.DeleteDeviceToken(ctx, userID, dt.ID); delErr != nil {
					s.log.Warn().Err(delErr).Str("token_id", dt.ID.String()).Msg("failed to prune invalid FCM token")
				}
			}
		}
	}
}
