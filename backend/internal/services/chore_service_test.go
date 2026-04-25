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

func TestChoreService_CreateChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)
		choreRepo.On("CreateChore", ctx, mock.AnythingOfType("*models.Chore")).Return(nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: uuid.New()}, {UserID: uuid.New()},
		}, nil)
		choreRepo.On("CreateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)

		chore := &models.Chore{GroupID: groupID, Name: "Clean"}
		err := svc.CreateChore(ctx, user, chore)
		require.NoError(t, err)
	})

	t.Run("not admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

		err := svc.CreateChore(ctx, user, &models.Chore{GroupID: groupID, Name: "Clean"})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})

	t.Run("missing name", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)

		err := svc.CreateChore(ctx, user, &models.Chore{GroupID: groupID, Name: ""})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestChoreService_GetChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		c, err := svc.GetChore(ctx, user, choreID)
		require.NoError(t, err)
		assert.Equal(t, choreID, c.ID)
	})
}

func TestChoreService_RotateChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	member1 := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)
		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
			ChoreID: choreID, MemberOrder: []uuid.UUID{member1}, CurrentIndex: 0,
		}, nil)
		choreRepo.On("UpdateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)

		err := svc.RotateChore(ctx, user, choreID)
		require.NoError(t, err)
	})
}

func TestChoreService_CompleteChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	member1 := uuid.New()
	assignID := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{ID: assignID, ChoreID: choreID}, nil)
		choreRepo.On("UpdateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)
		choreRepo.On("CreateCompletion", ctx, mock.AnythingOfType("*models.ChoreCompletion")).Return(nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
			ChoreID: choreID, MemberOrder: []uuid.UUID{member1}, CurrentIndex: 0,
		}, nil)
		choreRepo.On("UpdateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)

		err := svc.CompleteChore(ctx, user, choreID, nil)
		require.NoError(t, err)
	})
}

func TestChoreService_SkipChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	member1 := uuid.New()
	assignID := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{ID: assignID, ChoreID: choreID}, nil)
		choreRepo.On("UpdateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
			ChoreID: choreID, MemberOrder: []uuid.UUID{member1}, CurrentIndex: 0,
		}, nil)
		choreRepo.On("UpdateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)

		err := svc.SkipChore(ctx, user, choreID)
		require.NoError(t, err)
	})
}

func TestChoreService_RebuildMemberOrdersForGroup(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	choreID := uuid.New()
	member1 := uuid.New()
	member2 := uuid.New()

	t.Run("success", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: member1}, {UserID: member2},
		}, nil)
		choreRepo.On("ListChoresByGroup", ctx, groupID, 0, 0).Return([]models.Chore{{ID: choreID}}, nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
			ID: uuid.New(), ChoreID: choreID, MemberOrder: []uuid.UUID{member1}, CurrentIndex: 0,
		}, nil)
		choreRepo.On("BulkUpdateRotationStates", ctx, mock.AnythingOfType("[]models.ChoreRotationState")).Return(nil)

		err := svc.RebuildMemberOrdersForGroup(ctx, groupID)
		require.NoError(t, err)
	})

	t.Run("no rotation state skips", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{{UserID: member1}}, nil)
		choreRepo.On("ListChoresByGroup", ctx, groupID, 0, 0).Return([]models.Chore{{ID: choreID}}, nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(nil, pgx.ErrNoRows)

		err := svc.RebuildMemberOrdersForGroup(ctx, groupID)
		require.NoError(t, err)
	})
}
