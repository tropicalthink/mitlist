package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// NotificationService provides business logic for notifications.
type NotificationService struct {
	notificationRepo repositories.NotificationRepo
	activityRepo     repositories.ActivityRepo
	groupRepo        repositories.GroupRepo
	pushService      PushService
	mailService      MailService // optional; nil means email channel is disabled
	hub              *sse.Hub    // optional; nil disables SSE broadcasts
	log              *logger.Logger
}

// SetHub injects the SSE hub so newly persisted notifications broadcast to the
// household in real time. Without a hub, the in-app feed only updates on manual
// refresh.
func (s *NotificationService) SetHub(h *sse.Hub) { s.hub = h }

// SetLogger enables structured delivery-failure logging. Tests and lightweight
// consumers can omit it without changing dispatch behavior.
func (s *NotificationService) SetLogger(log *logger.Logger) { s.log = log }

// publishNotificationCreated emits a `notification:created` event for the
// group. The payload is intentionally empty: notification rows are per-user, so
// each client refetches its own canonical feed rather than trusting the event
// body (mirrors the pinwall reconcile pattern).
func (s *NotificationService) publishNotificationCreated(groupID uuid.UUID) {
	if s.hub == nil {
		return
	}
	s.hub.Publish(groupID.String(), sse.Event{
		Type:    "notification:created",
		GroupID: groupID.String(),
		Payload: json.RawMessage(`{}`),
	})
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(
	notificationRepo repositories.NotificationRepo,
	activityRepo repositories.ActivityRepo,
	groupRepo repositories.GroupRepo,
	pushService PushService,
) *NotificationService {
	return &NotificationService{
		notificationRepo: notificationRepo,
		activityRepo:     activityRepo,
		groupRepo:        groupRepo,
		pushService:      pushService,
	}
}

// NewNotificationServiceWithMail creates a NotificationService with email delivery enabled.
func NewNotificationServiceWithMail(
	notificationRepo repositories.NotificationRepo,
	activityRepo repositories.ActivityRepo,
	groupRepo repositories.GroupRepo,
	pushService PushService,
	mailService MailService,
) *NotificationService {
	return &NotificationService{
		notificationRepo: notificationRepo,
		activityRepo:     activityRepo,
		groupRepo:        groupRepo,
		pushService:      pushService,
		mailService:      mailService,
	}
}

// emailEligibleTypes lists notification types that are worth an email. High-frequency
// per-item events (list_item_added, meal_plan_changed) are excluded to avoid inbox
// spam; digests and reminders are included.
var emailEligibleTypes = map[string]bool{
	"weekly_digest":    true,
	"chore_due":        true,
	"chore_due_day_of": true,
	"expense_created":  true,
	"pinwall_reminder": true,
}

// NotificationDispatcher is the interface implemented by NotificationService.
// Consuming services accept this interface to avoid import cycles.
type NotificationDispatcher interface {
	DispatchToGroup(ctx context.Context, groupID, actorID uuid.UUID, nType, title, body string, payload models.NotificationPayload) error
	DispatchToUsers(ctx context.Context, userIDs []uuid.UUID, groupID uuid.UUID, nType, title, body string, payload models.NotificationPayload) error
}

// DispatchToGroup persists in-app notifications and sends push to every group
// member (except actorID) whose preferences allow this type. Persist is
// synchronous (the feed must be reliable); push is fired in the background so it
// never blocks the caller. Best-effort: push errors are logged, not returned.
func (s *NotificationService) DispatchToGroup(ctx context.Context, groupID, actorID uuid.UUID, nType, title, body string, payload models.NotificationPayload) error {
	members, err := s.groupRepo.ListMembershipsByGroup(ctx, groupID)
	if err != nil {
		return fmt.Errorf("dispatch: list members: %w", err)
	}
	prefs, err := s.notificationRepo.GetPreferencesByGroup(ctx, groupID)
	if err != nil {
		return fmt.Errorf("dispatch: load preferences: %w", err)
	}

	data, _ := json.Marshal(payload)
	now := time.Now().UTC()
	var rows []models.Notification
	var pushTargets []uuid.UUID
	var emailTargets []uuid.UUID
	for _, m := range members {
		if m.UserID == actorID {
			continue
		}
		pref := prefs[m.UserID]
		if pref == nil {
			pref = models.DefaultNotificationPreference(m.UserID, groupID)
		}
		if !preferenceForType(pref, nType) {
			continue
		}
		rows = append(rows, models.Notification{
			ID:        uuid.New(),
			UserID:    m.UserID,
			GroupID:   groupID,
			Type:      nType,
			Title:     title,
			Body:      body,
			Data:      data,
			CreatedAt: now,
		})
		if pref.PushEnabled {
			pushTargets = append(pushTargets, m.UserID)
		}
		if pref.EmailEnabled && emailEligibleTypes[nType] {
			emailTargets = append(emailTargets, m.UserID)
		}
	}
	if len(rows) == 0 {
		return nil
	}
	if err := s.notificationRepo.CreateNotificationsBatch(ctx, rows); err != nil {
		return fmt.Errorf("dispatch: persist: %w", err)
	}
	s.publishNotificationCreated(groupID)
	s.deliverPushAsync(pushTargets, title, body, payload, groupID, nType)
	s.deliverEmailAsync(emailTargets, groupID, title, body, nType)
	return nil
}

// DispatchToUsers persists in-app notifications and sends push to the specified
// users (e.g. a single assignee for a chore reminder). Preference-checked per user.
// Persist is synchronous; push is background best-effort.
func (s *NotificationService) DispatchToUsers(ctx context.Context, userIDs []uuid.UUID, groupID uuid.UUID, nType, title, body string, payload models.NotificationPayload) error {
	if len(userIDs) == 0 {
		return nil
	}
	prefs, err := s.notificationRepo.GetPreferencesByGroup(ctx, groupID)
	if err != nil {
		return fmt.Errorf("dispatch: load preferences: %w", err)
	}

	data, _ := json.Marshal(payload)
	now := time.Now().UTC()
	var rows []models.Notification
	var pushTargets []uuid.UUID
	var emailTargets []uuid.UUID
	for _, userID := range userIDs {
		pref := prefs[userID]
		if pref == nil {
			pref = models.DefaultNotificationPreference(userID, groupID)
		}
		if !preferenceForType(pref, nType) {
			continue
		}
		rows = append(rows, models.Notification{
			ID:        uuid.New(),
			UserID:    userID,
			GroupID:   groupID,
			Type:      nType,
			Title:     title,
			Body:      body,
			Data:      data,
			CreatedAt: now,
		})
		if pref.PushEnabled {
			pushTargets = append(pushTargets, userID)
		}
		if pref.EmailEnabled && emailEligibleTypes[nType] {
			emailTargets = append(emailTargets, userID)
		}
	}
	if len(rows) == 0 {
		return nil
	}
	if err := s.notificationRepo.CreateNotificationsBatch(ctx, rows); err != nil {
		return fmt.Errorf("dispatch: persist: %w", err)
	}
	s.publishNotificationCreated(groupID)
	s.deliverPushAsync(pushTargets, title, body, payload, groupID, nType)
	s.deliverEmailAsync(emailTargets, groupID, title, body, nType)
	return nil
}

func (s *NotificationService) deliverPushAsync(userIDs []uuid.UUID, title, body string, payload models.NotificationPayload, groupID uuid.UUID, nType string) {
	if s.pushService == nil || len(userIDs) == 0 {
		return
	}
	pushPayload, _ := json.Marshal(map[string]any{"title": title, "body": body, "data": payload})
	go func(ids []uuid.UUID, p string) {
		for _, id := range ids {
			if err := s.pushService.SendToUser(id, p); err != nil && s.log != nil {
				s.log.Error().Err(err).
					Str("user_id", id.String()).
					Str("group_id", groupID.String()).
					Str("notification_type", nType).
					Msg("notification push delivery failed")
			}
		}
	}(append([]uuid.UUID(nil), userIDs...), string(pushPayload))
}

func (s *NotificationService) deliverEmailAsync(userIDs []uuid.UUID, groupID uuid.UUID, subject, body, nType string) {
	if s.mailService == nil || len(userIDs) == 0 {
		return
	}
	go func(ids []uuid.UUID) {
		emailCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		memberEmails, err := s.groupRepo.ListMemberEmailsByGroup(emailCtx, groupID)
		if err != nil {
			if s.log != nil {
				s.log.Error().Err(err).
					Str("group_id", groupID.String()).
					Str("notification_type", nType).
					Msg("notification email recipient lookup failed")
			}
			return
		}
		for _, id := range ids {
			email := memberEmails[id]
			if email == "" {
				continue
			}
			if err := s.mailService.Send(email, subject, body, false); err != nil && s.log != nil {
				s.log.Error().Err(err).
					Str("user_id", id.String()).
					Str("group_id", groupID.String()).
					Str("notification_type", nType).
					Msg("notification email delivery failed")
			}
		}
	}(append([]uuid.UUID(nil), userIDs...))
}

// preferenceForType maps a notification type to the corresponding preference flag.
func preferenceForType(pref *models.NotificationPreference, nType string) bool {
	switch nType {
	case "chore_due":
		return pref.ChoreDue
	case "chore_due_day_of":
		return pref.ChoreDueDayOf
	case "list_item_added":
		return pref.ListItemAdded
	case "expense_created":
		return pref.ExpenseCreated
	case "meal_plan_changed":
		return pref.MealPlanChanged
	case "weekly_digest":
		return pref.WeeklyDigest
	case "pinwall_reminder":
		return pref.PinwallReminder
	default:
		return true
	}
}

// CreateNotification creates a notification and triggers push if enabled.
func (s *NotificationService) CreateNotification(ctx context.Context, n *models.Notification) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	n.CreatedAt = time.Now().UTC()
	n.IsRead = false

	if err := s.notificationRepo.CreateNotification(ctx, n); err != nil {
		return fmt.Errorf("create notification: %w", err)
	}

	// Trigger push if enabled for this notification type.
	// When GroupID is provided, we look up the user's preference for that group.
	// Push delivery requires Firebase/APNS setup (Slice 7 placeholder).
	if n.GroupID != uuid.Nil && s.pushService != nil {
		pref, err := s.notificationRepo.GetPreference(ctx, n.UserID, n.GroupID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				pref = models.DefaultNotificationPreference(n.UserID, n.GroupID)
			} else {
				if s.log != nil {
					s.log.Error().Err(err).
						Str("user_id", n.UserID.String()).
						Str("group_id", n.GroupID.String()).
						Msg("notification preference lookup failed; push suppressed")
				}
				return nil
			}
		}
		if !pref.PushEnabled || !preferenceForType(pref, n.Type) {
			return nil
		}
		payloadMap := map[string]interface{}{
			"title": n.Title,
			"body":  n.Body,
		}
		if len(n.Data) > 0 {
			var dataMap map[string]interface{}
			if err := json.Unmarshal(n.Data, &dataMap); err == nil {
				payloadMap["data"] = dataMap
			}
		}
		payloadBytes, _ := json.Marshal(payloadMap)
		if err := s.pushService.SendToUser(n.UserID, string(payloadBytes)); err != nil && s.log != nil {
			s.log.Error().Err(err).
				Str("user_id", n.UserID.String()).
				Str("group_id", n.GroupID.String()).
				Str("notification_type", n.Type).
				Msg("notification push delivery failed")
		}
	}

	return nil
}

