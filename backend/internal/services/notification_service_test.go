package services

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
	"github.com/mitlist-app/mitlist/internal/sse"
)

func TestNotificationService_CreateNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		notificationRepo.On("CreateNotification", ctx, mock.AnythingOfType("*models.Notification")).Return(nil)

		n := &models.Notification{UserID: userID, Type: "mention", Title: "Hello"}
		err := svc.CreateNotification(ctx, n)
		require.NoError(t, err)
	})
}

func TestNotificationService_GetNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success owner", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)

		n, err := svc.GetNotification(ctx, userID, notificationID)
		require.NoError(t, err)
		assert.Equal(t, notificationID, n.ID)
	})

	t.Run("wrong owner", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: uuid.New()}, nil)

		_, err := svc.GetNotification(ctx, userID, notificationID)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestNotificationService_MarkAsRead(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)
		notificationRepo.On("MarkAsRead", ctx, notificationID).Return(nil)

		err := svc.MarkAsRead(ctx, userID, notificationID)
		require.NoError(t, err)
	})
}

func TestNotificationService_CountUnreadNotifications(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationRepo := new(mocks.MockNotificationRepo)
	svc := NewNotificationService(notificationRepo, nil, nil, nil)

	notificationRepo.On("CountUnreadNotifications", ctx, userID).Return(4, nil)
	count, err := svc.CountUnreadNotifications(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, 4, count)
}

func TestNotificationService_DeleteNotification(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	notificationID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		notificationRepo.On("GetNotificationByID", ctx, notificationID).Return(&models.Notification{ID: notificationID, UserID: userID}, nil)
		notificationRepo.On("DeleteNotification", ctx, notificationID).Return(nil)

		err := svc.DeleteNotification(ctx, userID, notificationID)
		require.NoError(t, err)
	})
}

func TestDefaultNotificationPreference(t *testing.T) {
	userID := uuid.New()
	groupID := uuid.New()
	pref := models.DefaultNotificationPreference(userID, groupID)

	assert.Equal(t, userID, pref.UserID)
	assert.Equal(t, groupID, pref.GroupID)
	assert.True(t, pref.ChoreDue, "ChoreDue should be true")
	assert.True(t, pref.ChoreDueDayOf, "ChoreDueDayOf should be true")
	assert.True(t, pref.ListItemAdded, "ListItemAdded should be true")
	assert.True(t, pref.ExpenseCreated, "ExpenseCreated should be true")
	assert.True(t, pref.MealPlanChanged, "MealPlanChanged should be true")
	assert.True(t, pref.WeeklyDigest, "WeeklyDigest should be true")
	assert.True(t, pref.PinwallReminder, "PinwallReminder should be true (regression: was missing from notification_service default)")
	assert.True(t, pref.PushEnabled, "PushEnabled should be true")
}

func TestPreferenceForType_MoneyActivity(t *testing.T) {
	pref := &models.NotificationPreference{ExpenseCreated: false}
	for _, nType := range []string{
		models.NotificationTypeExpenseCreated,
		models.NotificationTypeRecurringExpenseCreated,
		models.NotificationTypeSettlementRequested,
		models.NotificationTypeSettlementConfirmed,
		models.NotificationTypeSettlementDeclined,
	} {
		assert.False(t, preferenceForType(pref, nType), nType)
	}

	pref.ExpenseCreated = true
	for _, nType := range []string{
		models.NotificationTypeExpenseCreated,
		models.NotificationTypeRecurringExpenseCreated,
		models.NotificationTypeSettlementRequested,
		models.NotificationTypeSettlementConfirmed,
		models.NotificationTypeSettlementDeclined,
	} {
		assert.True(t, preferenceForType(pref, nType), nType)
	}
}

