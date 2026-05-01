package jobs

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type mockChoreSchedulerRepo struct {
	mock.Mock
}

func (m *mockChoreSchedulerRepo) ListActiveScheduledChores(ctx context.Context) ([]models.Chore, error) {
	args := m.Called(ctx)
	return args.Get(0).([]models.Chore), args.Error(1)
}

func (m *mockChoreSchedulerRepo) GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error) {
	args := m.Called(ctx, choreID)
	v := args.Get(0)
	if v == nil {
		return nil, args.Error(1)
	}
	return v.(*models.ChoreRotationState), args.Error(1)
}

func (m *mockChoreSchedulerRepo) ScheduleChore(ctx context.Context, assignment *models.ChoreAssignment, stateID uuid.UUID, nextIndex int) error {
	args := m.Called(ctx, assignment, stateID, nextIndex)
	return args.Error(0)
}

func TestChoreScheduler_Run(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreSchedulerRepo)

	choreID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	userA := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	userB := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	stateID := uuid.MustParse("22222222-2222-2222-2222-222222222222")

	chores := []models.Chore{
		{ID: choreID, Name: "Dishes"},
	}

	state := &models.ChoreRotationState{
		ID:           stateID,
		ChoreID:      choreID,
		MemberOrder:  []uuid.UUID{userA, userB},
		CurrentIndex: 0,
	}

	var captured *models.ChoreAssignment
	repo.On("ListActiveScheduledChores", mock.Anything).Return(chores, nil)
	repo.On("GetRotationState", mock.Anything, choreID).Return(state, nil)
	repo.On("ScheduleChore", mock.Anything, mock.MatchedBy(func(a *models.ChoreAssignment) bool {
		captured = a
		return a.ChoreID == choreID
	}), stateID, 1).Return(nil)

	scheduler := newChoreScheduler(repo, log)
	scheduler.Run()

	repo.AssertExpectations(t)
	assert.NotNil(t, captured)
	assert.Equal(t, userA, captured.UserID)
}

func TestChoreScheduler_Run_NoRotationState(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreSchedulerRepo)

	choreID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	chores := []models.Chore{{ID: choreID}}

	repo.On("ListActiveScheduledChores", mock.Anything).Return(chores, nil)
	repo.On("GetRotationState", mock.Anything, choreID).Return(nil, pgx.ErrNoRows)

	scheduler := newChoreScheduler(repo, log)
	scheduler.Run()

	repo.AssertExpectations(t)
	repo.AssertNotCalled(t, "ScheduleChore")
}

func TestChoreScheduler_Run_EmptyMemberOrder(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreSchedulerRepo)

	choreID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	chores := []models.Chore{{ID: choreID}}

	state := &models.ChoreRotationState{
		ID:           uuid.New(),
		ChoreID:      choreID,
		MemberOrder:  []uuid.UUID{},
		CurrentIndex: 0,
	}

	repo.On("ListActiveScheduledChores", mock.Anything).Return(chores, nil)
	repo.On("GetRotationState", mock.Anything, choreID).Return(state, nil)

	scheduler := newChoreScheduler(repo, log)
	scheduler.Run()

	repo.AssertExpectations(t)
	repo.AssertNotCalled(t, "ScheduleChore")
}

func TestChoreScheduler_Run_DeterministicRotation(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreSchedulerRepo)

	choreID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	users := []uuid.UUID{
		uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
		uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
		uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc"),
	}
	stateID := uuid.MustParse("22222222-2222-2222-2222-222222222222")

	chores := []models.Chore{{ID: choreID}}

	for i, expectedUser := range users {
		state := &models.ChoreRotationState{
			ID:           stateID,
			ChoreID:      choreID,
			MemberOrder:  users,
			CurrentIndex: i,
		}

		repo.On("ListActiveScheduledChores", mock.Anything).Return(chores, nil).Once()
		repo.On("GetRotationState", mock.Anything, choreID).Return(state, nil).Once()
		nextIndex := (i + 1) % len(users)
		repo.On("ScheduleChore", mock.Anything, mock.MatchedBy(func(a *models.ChoreAssignment) bool {
			return a.UserID == expectedUser
		}), stateID, nextIndex).Return(nil).Once()

		scheduler := newChoreScheduler(repo, log)
		scheduler.Run()
	}

	repo.AssertExpectations(t)
}
