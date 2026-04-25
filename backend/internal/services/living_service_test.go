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

func TestLivingService_CreateLivingThing(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		livingRepo.On("CreateLivingThing", ctx, mock.AnythingOfType("*models.LivingThing")).Return(&models.LivingThing{ID: uuid.New()}, nil)

		lt := &models.LivingThing{GroupID: groupID, Name: "Ficus"}
		result, err := svc.CreateLivingThing(ctx, userID, lt)
		require.NoError(t, err)
		assert.NotEqual(t, uuid.Nil, result.ID)
	})

	t.Run("not a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.CreateLivingThing(ctx, userID, &models.LivingThing{GroupID: groupID})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestLivingService_GetLivingThing(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	ltID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(&models.LivingThing{ID: ltID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)

		lt, err := svc.GetLivingThing(ctx, userID, ltID)
		require.NoError(t, err)
		assert.Equal(t, ltID, lt.ID)
	})

	t.Run("not found", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		svc := NewLivingService(livingRepo, nil)

		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetLivingThing(ctx, userID, ltID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}

func TestLivingService_CreateCareSchedule(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	ltID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(&models.LivingThing{ID: ltID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		livingRepo.On("CreateCareSchedule", ctx, mock.AnythingOfType("*models.CareSchedule")).Return(&models.CareSchedule{ID: uuid.New()}, nil)

		cs := &models.CareSchedule{LivingThingID: ltID}
		result, err := svc.CreateCareSchedule(ctx, userID, cs)
		require.NoError(t, err)
		assert.NotEqual(t, uuid.Nil, result.ID)
	})
}

func TestLivingService_GetCareSchedule(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	csID := uuid.New()
	ltID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		livingRepo.On("GetCareSchedule", ctx, csID).Return(&models.CareSchedule{ID: csID, LivingThingID: ltID}, nil)
		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(&models.LivingThing{ID: ltID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)

		cs, err := svc.GetCareSchedule(ctx, userID, csID)
		require.NoError(t, err)
		assert.Equal(t, csID, cs.ID)
	})
}

func TestLivingService_LogCare(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	csID := uuid.New()
	ltID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		livingRepo.On("GetCareSchedule", ctx, csID).Return(&models.CareSchedule{ID: csID, LivingThingID: ltID}, nil)
		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(&models.LivingThing{ID: ltID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		livingRepo.On("CreateCareLog", ctx, mock.AnythingOfType("*models.CareLog")).Return(&models.CareLog{ID: uuid.New()}, nil)

		cl := &models.CareLog{CareScheduleID: csID}
		result, err := svc.LogCare(ctx, userID, cl)
		require.NoError(t, err)
		assert.NotEqual(t, uuid.Nil, result.ID)
	})
}

func TestLivingService_ListCareLogs(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	scheduleID := uuid.New()
	ltID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		livingRepo := new(mocks.MockLivingRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewLivingService(livingRepo, groupRepo)

		livingRepo.On("GetCareSchedule", ctx, scheduleID).Return(&models.CareSchedule{ID: scheduleID, LivingThingID: ltID}, nil)
		livingRepo.On("GetLivingThingByID", ctx, ltID).Return(&models.LivingThing{ID: ltID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		livingRepo.On("ListCareLogs", ctx, scheduleID, 10, 0).Return([]models.CareLog{{ID: uuid.New()}}, nil)

		logs, err := svc.ListCareLogs(ctx, userID, scheduleID, 10, 0)
		require.NoError(t, err)
		assert.Len(t, logs, 1)
	})
}
