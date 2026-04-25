package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// NotificationService provides business logic for notifications.
type NotificationService struct {
	notificationRepo repositories.NotificationRepo
	pushService      PushService
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(
	notificationRepo repositories.NotificationRepo,
	pushService PushService,
) *NotificationService {
	return &NotificationService{
		notificationRepo: notificationRepo,
		pushService:      pushService,
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
	prefs, err := s.notificationRepo.GetPreferences(ctx, n.UserID)
	if err == nil {
		for _, pref := range prefs {
			if pref.Type == n.Type && pref.Enabled && pref.Channel == "push" {
				_ = s.pushService.SendToUser(n.UserID, n.Title)
				break
			}
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

// GetPreferences retrieves notification preferences for a user.
func (s *NotificationService) GetPreferences(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error) {
	return s.notificationRepo.GetPreferences(ctx, userID)
}

// UpdatePreferences updates a notification preference.
func (s *NotificationService) UpdatePreferences(ctx context.Context, userID uuid.UUID, pref *models.NotificationPreference) error {
	existing, err := s.notificationRepo.GetPreferences(ctx, userID)
	if err != nil {
		return fmt.Errorf("get preferences: %w", err)
	}
	found := false
	for _, p := range existing {
		if p.ID == pref.ID {
			found = true
			break
		}
	}
	if !found {
		return &api.NotFoundError{Resource: "notification preference", ID: pref.ID.String()}
	}
	if pref.UserID != uuid.Nil && pref.UserID != userID {
		return &api.PermissionDeniedError{Action: "update notification preference"}
	}
	return s.notificationRepo.UpdatePreferences(ctx, pref)
}
