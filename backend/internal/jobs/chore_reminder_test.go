package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/pkg/logger"
)

type mockChoreReminderRepo struct {
	mock.Mock
}

func (m *mockChoreReminderRepo) ListPendingAssignmentsDueSoon(ctx context.Context, cutoff time.Time) ([]models.ChoreAssignment, error) {
	args := m.Called(ctx, cutoff)
	return args.Get(0).([]models.ChoreAssignment), args.Error(1)
}

func (m *mockChoreReminderRepo) GetChoreName(ctx context.Context, choreID uuid.UUID) (string, error) {
	args := m.Called(ctx, choreID)
	return args.String(0), args.Error(1)
}

type mockPusher struct {
	mock.Mock
}

func (m *mockPusher) SendToUser(userID uuid.UUID, payload string) error {
	args := m.Called(userID, payload)
	return args.Error(0)
}

func (m *mockPusher) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	args := m.Called(groupID, payload)
	return args.Error(0)
}

func TestChoreReminder_Run(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreReminderRepo)
	pusher := new(mockPusher)

	assignmentID := uuid.New()
	choreID := uuid.New()
	userID := uuid.New()

	assignments := []models.ChoreAssignment{
		{ID: assignmentID, ChoreID: choreID, UserID: userID},
	}

	repo.On("ListPendingAssignmentsDueSoon", mock.Anything, mock.AnythingOfType("time.Time")).Return(assignments, nil)
	repo.On("GetChoreName", mock.Anything, choreID).Return("Dishes", nil)
	pusher.On("SendToUser", userID, mock.AnythingOfType("string")).Return(nil)

	reminder := newChoreReminder(repo, pusher, log)
	reminder.Run()

	repo.AssertExpectations(t)
	pusher.AssertExpectations(t)
}

func TestChoreReminder_Run_ListError(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreReminderRepo)
	pusher := new(mockPusher)

	repo.On("ListPendingAssignmentsDueSoon", mock.Anything, mock.AnythingOfType("time.Time")).Return([]models.ChoreAssignment{}, assert.AnError)

	reminder := newChoreReminder(repo, pusher, log)
	reminder.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}
