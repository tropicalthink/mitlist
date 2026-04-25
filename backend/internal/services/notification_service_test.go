package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func TestNotificationService_CreateNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success triggers push", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notificationRepo, pushSvc)

		notificationRepo.On("CreateNotification", ctx, mock.AnythingOfType("*models.Notification")).Return(nil)
		notificationRepo.On("GetPreferences", ctx, userID).Return([]models.NotificationPreference{
			{Type: "mention", Enabled: true, Channel: "push"},
		}, nil)
		pushSvc.On("SendToUser", userID, mock.AnythingOfType("string")).Return(nil)

		n := &models.Notification{UserID: userID, Type: "mention", Title: "Hello"}
		err := svc.CreateNotification(ctx, n)
		require.NoError(t, err)
	})

	t.Run("success no push", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("CreateNotification", ctx, mock.AnythingOfType("*models.Notification")).Return(nil)
		notificationRepo.On("GetPreferences", ctx, userID).Return([]models.NotificationPreference{}, nil)

		n := &models.Notification{UserID: userID, Type: "mention", Title: "Hello"}
		err := svc.CreateNotification(ctx, n)
		require.NoError(t, err)
	})
}

func TestNotificationService_GetNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success owner", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)

		n, err := svc.GetNotification(ctx, userID, notificationID)
		require.NoError(t, err)
		assert.Equal(t, notificationID, n.ID)
	})

	t.Run("wrong owner", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: uuid.New()}, nil)

		_, err := svc.GetNotification(ctx, userID, notificationID)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestNotificationService_MarkAsRead(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)
		notificationRepo.On("MarkAsRead", ctx, notificationID).Return(nil)

		err := svc.MarkAsRead(ctx, userID, notificationID)
		require.NoError(t, err)
	})
}

func TestNotificationService_DeleteNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)
		notificationRepo.On("DeleteNotification", ctx, notificationID).Return(nil)

		err := svc.DeleteNotification(ctx, userID, notificationID)
		require.NoError(t, err)
	})
}

func TestNotificationService_UpdatePreferences(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	prefID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetPreferences", ctx, userID).Return([]models.NotificationPreference{
			{ID: prefID, UserID: userID},
		}, nil)
		notificationRepo.On("UpdatePreferences", ctx, mock.AnythingOfType("*models.NotificationPreference")).Return(nil)

		pref := &models.NotificationPreference{ID: prefID, UserID: userID, Enabled: false}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.NoError(t, err)
	})

	t.Run("preference not found", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetPreferences", ctx, userID).Return([]models.NotificationPreference{}, nil)

		pref := &models.NotificationPreference{ID: prefID}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})

	t.Run("wrong user", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil)

		notificationRepo.On("GetPreferences", ctx, userID).Return([]models.NotificationPreference{
			{ID: prefID, UserID: userID},
		}, nil)

		pref := &models.NotificationPreference{ID: prefID, UserID: uuid.New()}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}