// GetNotification retrieves a notification by ID, enforcing ownership.
func (s *NotificationService) GetNotification(ctx context.Context, userID, notificationID uuid.UUID) (*models.Notification, error) {
	n, err := s.notificationRepo.GetNotificationByID(ctx, notificationID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "notification", ID: notificationID.String()}
		}
		return nil, fmt.Errorf("get notification: %w", err)
	}
	if n.UserID != userID {
		return nil, &api.PermissionDeniedError{Action: "access notification"}
	}
	return n, nil
}

// ListNotifications lists notifications for a user.
func (s *NotificationService) ListNotifications(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Notification, error) {
	return s.notificationRepo.ListNotificationsByUser(ctx, userID, limit, offset)
}

// ListNotificationsBefore lists an older page using a stable cursor.
func (s *NotificationService) ListNotificationsBefore(ctx context.Context, userID uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error) {
	return s.notificationRepo.ListNotificationsByUserBefore(ctx, userID, before, beforeID, limit)
}

// CountUnreadNotifications returns the user's unread inbox count.
func (s *NotificationService) CountUnreadNotifications(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.notificationRepo.CountUnreadNotifications(ctx, userID)
}

// MarkAsRead marks a single notification as read.
func (s *NotificationService) MarkAsRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	n, err := s.notificationRepo.GetNotificationByID(ctx, notificationID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "notification", ID: notificationID.String()}
		}
		return fmt.Errorf("get notification: %w", err)
	}
	if n.UserID != userID {
		return &api.PermissionDeniedError{Action: "mark notification as read"}
	}
	return s.notificationRepo.MarkAsRead(ctx, notificationID)
}

