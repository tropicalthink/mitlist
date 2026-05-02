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
)

// NotificationService provides business logic for notifications.
type NotificationService struct {
	notificationRepo repositories.NotificationRepo
	activityRepo     repositories.ActivityRepo
	pushService      PushService
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(
	notificationRepo repositories.NotificationRepo,
	activityRepo repositories.ActivityRepo,
	pushService PushService,
) *NotificationService {
	return &NotificationService{
		notificationRepo: notificationRepo,
		activityRepo:     activityRepo,
		pushService:      pushService,
	}
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
	default:
		return pref.PushEnabled // default to global push toggle for unknown types
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
			// Silently skip push on preference lookup failure.
			return nil
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
		_ = s.pushService.SendToUser(n.UserID, string(payloadBytes))
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
	return s.notificationRepo.GetPreferencesByUser(ctx, userID)
}

// GetGroupPreference retrieves notification preferences for a user in a specific group.
func (s *NotificationService) GetGroupPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	pref, err := s.notificationRepo.GetPreference(ctx, userID, groupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Return defaults
			return &models.NotificationPreference{
				UserID:          userID,
				GroupID:         groupID,
				ChoreDue:        true,
				ChoreDueDayOf:   true,
				ListItemAdded:   true,
				ExpenseCreated:  true,
				MealPlanChanged: true,
				WeeklyDigest:    true,
				PushEnabled:     true,
			}, nil
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
