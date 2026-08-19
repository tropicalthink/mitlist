package repositories

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestNotificationRepository_CreateNotification(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)

	n := &models.Notification{
		UserID:    fixedUUID(),
		GroupID:   fixedUUID(),
		Type:      "info",
		Title:     "Hello",
		Body:      "World",
		Data:      []byte(`{"key":"value"}`),
		IsRead:    false,
		ReadAt:    nil,
		CreatedAt: fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(fixedUUID(), n.UserID, n.GroupID, n.Type, n.Title, n.Body, n.Data, false, nil, fixedTime())

	mock.ExpectQuery("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), n.UserID, n.GroupID, n.Type, n.Title, n.Body, n.Data, false, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	err := repo.CreateNotification(context.Background(), n)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, n.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_QueueListItemNotification(t *testing.T) {
	mockDB := newMockDB(t)
	repo := NewNotificationRepository(mockDB)
	groupID, actorID, listID := uuid.New(), uuid.New(), uuid.New()

	mockDB.ExpectExec("INSERT INTO list_notification_batches").
		WithArgs(groupID, actorID, listID, "Mina", "Groceries", "Milk").
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.QueueListItemNotification(context.Background(), groupID, actorID, listID, "Mina", "Groceries", "Milk")
	require.NoError(t, err)
	assert.NoError(t, mockDB.ExpectationsWereMet())
}

func TestNotificationRepository_GetNotificationByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), "info", "Hello", "World", []byte(`{}`), false, nil, fixedTime())

	mock.ExpectQuery("SELECT .* FROM notifications WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	n, err := repo.GetNotificationByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, n.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_GetNotificationByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM notifications WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	n, err := repo.GetNotificationByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, n)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_ListNotificationsByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(fixedUUID(), uid, fixedUUID(), "info", "Hello", "World", []byte(`{}`), false, nil, fixedTime())

	mock.ExpectQuery("SELECT .* FROM notifications WHERE user_id = .*").
		WithArgs(uid, 50, 0).
		WillReturnRows(rows)

	notifications, err := repo.ListNotificationsByUser(context.Background(), uid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, notifications, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_ListNotificationsByUserAndGroups(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	groupIDs := []uuid.UUID{uuid.New(), uuid.New()}

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(uuid.New(), uid, groupIDs[0], "info", "Scoped", "Visible", []byte(`{}`), false, nil, fixedTime())

	mock.ExpectQuery("SELECT .* FROM notifications WHERE user_id = .* AND group_id = ANY").
		WithArgs(uid, groupIDs, 50, 0).
		WillReturnRows(rows)

	notifications, err := repo.ListNotificationsByUserAndGroups(context.Background(), uid, groupIDs, 0, 0)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, groupIDs[0], notifications[0].GroupID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_ListNotificationsByUserBefore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	beforeID := uuid.New()
	before := fixedTime()

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(uuid.New(), uid, fixedUUID(), "info", "Older", "World", []byte(`{}`), false, nil, before.Add(-time.Second))

	mock.ExpectQuery("SELECT .* FROM notifications WHERE user_id = .* AND \\(created_at, id\\) < .* ORDER BY created_at DESC, id DESC LIMIT").
		WithArgs(uid, before, beforeID, 25).
		WillReturnRows(rows)

	notifications, err := repo.ListNotificationsByUserBefore(context.Background(), uid, before, beforeID, 25)
	require.NoError(t, err)
	assert.Len(t, notifications, 1)
	assert.Equal(t, "Older", notifications[0].Title)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_ListNotificationsByUserAndGroupsBefore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	groupIDs := []uuid.UUID{uuid.New()}
	beforeID := uuid.New()
	before := fixedTime()

	rows := pgxmock.NewRows([]string{"id", "user_id", "group_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(uuid.New(), uid, groupIDs[0], "info", "Scoped older", "Visible", []byte(`{}`), false, nil, before.Add(-time.Second))

	mock.ExpectQuery("SELECT .* FROM notifications WHERE user_id = .* AND group_id = ANY.* AND \\(created_at, id\\) <").
		WithArgs(uid, groupIDs, before, beforeID, 25).
		WillReturnRows(rows)

	notifications, err := repo.ListNotificationsByUserAndGroupsBefore(context.Background(), uid, groupIDs, before, beforeID, 25)
	require.NoError(t, err)
	require.Len(t, notifications, 1)
	assert.Equal(t, "Scoped older", notifications[0].Title)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_CountUnreadNotifications(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM notifications WHERE user_id = .* AND is_read = false").
		WithArgs(uid).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(7))

	count, err := repo.CountUnreadNotifications(context.Background(), uid)
	require.NoError(t, err)
	assert.Equal(t, 7, count)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_CountUnreadNotificationsByGroups(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	groupIDs := []uuid.UUID{uuid.New(), uuid.New()}

	mock.ExpectQuery("SELECT COUNT\\(\\*\\) FROM notifications WHERE user_id = .* AND group_id = ANY.* AND is_read = false").
		WithArgs(uid, groupIDs).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(4))

	count, err := repo.CountUnreadNotificationsByGroups(context.Background(), uid, groupIDs)
	require.NoError(t, err)
	assert.Equal(t, 4, count)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_MarkAsRead(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE notifications SET is_read = true").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.MarkAsRead(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_MarkAsRead_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE notifications SET is_read = true").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	err := repo.MarkAsRead(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_MarkAllAsRead(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	mock.ExpectExec("UPDATE notifications SET is_read = true, read_at = NOW\\(\\) WHERE user_id = .* AND is_read = false").
		WithArgs(uid).
		WillReturnResult(pgxmock.NewResult("UPDATE", 3))

	err := repo.MarkAllAsRead(context.Background(), uid)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_MarkAllAsReadByGroups(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	groupIDs := []uuid.UUID{uuid.New()}

	mock.ExpectExec("UPDATE notifications SET is_read = true, read_at = NOW\\(\\) WHERE user_id = .* AND group_id = ANY.* AND is_read = false").
		WithArgs(uid, groupIDs).
		WillReturnResult(pgxmock.NewResult("UPDATE", 2))

	err := repo.MarkAllAsReadByGroups(context.Background(), uid, groupIDs)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_DeleteNotification(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM notifications WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteNotification(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_DeleteNotification_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM notifications WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteNotification(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_GetPreference(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{
		"id", "user_id", "group_id", "chore_due", "chore_due_day_of", "list_item_added",
		"expense_created", "meal_plan_changed", "weekly_digest", "pinwall_reminder", "push_enabled", "email_enabled", "created_at", "updated_at",
	}).AddRow(fixedUUID(), uid, gid, true, true, true, true, true, true, true, true, true, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM notification_preferences WHERE user_id = .* AND group_id = .*").
		WithArgs(uid, gid).
		WillReturnRows(rows)

	pref, err := repo.GetPreference(context.Background(), uid, gid)
	require.NoError(t, err)
	assert.Equal(t, uid, pref.UserID)
	assert.Equal(t, gid, pref.GroupID)
	assert.True(t, pref.PushEnabled)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_GetPreferencesByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{
		"id", "user_id", "group_id", "chore_due", "chore_due_day_of", "list_item_added",
		"expense_created", "meal_plan_changed", "weekly_digest", "pinwall_reminder", "push_enabled", "email_enabled", "created_at", "updated_at",
	}).AddRow(fixedUUID(), uid, fixedUUID(), true, true, true, true, true, true, true, true, true, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM notification_preferences WHERE user_id = .*").
		WithArgs(uid).
		WillReturnRows(rows)

	prefs, err := repo.GetPreferencesByUser(context.Background(), uid)
	require.NoError(t, err)
	assert.Len(t, prefs, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_GetPreferencesByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{
		"id", "user_id", "group_id", "chore_due", "chore_due_day_of", "list_item_added",
		"expense_created", "meal_plan_changed", "weekly_digest", "pinwall_reminder", "push_enabled", "email_enabled", "created_at", "updated_at",
	}).AddRow(fixedUUID(), uid, gid, true, true, true, true, true, true, true, true, true, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM notification_preferences WHERE group_id = .*").
		WithArgs(gid).
		WillReturnRows(rows)

	prefs, err := repo.GetPreferencesByGroup(context.Background(), gid)
	require.NoError(t, err)
	require.Len(t, prefs, 1)
	assert.True(t, prefs[uid].PushEnabled)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_CreateNotificationsBatch(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateNotificationsBatch(context.Background(), []models.Notification{{
		UserID: uid, Type: "pinwall_reminder", Title: "Reminder", Body: "Buy milk",
	}})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_UpsertPreference(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()
	gid := fixedUUID()

	mock.ExpectQuery("INSERT INTO notification_preferences").
		WithArgs(pgxmock.AnyArg(), uid, gid, true, true, true, true, true, true, true, true, true).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(fixedUUID(), fixedTime(), fixedTime()))

	pref := &models.NotificationPreference{UserID: uid, GroupID: gid, ChoreDue: true, ChoreDueDayOf: true, ListItemAdded: true, ExpenseCreated: true, MealPlanChanged: true, WeeklyDigest: true, PinwallReminder: true, PushEnabled: true, EmailEnabled: true}
	err := repo.UpsertPreference(context.Background(), pref)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}
