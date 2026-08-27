package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/stretchr/testify/mock"
)

// MockNotificationRepo is a mock implementation of repositories.NotificationRepo.
type MockNotificationRepo struct {
	mock.Mock
}

func (m *MockNotificationRepo) ListNotificationsByUserBefore(ctx context.Context, userID uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error) {
	args := m.Called(ctx, userID, before, beforeID, limit)
	if n := args.Get(0); n != nil {
		return n.([]models.Notification), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) CreateNotification(ctx context.Context, n *models.Notification) error {
	args := m.Called(ctx, n)
	return args.Error(0)
}

func (m *MockNotificationRepo) GetNotificationByID(ctx context.Context, id uuid.UUID) (*models.Notification, error) {
	args := m.Called(ctx, id)
	if n := args.Get(0); n != nil {
		return n.(*models.Notification), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) ListNotificationsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Notification, error) {
	args := m.Called(ctx, userID, limit, offset)
	if n := args.Get(0); n != nil {
		return n.([]models.Notification), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) ListNotificationsByUserAndGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, limit, offset int) ([]models.Notification, error) {
	args := m.Called(ctx, userID, groupIDs, limit, offset)
	if n := args.Get(0); n != nil {
		return n.([]models.Notification), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) ListNotificationsByUserAndGroupsBefore(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error) {
	args := m.Called(ctx, userID, groupIDs, before, beforeID, limit)
	if n := args.Get(0); n != nil {
		return n.([]models.Notification), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) CountUnreadNotifications(ctx context.Context, userID uuid.UUID) (int, error) {
	args := m.Called(ctx, userID)
	return args.Int(0), args.Error(1)
}

func (m *MockNotificationRepo) CountUnreadNotificationsByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) (int, error) {
	args := m.Called(ctx, userID, groupIDs)
	return args.Int(0), args.Error(1)
}

func (m *MockNotificationRepo) MarkAsRead(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockNotificationRepo) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockNotificationRepo) MarkAllAsReadByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) error {
	args := m.Called(ctx, userID, groupIDs)
	return args.Error(0)
}

func (m *MockNotificationRepo) DeleteNotification(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockNotificationRepo) GetPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	args := m.Called(ctx, userID, groupID)
	if p := args.Get(0); p != nil {
		return p.(*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) GetPreferencesByUser(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error) {
	args := m.Called(ctx, userID)
	if p := args.Get(0); p != nil {
		return p.([]models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	args := m.Called(ctx, groupID)
	if p := args.Get(0); p != nil {
		return p.(map[uuid.UUID]*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	args := m.Called(ctx, notifications)
	return args.Error(0)
}

func (m *MockNotificationRepo) CreateNotificationsBatchIdempotent(ctx context.Context, notifications []models.Notification) error {
	args := m.Called(ctx, notifications)
	return args.Error(0)
}

func (m *MockNotificationRepo) QueueListItemNotification(ctx context.Context, groupID, actorID, listID uuid.UUID, actorName, listName, itemName string) error {
	args := m.Called(ctx, groupID, actorID, listID, actorName, listName, itemName)
	return args.Error(0)
}

func (m *MockNotificationRepo) FlushListNotificationBatches(ctx context.Context, actorID, listID uuid.UUID) error {
	args := m.Called(ctx, actorID, listID)
	return args.Error(0)
}

func (m *MockNotificationRepo) UpsertPreference(ctx context.Context, pref *models.NotificationPreference) error {
	args := m.Called(ctx, pref)
	return args.Error(0)
}