func TestNotificationService_DispatchToGroup(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	actorID := uuid.New()
	member1 := uuid.New()
	member2 := uuid.New()

	memberships := []models.GroupMembership{
		{UserID: actorID},
		{UserID: member1},
		{UserID: member2},
	}

	t.Run("queues complete list item events for a digest", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)
		listID := uuid.New()
		payload := models.NotificationPayload{
			Screen: models.ScreenListDetail, EntityType: models.EntityTypeList,
			ID: listID.String(), GroupID: groupID.String(), ActorName: "Mina",
			EntityName: "Groceries", ItemName: "Milk",
		}
		notifRepo.On("QueueListItemNotification", ctx, groupID, actorID, listID, "Mina", "Groceries", "Milk").Return(nil)

		err := svc.DispatchToGroup(ctx, groupID, actorID, models.NotificationTypeListItemAdded, "T", "B", payload)

		require.NoError(t, err)
		notifRepo.AssertNotCalled(t, "CreateNotificationsBatch", mock.Anything, mock.Anything)
		groupRepo.AssertNotCalled(t, "ListMembershipsByGroup", mock.Anything, mock.Anything)
	})

	t.Run("persists rows and pushes for eligible members, excludes actor", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notifRepo, nil, groupRepo, pushSvc)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return(memberships, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.MatchedBy(func(rows []models.Notification) bool {
			if len(rows) != 2 {
				return false
			}
			for _, r := range rows {
				if r.UserID == actorID {
					return false
				}
			}
			return true
		})).Return(nil)
		pushSvc.On("SendToUser", mock.AnythingOfType("uuid.UUID"), mock.AnythingOfType("string")).Return(nil)

		payload := models.NotificationPayload{Screen: models.ScreenListDetail, EntityType: models.EntityTypeList}
		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertCalled(t, "CreateNotificationsBatch", ctx, mock.Anything)
	})

	t.Run("persists in-app rows with PushEnabled=false", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notifRepo, nil, groupRepo, pushSvc)

		disabledPref := &models.NotificationPreference{
			UserID: member1, GroupID: groupID, PushEnabled: false, ListItemAdded: true,
		}
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: actorID},
			{UserID: member1},
		}, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{
			member1: disabledPref,
		}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.MatchedBy(func(rows []models.Notification) bool {
			return len(rows) == 1 && rows[0].UserID == member1
		})).Return(nil)

		payload := models.NotificationPayload{}
		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertCalled(t, "CreateNotificationsBatch", ctx, mock.Anything)
		pushSvc.AssertNotCalled(t, "SendToUser")
	})

	t.Run("fails closed when preferences cannot be loaded", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return(memberships, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(nil, assert.AnError)

		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", models.NotificationPayload{})
		require.ErrorIs(t, err, assert.AnError)
		notifRepo.AssertNotCalled(t, "CreateNotificationsBatch")
	})

	t.Run("skips members with type-specific pref disabled", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)

		typePref := &models.NotificationPreference{
			UserID: member1, GroupID: groupID, PushEnabled: true, ListItemAdded: false,
		}
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: actorID},
			{UserID: member1},
		}, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{
			member1: typePref,
		}, nil)

		payload := models.NotificationPayload{}
		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertNotCalled(t, "CreateNotificationsBatch")
	})

	t.Run("no-op with zero eligible members (all excluded/opted-out)", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)

		// Only the actor in the group.
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: actorID},
		}, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)

		payload := models.NotificationPayload{}
		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertNotCalled(t, "CreateNotificationsBatch")
	})

	t.Run("push invoked for eligible users", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notifRepo, nil, groupRepo, pushSvc)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: actorID},
			{UserID: member1},
		}, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		var persistedID uuid.UUID
		notifRepo.On("CreateNotificationsBatch", ctx, mock.MatchedBy(func(rows []models.Notification) bool {
			if len(rows) != 1 {
				return false
			}
			persistedID = rows[0].ID
			return persistedID != uuid.Nil
		})).Return(nil)
		sent := make(chan string, 1)
		pushSvc.On("SendToUser", member1, mock.AnythingOfType("string")).
			Run(func(args mock.Arguments) { sent <- args.String(1) }).
			Return(nil)

		payload := models.NotificationPayload{Copy: models.NewNotificationCopy(
			models.NotificationTemplateChoreDueSoon,
			map[string]string{"chore_name": "Dishes"},
		)}
		err := svc.DispatchToGroup(ctx, groupID, actorID, "list_item_added", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertCalled(t, "CreateNotificationsBatch", ctx, mock.Anything)
		select {
		case raw := <-sent:
			var pushPayload struct {
				Data map[string]string `json:"data"`
			}
			require.NoError(t, json.Unmarshal([]byte(raw), &pushPayload))
			assert.Equal(t, persistedID.String(), pushPayload.Data["notification_id"])
			var copy models.NotificationCopy
			require.NoError(t, json.Unmarshal([]byte(pushPayload.Data["copy"]), &copy))
			assert.Equal(t, models.NotificationTemplateChoreDueSoon, copy.Template)
		case <-time.After(time.Second):
			t.Fatal("timed out waiting for async push")
		}
	})
}