// MarkAllAsRead marks all notifications for a user as read.
func (s *NotificationService) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	return s.notificationRepo.MarkAllAsRead(ctx, userID)
}

// DeleteNotification deletes a notification.
func (s *NotificationService) DeleteNotification(ctx context.Context, userID, notificationID uuid.UUID) error {
	n, err := s.notificationRepo.GetNotificationByID(ctx, notificationID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "notification", ID: notificationID.String()}
		}
		return fmt.Errorf("get notification: %w", err)
	}
	if n.UserID != userID {
		return &api.PermissionDeniedError{Action: "delete notification"}
	}
	return s.notificationRepo.DeleteNotification(ctx, notificationID)
}

// GetPreferences retrieves notification preferences for a user across all groups.
func (s *NotificationService) GetPreferences(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error) {
	prefs, err := s.notificationRepo.GetPreferencesByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	groups, err := s.groupRepo.ListGroupsByUser(ctx, userID, 500, 0)
	if err != nil {
		return nil, fmt.Errorf("list preference groups: %w", err)
	}
	byGroup := make(map[uuid.UUID]models.NotificationPreference, len(prefs))
	for _, pref := range prefs {
		byGroup[pref.GroupID] = pref
	}
	result := make([]models.NotificationPreference, 0, len(groups))
	for _, group := range groups {
		if pref, ok := byGroup[group.ID]; ok {
			result = append(result, pref)
		} else {
			result = append(result, *models.DefaultNotificationPreference(userID, group.ID))
		}
	}
	return result, nil
}

