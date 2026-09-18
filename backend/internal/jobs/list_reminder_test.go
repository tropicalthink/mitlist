package jobs

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type mockListReminderRepo struct {
	mock.Mock
}

func (m *mockListReminderRepo) ListDueReminders(ctx context.Context, before time.Time, limit int) ([]dueListReminder, error) {
	args := m.Called(ctx, before, limit)
	if v := args.Get(0); v != nil {
		return v.([]dueListReminder), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockListReminderRepo) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.([]uuid.UUID), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockListReminderRepo) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.(map[uuid.UUID]*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockListReminderRepo) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	args := m.Called(ctx, notifications)
	return args.Error(0)
}

func (m *mockListReminderRepo) MarkReminderSent(ctx context.Context, listID uuid.UUID, sentAt time.Time) (bool, error) {
	args := m.Called(ctx, listID, sentAt)
	return args.Bool(0), args.Error(1)
}

func TestListReminder_Run_CachesGroupMembersAndPreferences(t *testing.T) {
	log := logger.New("test")
	repo := new(mockListReminderRepo)
	pusher := new(mockPusher)
	groupID := uuid.New()
	authorID := uuid.New()
	memberID := uuid.New()
	remindAt := time.Now().UTC().Add(-time.Minute)

	due := []dueListReminder{
		{List: models.List{ID: uuid.New(), GroupID: groupID, Name: "Groceries", RemindAt: &remindAt}, OpenItems: 3},
		{List: models.List{ID: uuid.New(), GroupID: groupID, Name: "Hardware store", RemindAt: &remindAt}, OpenItems: 0},
	}

	repo.On("ListDueReminders", mock.Anything, mock.AnythingOfType("time.Time"), 200).Return(due, nil)
	repo.On("ListGroupMembers", mock.Anything, groupID).Return([]uuid.UUID{authorID, memberID}, nil).Once()
	repo.On("GetPreferencesByGroup", mock.Anything, groupID).Return(map[uuid.UUID]*models.NotificationPreference{
		memberID: {UserID: memberID, GroupID: groupID, PushEnabled: true, PinwallReminder: true},
	}, nil).Once()
	repo.On("CreateNotificationsBatch", mock.Anything, mock.AnythingOfType("[]models.Notification")).Return(nil).Twice()
	repo.On("MarkReminderSent", mock.Anything, mock.AnythingOfType("uuid.UUID"), mock.AnythingOfType("time.Time")).Return(true, nil).Twice()
	// No stored prefs for the author → all-on default, so they get their own reminder.
	pusher.On("SendToUser", authorID, mock.AnythingOfType("string")).Return(nil).Twice()
	pusher.On("SendToUser", memberID, mock.AnythingOfType("string")).Return(nil).Twice()

	job := &ListReminder{repo: repo, log: log, push: pusher}
	job.Run()

	repo.AssertNumberOfCalls(t, "ListGroupMembers", 1)
	repo.AssertNumberOfCalls(t, "GetPreferencesByGroup", 1)
	pusher.AssertExpectations(t)
}

func TestListReminder_sendForList_SkipsOptedOutAndBuildsPayload(t *testing.T) {
	log := logger.New("test")
	repo := new(mockListReminderRepo)
	pusher := new(mockPusher)

	groupID := uuid.New()
	authorID := uuid.New()
	optedOutID := uuid.New()
	remindAt := time.Date(2026, 9, 20, 10, 0, 0, 0, time.UTC)
	list := models.List{ID: uuid.New(), GroupID: groupID, Name: "Groceries", Type: "shopping", RemindAt: &remindAt}

	cache := &groupReminderCache{
		members: []uuid.UUID{authorID, optedOutID},
		prefs: map[uuid.UUID]*models.NotificationPreference{
			authorID:   {PushEnabled: true, PinwallReminder: true},
			optedOutID: {PushEnabled: true, PinwallReminder: false},
		},
	}

	repo.On("CreateNotificationsBatch", mock.Anything, mock.MatchedBy(func(notifications []models.Notification) bool {
		if len(notifications) != 1 || notifications[0].UserID != authorID {
			return false
		}
		n := notifications[0]
		if n.Type != models.NotificationTypeListReminder || n.Body != "Groceries · 2 items left" {
			return false
		}
		var payload models.NotificationPayload
		if err := json.Unmarshal(n.Data, &payload); err != nil {
			return false
		}
		return payload.Screen == models.ScreenListDetail &&
			payload.EntityType == models.EntityTypeList &&
			payload.ID == list.ID.String() &&
			payload.Copy != nil &&
			payload.Copy.Template == models.NotificationTemplateListReminder &&
			payload.Copy.Params["list_name"] == "Groceries" &&
			payload.Copy.Params["item_count"] == "2" &&
			payload.DedupeKey != ""
	})).Return(nil)
	repo.On("MarkReminderSent", mock.Anything, list.ID, mock.AnythingOfType("time.Time")).Return(true, nil)
	pusher.On("SendToUser", authorID, mock.AnythingOfType("string")).Return(nil)

	job := &ListReminder{repo: repo, log: log, push: pusher}
	err := job.sendForList(context.Background(), dueListReminder{List: list, OpenItems: 2}, cache)
	require.NoError(t, err)
	repo.AssertExpectations(t)
	pusher.AssertExpectations(t)
}

func TestListReminder_sendForList_DispatcherPath(t *testing.T) {
	log := logger.New("test")
	repo := new(mockListReminderRepo)
	dispatcher := &capturedDispatch{}

	groupID := uuid.New()
	remindAt := time.Now().UTC()
	list := models.List{ID: uuid.New(), GroupID: groupID, Name: "Groceries", RemindAt: &remindAt}

	repo.On("MarkReminderSent", mock.Anything, list.ID, mock.AnythingOfType("time.Time")).Return(true, nil)

	job := &ListReminder{repo: repo, log: log, dispatcher: dispatcher}
	err := job.sendForList(context.Background(), dueListReminder{List: list, OpenItems: 1}, &groupReminderCache{})
	require.NoError(t, err)

	assert.Equal(t, models.NotificationTypeListReminder, dispatcher.nType)
	assert.Equal(t, "List reminder", dispatcher.title)
	assert.Equal(t, "Groceries · 1 item left", dispatcher.body)
	assert.Equal(t, groupID.String(), dispatcher.payload.GroupID)
	assert.Equal(t, models.ScreenListDetail, dispatcher.payload.Screen)
	repo.AssertExpectations(t)
}

func TestListReminder_sendForList_NoDeliveryLeavesReminderPending(t *testing.T) {
	log := logger.New("test")
	repo := new(mockListReminderRepo)
	pusher := new(mockPusher)

	remindAt := time.Now().UTC()
	list := models.List{ID: uuid.New(), GroupID: uuid.New(), Name: "Groceries", RemindAt: &remindAt}
	memberID := uuid.New()
	cache := &groupReminderCache{
		members: []uuid.UUID{memberID},
		prefs:   map[uuid.UUID]*models.NotificationPreference{memberID: {PushEnabled: false, PinwallReminder: true}},
	}

	job := &ListReminder{repo: repo, log: log, push: pusher}
	err := job.sendForList(context.Background(), dueListReminder{List: list}, cache)
	require.NoError(t, err)
	repo.AssertNotCalled(t, "MarkReminderSent", mock.Anything, mock.Anything, mock.Anything)
	repo.AssertNotCalled(t, "CreateNotificationsBatch", mock.Anything, mock.Anything)
}
