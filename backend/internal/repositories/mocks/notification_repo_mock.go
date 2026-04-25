package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockNotificationRepo is a mock implementation of repositories.NotificationRepo.
type MockNotificationRepo struct {
	mock.Mock
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

func (m *MockNotificationRepo) MarkAsRead(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockNotificationRepo) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockNotificationRepo) DeleteNotification(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockNotificationRepo) GetPreferences(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error) {
	args := m.Called(ctx, userID)
	if p := args.Get(0); p != nil {
		return p.([]models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockNotificationRepo) UpdatePreferences(ctx context.Context, pref *models.NotificationPreference) error {
	args := m.Called(ctx, pref)
	return args.Error(0)
}
