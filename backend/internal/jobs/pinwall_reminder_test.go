package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type mockPinwallReminderRepo struct {
	mock.Mock
}

func (m *mockPinwallReminderRepo) ListDueReminders(ctx context.Context, before time.Time, limit int) ([]models.PinwallPost, error) {
	args := m.Called(ctx, before, limit)
	if v := args.Get(0); v != nil {
		return v.([]models.PinwallPost), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockPinwallReminderRepo) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.([]uuid.UUID), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockPinwallReminderRepo) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	args := m.Called(ctx, userID, groupID)
	if v := args.Get(0); v != nil {
		return v.(*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockPinwallReminderRepo) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.(map[uuid.UUID]*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockPinwallReminderRepo) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	args := m.Called(ctx, notifications)
	return args.Error(0)
}

func (m *mockPinwallReminderRepo) MarkReminderSent(ctx context.Context, postID uuid.UUID, sentAt time.Time) (bool, error) {
	args := m.Called(ctx, postID, sentAt)
	return args.Bool(0), args.Error(1)
}

func TestPinwallReminder_Run_CachesGroupMembersAndPreferences(t *testing.T) {
	log := logger.New("test")
	repo := new(mockPinwallReminderRepo)
	pusher := new(mockPusher)
	groupID := uuid.New()
	authorID := uuid.New()
	memberID := uuid.New()
	remindAt := time.Now().UTC().Add(-time.Minute)

	posts := []models.PinwallPost{
		{ID: uuid.New(), GroupID: groupID, UserID: authorID, Content: "First", RemindAt: &remindAt},
		{ID: uuid.New(), GroupID: groupID, UserID: authorID, Content: "Second", RemindAt: &remindAt},
	}

	repo.On("ListDueReminders", mock.Anything, mock.AnythingOfType("time.Time"), 200).Return(posts, nil)
	repo.On("ListGroupMembers", mock.Anything, groupID).Return([]uuid.UUID{authorID, memberID}, nil).Once()
	repo.On("GetPreferencesByGroup", mock.Anything, groupID).Return(map[uuid.UUID]*models.NotificationPreference{
		memberID: {UserID: memberID, GroupID: groupID, PushEnabled: true, PinwallReminder: true},
	}, nil).Once()
	repo.On("CreateNotificationsBatch", mock.Anything, mock.AnythingOfType("[]models.Notification")).Return(nil).Twice()
	repo.On("MarkReminderSent", mock.Anything, mock.AnythingOfType("uuid.UUID"), mock.AnythingOfType("time.Time")).Return(true, nil).Twice()
	pusher.On("SendToUser", memberID, mock.AnythingOfType("string")).Return(nil).Twice()

	job := &PinwallReminder{repo: repo, log: log, push: pusher}
	job.Run()

	repo.AssertNumberOfCalls(t, "ListGroupMembers", 1)
	repo.AssertNumberOfCalls(t, "GetPreferencesByGroup", 1)
	repo.AssertNotCalled(t, "GetUserPreference", mock.Anything, mock.Anything, mock.Anything)
	pusher.AssertExpectations(t)
}

func TestPinwallReminder_sendForPost_SkipsAuthorAndOptedOutMembers(t *testing.T) {
	log := logger.New("test")
	repo := new(mockPinwallReminderRepo)
	pusher := new(mockPusher)

	groupID := uuid.New()
	authorID := uuid.New()
	memberID := uuid.New()
	optedOutID := uuid.New()
	remindAt := time.Now().UTC()
	post := models.PinwallPost{ID: uuid.New(), GroupID: groupID, UserID: authorID, Content: "Pay rent", RemindAt: &remindAt}

	cache := &groupReminderCache{
		members: []uuid.UUID{authorID, memberID, optedOutID},
		prefs: map[uuid.UUID]*models.NotificationPreference{
			memberID:   {PushEnabled: true, PinwallReminder: true},
			optedOutID: {PushEnabled: true, PinwallReminder: false},
		},
	}

	repo.On("CreateNotificationsBatch", mock.Anything, mock.MatchedBy(func(notifications []models.Notification) bool {
		return len(notifications) == 1 && notifications[0].UserID == memberID
	})).Return(nil)
	repo.On("MarkReminderSent", mock.Anything, post.ID, mock.AnythingOfType("time.Time")).Return(true, nil)
	pusher.On("SendToUser", memberID, mock.AnythingOfType("string")).Return(nil)

	job := &PinwallReminder{repo: repo, log: log, push: pusher}
	err := job.sendForPost(context.Background(), post, cache)
	assert.NoError(t, err)
}
