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
		svc := NewChoreService(choreRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)
		choreRepo.On("CreateChore", ctx, mock.AnythingOfType("*models.Chore")).Return(nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: uuid.New()}, {UserID: uuid.New()},
		}, nil)
		choreRepo.On("CreateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)
		choreRepo.On("UpdateRotationState", ctx, mock.MatchedBy(func(state *models.ChoreRotationState) bool {
			return state.CurrentIndex == 1
		})).Return(nil)

		chore := &models.Chore{GroupID: groupID, Name: "Clean"}
		err := svc.CreateChore(ctx, user, chore)
		require.NoError(t, err)
	})

	t.Run("no assignment creates no initial assignment", func(t *testing.T) {
		choreRepo := new(mocks.MockChoreRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(choreRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)
		choreRepo.On("CreateChore", ctx, mock.AnythingOfType("*models.Chore")).Return(nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: uuid.New()}, {UserID: uuid.New()},
		}, nil)
		choreRepo.On("CreateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)

		err := svc.CreateChore(ctx, user, &models.Chore{
			GroupID:        groupID,
			Name:           "Clean",
			AssignmentType: "no-assignment",
		})
		require.NoError(t, err)
		choreRepo.AssertNotCalled(t, "CreateAssignment", mock.Anything, mock.Anything)
	})

	t.Run("not admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(nil, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

		err := svc.CreateChore(ctx, user, &models.Chore{GroupID: groupID, Name: "Clean"})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})

	t.Run("missing name", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewChoreService(nil, groupRepo, nil)

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
		svc := NewChoreService(choreRepo, groupRepo, nil)

		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		c, err := svc.GetChore(ctx, user, choreID)
		require.NoError(t, err)
		assert.Equal(t, choreID, c.ID)
	})
}

func TestChoreService_GetChoreDetails(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	assignmentID := uuid.New()
	now := time.Now().UTC()
	averageHours := 36.0

	choreRepo := new(mocks.MockChoreRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(choreRepo, groupRepo, nil)

	choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{
		ID:      choreID,
		GroupID: groupID,
		Name:    "Clean counters",
	}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
	dueSoon := now.Add(24 * time.Hour)
	choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{
		ID:         assignmentID,
		ChoreID:    choreID,
		UserID:     user.ID,
		Status:     "pending",
		DueDate:    &dueSoon,
		AssignedAt: now.Add(-time.Hour),
	}, nil)
	choreRepo.On("ListAssignments", ctx, choreID, 100, 0).Return([]models.ChoreAssignment{
		{ID: assignmentID, ChoreID: choreID, UserID: user.ID, Status: "pending", DueDate: &dueSoon, AssignedAt: now.Add(-time.Hour)},
		{ID: uuid.New(), ChoreID: choreID, UserID: user.ID, Status: "completed", AssignedAt: now.Add(-48 * time.Hour), CompletedAt: ptrTime(now.Add(-47 * time.Hour))},
	}, nil)
	choreRepo.On("GetChoreStats", ctx, choreID).Return(&models.ChoreStats{
		TrackedCount:          3,
		LastTrackedAt:         ptrTime(now.Add(-47 * time.Hour)),
		LastDoneByUserID:      &user.ID,
		AverageFrequencyHours: &averageHours,
	}, nil)

	details, err := svc.GetChoreDetails(ctx, user, choreID, 7)
	require.NoError(t, err)
	assert.Equal(t, choreID, details.Chore.ID)
	assert.Equal(t, 3, details.Stats.TrackedCount)
	assert.Equal(t, "due_soon", details.DueStatus)
	assert.True(t, details.AssignedToMe)
	require.NotNil(t, details.LastAssignment)
	assert.Equal(t, "completed", details.LastAssignment.Status)
}

func TestChoreService_ListCurrentChores(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()
	choreID := uuid.New()
	assignmentID := uuid.New()
	due := time.Now().UTC().Add(24 * time.Hour)

	choreRepo := new(mocks.MockChoreRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(choreRepo, groupRepo, nil)

	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
	choreRepo.On("ListCurrentChoresByGroup", ctx, groupID, 50, 0).Return([]models.CurrentChore{
		{
			Chore: models.Chore{ID: choreID, GroupID: groupID, Name: "Vacuum"},
			PendingAssignment: &models.ChoreAssignment{
				ID:         assignmentID,
				ChoreID:    choreID,
				UserID:     user.ID,
				Status:     "pending",
				DueDate:    &due,
				AssignedAt: time.Now().UTC(),
			},
		},
	}, nil)

	current, err := svc.ListCurrentChores(ctx, user, groupID, 50, 0, 7)
	require.NoError(t, err)
	require.Len(t, current, 1)
	assert.True(t, current[0].AssignedToMe)
	assert.NotEmpty(t, current[0].DueStatus)
}

func TestChoreService_ListCurrentChores_RequiresMembership(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(nil, groupRepo, nil)

	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(nil, pgx.ErrNoRows)

	_, err := svc.ListCurrentChores(ctx, user, groupID, 50, 0, 7)
	require.Error(t, err)
	assert.IsType(t, &api.PermissionDeniedError{}, err)
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
		svc := NewChoreService(choreRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "admin"}, nil)
		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(nil, pgx.ErrNoRows)
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
		svc := NewChoreService(choreRepo, groupRepo, nil)

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
		svc := NewChoreService(choreRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
		choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{ID: assignID, ChoreID: choreID}, nil)
		choreRepo.On("UpdateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
			ChoreID: choreID, MemberOrder: []uuid.UUID{member1}, CurrentIndex: 0,
		}, nil)
		choreRepo.On("UpdateRotationState", ctx, mock.AnythingOfType("*models.ChoreRotationState")).Return(nil)
		choreRepo.On("CreateAssignment", ctx, mock.AnythingOfType("*models.ChoreAssignment")).Return(nil)

		err := svc.SkipChore(ctx, user, choreID, nil)
		require.NoError(t, err)
	})
}