func TestNotificationService_DispatchToUsers(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()

	t.Run("persists row and pushes for eligible user", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notifRepo, nil, groupRepo, pushSvc)

		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.MatchedBy(func(rows []models.Notification) bool {
			return len(rows) == 1 && rows[0].UserID == userID && rows[0].Type == "chore_due"
		})).Return(nil)
		pushSvc.On("SendToUser", userID, mock.AnythingOfType("string")).Return(nil)

		payload := models.NotificationPayload{Screen: models.ScreenChoreDetail, EntityType: models.EntityTypeChore}
		err := svc.DispatchToUsers(ctx, []uuid.UUID{userID}, groupID, "chore_due", "Chore Reminder", "Due soon", payload)
		require.NoError(t, err)
		notifRepo.AssertCalled(t, "CreateNotificationsBatch", ctx, mock.Anything)
	})

	t.Run("no-op for empty userIDs", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)

		payload := models.NotificationPayload{}
		err := svc.DispatchToUsers(ctx, []uuid.UUID{}, groupID, "chore_due", "T", "B", payload)
		require.NoError(t, err)
		notifRepo.AssertNotCalled(t, "GetPreferencesByGroup")
		notifRepo.AssertNotCalled(t, "CreateNotificationsBatch")
	})

	t.Run("blocking delivery returns push failure", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		pushSvc := new(mocks.MockPushService)
		svc := NewNotificationService(notifRepo, nil, groupRepo, pushSvc)

		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.Anything).Return(nil)
		pushSvc.On("SendToUser", userID, mock.AnythingOfType("string")).Return(errors.New("provider unavailable"))

		err := svc.DispatchToUsersAndWait(ctx, []uuid.UUID{userID}, groupID, "chore_due", "T", "B", models.NotificationPayload{})
		require.ErrorContains(t, err, "provider unavailable")
	})
}

func TestNotificationService_UpdatePreferences(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewNotificationService(notificationRepo, nil, groupRepo, nil)

		notificationRepo.On("UpsertPreference", ctx, mock.AnythingOfType("*models.NotificationPreference")).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{
			GroupID: groupID,
			UserID:  userID,
			Role:    "member",
		}, nil)

		pref := &models.NotificationPreference{UserID: userID, GroupID: groupID, ChoreDue: false}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.NoError(t, err)
	})

	t.Run("wrong user", func(t *testing.T) {
		notificationRepo := new(mocks.MockNotificationRepo)
		svc := NewNotificationService(notificationRepo, nil, nil, nil)

		pref := &models.NotificationPreference{UserID: uuid.New(), GroupID: groupID}
		err := svc.UpdatePreferences(ctx, userID, pref)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestNotificationService_GetPreferencesIncludesUnsavedDefaults(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	notifRepo := new(mocks.MockNotificationRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewNotificationService(notifRepo, nil, groupRepo, nil)

	notifRepo.On("GetPreferencesByUser", ctx, userID).Return([]models.NotificationPreference{}, nil)
	groupRepo.On("ListGroupsByUser", ctx, userID, 500, 0).Return([]models.Group{{ID: groupID}}, nil)

	prefs, err := svc.GetPreferences(ctx, userID)
	require.NoError(t, err)
	require.Len(t, prefs, 1)
	assert.Equal(t, groupID, prefs[0].GroupID)
	assert.True(t, prefs[0].PushEnabled)
	assert.False(t, prefs[0].EmailEnabled)
}

func TestDispatchToGroup_PublishesSSE(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	actorID := uuid.New()
	member1 := uuid.New()

	memberships := []models.GroupMembership{
		{UserID: actorID},
		{UserID: member1},
	}

	t.Run("publishes notification:created event when hub is set", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return(memberships, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.Anything).Return(nil)

		hub := sse.New()
		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)
		svc.SetHub(hub)

		ch := hub.Subscribe(groupID.String(), "")
		defer hub.Unsubscribe(groupID.String(), ch)

		err := svc.DispatchToGroup(ctx, groupID, actorID, "expense_created", "T", "B", models.NotificationPayload{})
		require.NoError(t, err)

		select {
		case data := <-ch:
			var ev sse.Event
			require.NoError(t, json.Unmarshal(data, &ev))
			assert.Equal(t, "notification:created", ev.Type)
			assert.Equal(t, groupID.String(), ev.GroupID)
		case <-time.After(time.Second):
			t.Fatal("expected a notification:created SSE event within 1s")
		}
	})

	t.Run("no hub set: DispatchToGroup returns nil without panic", func(t *testing.T) {
		notifRepo := new(mocks.MockNotificationRepo)
		groupRepo := new(mocks.MockGroupRepo)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return(memberships, nil)
		notifRepo.On("GetPreferencesByGroup", ctx, groupID).Return(map[uuid.UUID]*models.NotificationPreference{}, nil)
		notifRepo.On("CreateNotificationsBatch", ctx, mock.Anything).Return(nil)

		svc := NewNotificationService(notifRepo, nil, groupRepo, nil)
		// hub is nil by default — nil-guard must protect

		err := svc.DispatchToGroup(ctx, groupID, actorID, "expense_created", "T", "B", models.NotificationPayload{})
		require.NoError(t, err)
	})
}
