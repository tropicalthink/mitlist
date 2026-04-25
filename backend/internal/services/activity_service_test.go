package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func TestActivityService_LogActivity(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		activityRepo.On("LogActivity", ctx, mock.AnythingOfType("*models.ActivityLog")).Return(nil)

		log := &models.ActivityLog{GroupID: groupID, Action: "create"}
		err := svc.LogActivity(ctx, userID, log)
		require.NoError(t, err)
		assert.Equal(t, userID, log.UserID)
	})

	t.Run("not a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		err := svc.LogActivity(ctx, userID, &models.ActivityLog{GroupID: groupID})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestActivityService_GetActivityLog(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	logID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		activityRepo.On("GetActivityLogByID", ctx, logID).Return(&models.ActivityLog{ID: logID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)

		log, err := svc.GetActivityLog(ctx, userID, logID)
		require.NoError(t, err)
		assert.Equal(t, logID, log.ID)
	})

	t.Run("not found", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		svc := NewActivityService(activityRepo, nil)

		activityRepo.On("GetActivityLogByID", ctx, logID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetActivityLog(ctx, userID, logID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}

func TestActivityService_ListActivityLogs(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		activityRepo.On("ListActivityLogsByGroup", ctx, groupID, 10, 0).Return([]models.ActivityLog{{ID: uuid.New()}}, nil)

		logs, err := svc.ListActivityLogs(ctx, userID, groupID, 10, 0)
		require.NoError(t, err)
		assert.Len(t, logs, 1)
	})
}

func TestActivityService_DeleteActivityLog(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	logID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		activityRepo.On("GetActivityLogByID", ctx, logID).Return(&models.ActivityLog{ID: logID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		activityRepo.On("DeleteActivityLog", ctx, logID).Return(nil)

		err := svc.DeleteActivityLog(ctx, userID, logID)
		require.NoError(t, err)
	})
}