// GetGroupPreference retrieves notification preferences for a user in a specific group.
func (s *NotificationService) GetGroupPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	if err := requireGroupMember(ctx, s.groupRepo, groupID, userID); err != nil {
		return nil, err
	}
	pref, err := s.notificationRepo.GetPreference(ctx, userID, groupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Return defaults
			return models.DefaultNotificationPreference(userID, groupID), nil
		}
		return nil, fmt.Errorf("get preference: %w", err)
	}
	return pref, nil
}

// UpdatePreferences upserts notification preferences for a user/group.
func (s *NotificationService) UpdatePreferences(ctx context.Context, userID uuid.UUID, pref *models.NotificationPreference) error {
	if pref.UserID != uuid.Nil && pref.UserID != userID {
		return &api.PermissionDeniedError{Action: "update notification preference"}
	}
	pref.UserID = userID
	if err := requireGroupMember(ctx, s.groupRepo, pref.GroupID, userID); err != nil {
		return err
	}
	return s.notificationRepo.UpsertPreference(ctx, pref)
}

// WeeklyDigest aggregates household activity for the past week.
// Delivery via email/push requires external provider setup.
func (s *NotificationService) WeeklyDigest(ctx context.Context, groupID uuid.UUID) (map[string]interface{}, error) {
	counts, err := s.activityRepo.CountWeeklyActivity(ctx, groupID)
	if err != nil {
		return nil, fmt.Errorf("weekly digest: %w", err)
	}
	return map[string]interface{}{
		"group_id":   groupID,
		"period":     "last_7_days",
		"chores":     counts["chores"],
		"expenses":   counts["expenses"],
		"lists":      counts["lists"],
		"meal_plans": counts["meal_plans"],
		"recipes":    counts["recipes"],
	}, nil
}
