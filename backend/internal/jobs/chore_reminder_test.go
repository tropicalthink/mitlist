package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
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

func (m *mockChoreReminderRepo) GetChoreGroupID(ctx context.Context, choreID uuid.UUID) (uuid.UUID, error) {
	args := m.Called(ctx, choreID)
	return args.Get(0).(uuid.UUID), args.Error(1)
}

func (m *mockChoreReminderRepo) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	args := m.Called(ctx, userID, groupID)
	if p := args.Get(0); p != nil {
		return p.(*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
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

func (m *mockPusher) BroadcastToGroupExcluding(groupID, excludeUserID uuid.UUID, payload string) error {
	args := m.Called(groupID, excludeUserID, payload)
	return args.Error(0)
}

func TestChoreReminder_Run(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreReminderRepo)
	pusher := new(mockPusher)

	assignmentID := uuid.New()
	choreID := uuid.New()
	userID := uuid.New()
	groupID := uuid.New()

	assignments := []models.ChoreAssignment{
		{ID: assignmentID, ChoreID: choreID, UserID: userID},
	}

	repo.On("ListPendingAssignmentsDueSoon", mock.Anything, mock.AnythingOfType("time.Time")).Return(assignments, nil)
	repo.On("GetChoreGroupID", mock.Anything, choreID).Return(groupID, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:      userID,
		GroupID:     groupID,
		ChoreDue:    true,
		PushEnabled: true,
	}, nil)
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

func TestChoreReminder_Run_RespectsChoreDueOptOut(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreReminderRepo)
	pusher := new(mockPusher)

	assignmentID := uuid.New()
	choreID := uuid.New()
	userID := uuid.New()
	groupID := uuid.New()

	assignments := []models.ChoreAssignment{
		{ID: assignmentID, ChoreID: choreID, UserID: userID},
	}

	repo.On("ListPendingAssignmentsDueSoon", mock.Anything, mock.AnythingOfType("time.Time")).Return(assignments, nil)
	repo.On("GetChoreGroupID", mock.Anything, choreID).Return(groupID, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:      userID,
		GroupID:     groupID,
		ChoreDue:    false,
		PushEnabled: true,
	}, nil)

	reminder := newChoreReminder(repo, pusher, log)
	reminder.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}

func TestChoreReminder_Run_RespectsPushDisabled(t *testing.T) {
	log := logger.New("test")
	repo := new(mockChoreReminderRepo)
	pusher := new(mockPusher)

	assignmentID := uuid.New()
	choreID := uuid.New()
	userID := uuid.New()
	groupID := uuid.New()

	assignments := []models.ChoreAssignment{
		{ID: assignmentID, ChoreID: choreID, UserID: userID},
	}

	repo.On("ListPendingAssignmentsDueSoon", mock.Anything, mock.AnythingOfType("time.Time")).Return(assignments, nil)
	repo.On("GetChoreGroupID", mock.Anything, choreID).Return(groupID, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:      userID,
		GroupID:     groupID,
		ChoreDue:    true,
		PushEnabled: false,
	}, nil)

	reminder := newChoreReminder(repo, pusher, log)
	reminder.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}
