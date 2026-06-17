package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestNotificationService_CreateNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil)

		notificationRepo.On("CreateNotification", ctx, mock.AnythingOfType("*models.Notification")).Return(nil)

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
		svc := NewNotificationService(notificationRepo, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)

		n, err := svc.GetNotification(ctx, userID, notificationID)
		require.NoError(t, err)
		assert.Equal(t, notificationID, n.ID)
	})

	t.Run("wrong owner", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil)

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
		svc := NewNotificationService(notificationRepo, nil, nil)

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
		svc := NewNotificationService(notificationRepo, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)
		notificationRepo.On("DeleteNotification", ctx, notificationID).Return(nil)

		err := svc.DeleteNotification(ctx, userID, notificationID)
		require.NoError(t, err)
	})
}

func TestDefaultNotificationPreference(t *testing.T) {
	userID := uuid.New()
	groupID := uuid.New()
	pref := models.DefaultNotificationPreference(userID, groupID)

	assert.Equal(t, userID, pref.UserID)
	assert.Equal(t, groupID, pref.GroupID)
	assert.True(t, pref.ChoreDue, "ChoreDue should be true")
	assert.True(t, pref.ChoreDueDayOf, "ChoreDueDayOf should be true")
	assert.True(t, pref.ListItemAdded, "ListItemAdded should be true")
	assert.True(t, pref.ExpenseCreated, "ExpenseCreated should be true")
	assert.True(t, pref.MealPlanChanged, "MealPlanChanged should be true")
	assert.True(t, pref.WeeklyDigest, "WeeklyDigest should be true")
	assert.True(t, pref.PinwallReminder, "PinwallReminder should be true (regression: was missing from notification_service default)")
	assert.True(t, pref.PushEnabled, "PushEnabled should be true")
}

func TestNotificationService_UpdatePreferences(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil)

		notificationRepo.On("UpsertPreference", ctx, mock.AnythingOfType("*models.NotificationPreference")).Return(nil)

		pref := &models.NotificationPreference{UserID: userID, GroupID: groupID, ChoreDue: false}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.NoError(t, err)
	})

	t.Run("wrong user", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil)

		pref := &models.NotificationPreference{UserID: uuid.New(), GroupID: groupID}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}