func TestChoreService_RescheduleChore(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	assignID := uuid.New()
	newDue := time.Now().UTC().Add(48 * time.Hour)

	choreRepo := new(mocks.MockChoreRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(choreRepo, groupRepo, nil)

	choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
	choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{
		ID:         assignID,
		ChoreID:    choreID,
		UserID:     user.ID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}, nil)
	choreRepo.On("UpdateAssignment", ctx, mock.MatchedBy(func(a *models.ChoreAssignment) bool {
		return a.ID == assignID && a.DueDate != nil && a.DueDate.Equal(newDue)
	})).Return(nil)

	err := svc.RescheduleChore(ctx, user, choreID, &newDue, nil)
	require.NoError(t, err)
}

func TestChoreService_RescheduleChore_RejectsPastDueDate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	past := time.Now().UTC().Add(-2 * time.Hour)

	choreRepo := new(mocks.MockChoreRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(choreRepo, groupRepo, nil)

	choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

	err := svc.RescheduleChore(ctx, user, choreID, &past, nil)
	require.Error(t, err)
	assert.IsType(t, &api.ValidationError{}, err)
}

func TestChoreService_UndoLastChoreExecution_RestoresSuccessorRotation(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	choreID := uuid.New()
	groupID := uuid.New()
	member1 := uuid.New()
	member2 := uuid.New()
	finishedID := uuid.New()
	pendingID := uuid.New()
	stateID := uuid.New()
	completedAt := time.Now().UTC()

	choreRepo := new(mocks.MockChoreRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewChoreService(choreRepo, groupRepo, nil)

	choreRepo.On("GetChoreByID", ctx, choreID).Return(&models.Chore{ID: choreID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
	choreRepo.On("ListAssignments", ctx, choreID, 100, 0).Return([]models.ChoreAssignment{
		{
			ID:          finishedID,
			ChoreID:     choreID,
			UserID:      member1,
			Status:      "completed",
			AssignedAt:  completedAt.Add(-time.Hour),
			CompletedAt: &completedAt,
		},
	}, nil)
	choreRepo.On("GetPendingAssignmentByChore", ctx, choreID).Return(&models.ChoreAssignment{
		ID:         pendingID,
		ChoreID:    choreID,
		UserID:     member2,
		Status:     "pending",
		AssignedAt: completedAt,
	}, nil)
	choreRepo.On("DeleteAssignment", ctx, pendingID).Return(nil)
	choreRepo.On("UpdateAssignment", ctx, mock.MatchedBy(func(a *models.ChoreAssignment) bool {
		return a.ID == finishedID && a.Status == "pending" && a.CompletedAt == nil
	})).Return(nil)
	choreRepo.On("GetRotationState", ctx, choreID).Return(&models.ChoreRotationState{
		ID:           stateID,
		ChoreID:      choreID,
		MemberOrder:  []uuid.UUID{member1, member2},
		CurrentIndex: 0,
	}, nil)
	choreRepo.On("UpdateRotationState", ctx, mock.MatchedBy(func(state *models.ChoreRotationState) bool {
		return state.ID == stateID && state.CurrentIndex == 1
	})).Return(nil)

	err := svc.UndoLastChoreExecution(ctx, user, choreID)
	require.NoError(t, err)
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
		svc := NewChoreService(choreRepo, groupRepo, nil)

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
		svc := NewChoreService(choreRepo, groupRepo, nil)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{{UserID: member1}}, nil)
		choreRepo.On("ListChoresByGroup", ctx, groupID, 0, 0).Return([]models.Chore{{ID: choreID}}, nil)
		choreRepo.On("GetRotationState", ctx, choreID).Return(nil, pgx.ErrNoRows)

		err := svc.RebuildMemberOrdersForGroup(ctx, groupID)
		require.NoError(t, err)
	})
}

func ptrTime(t time.Time) *time.Time {
	return &t
}
