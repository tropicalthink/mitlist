package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestActivityService_ListRecentActivity(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()

	user := &models.User{ID: userID, IsActive: true, IsVerified: true}

	t.Run("success returns events", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		events := []models.ActivityEvent{
			{
				ID:        "evt1",
				Type:      models.ActivityTypeExpenseCreated,
				Title:     "Groceries",
				GroupID:   groupID,
				CreatedAt: time.Now(),
			},
			{
				ID:        "evt2",
				Type:      models.ActivityTypeChoreCompleted,
				Title:     "Dishes",
				GroupID:   groupID,
				CreatedAt: time.Now(),
			},
		}

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		activityRepo.On("ListRecentActivity", ctx, groupID, 20).Return(events, nil)

		result, err := svc.ListRecentActivity(ctx, user, groupID, 20)
		require.NoError(t, err)
		assert.Len(t, result, 2)
		assert.Equal(t, "evt1", result[0].ID)
		assert.Equal(t, models.ActivityTypeExpenseCreated, result[0].Type)
		assert.Equal(t, "Groceries", result[0].Title)
	})

	t.Run("non-member returns permission denied", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.ListRecentActivity(ctx, user, groupID, 20)
		require.Error(t, err)
		activityRepo.AssertNotCalled(t, "ListRecentActivity", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("empty group returns empty slice", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		activityRepo.On("ListRecentActivity", ctx, groupID, 5).Return([]models.ActivityEvent{}, nil)

		result, err := svc.ListRecentActivity(ctx, user, groupID, 5)
		require.NoError(t, err)
		assert.Empty(t, result)
	})

	t.Run("limit is passed through to repo", func(t *testing.T) {
		activityRepo := new(mocks.MockActivityRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewActivityService(activityRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		activityRepo.On("ListRecentActivity", ctx, groupID, 50).Return([]models.ActivityEvent{}, nil)

		_, err := svc.ListRecentActivity(ctx, user, groupID, 50)
		require.NoError(t, err)
		activityRepo.AssertCalled(t, "ListRecentActivity", ctx, groupID, 50)
	})
}
