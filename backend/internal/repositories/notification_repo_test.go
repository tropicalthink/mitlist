package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/models"
)

func TestNotificationRepository_CreateNotification(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)

	n := &models.Notification{
		UserID:  fixedUUID(),
		Type:    "info",
		Title:   "Hello",
		Body:    "World",
		Data:    []byte(`{"key":"value"}`),
		IsRead:  false,
		ReadAt:  nil,
		CreatedAt: fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(fixedUUID(), n.UserID, n.Type, n.Title, n.Body, n.Data, false, nil, fixedTime())

	mock.ExpectQuery("INSERT INTO notifications").
		WithArgs(pgxmock.AnyArg(), n.UserID, n.Type, n.Title, n.Body, n.Data, false, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	err := repo.CreateNotification(context.Background(), n)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, n.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_GetNotificationByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(id, fixedUUID(), "info", "Hello", "World", []byte(`{}`), false, nil, fixedTime())

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

	rows := pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data", "is_read", "read_at", "created_at"}).
		AddRow(fixedUUID(), uid, "info", "Hello", "World", []byte(`{}`), false, nil, fixedTime())

	mock.ExpectQuery("SELECT .* FROM notifications WHERE user_id = .*").
		WithArgs(uid, 50, 0).
		WillReturnRows(rows)

	notifications, err := repo.ListNotificationsByUser(context.Background(), uid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, notifications, 1)
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

func TestNotificationRepository_GetPreferences(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "type", "enabled", "channel"}).
		AddRow(fixedUUID(), uid, "push", true, "web")

	mock.ExpectQuery("SELECT .* FROM notification_preferences WHERE user_id = .*").
		WithArgs(uid).
		WillReturnRows(rows)

	prefs, err := repo.GetPreferences(context.Background(), uid)
	require.NoError(t, err)
	assert.Len(t, prefs, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_UpdatePreferences(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE notification_preferences SET").
		WithArgs("push", true, "web", id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	pref := &models.NotificationPreference{ID: id, Type: "push", Enabled: true, Channel: "web"}
	err := repo.UpdatePreferences(context.Background(), pref)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestNotificationRepository_UpdatePreferences_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewNotificationRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE notification_preferences SET").
		WithArgs("push", true, "web", id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	pref := &models.NotificationPreference{ID: id, Type: "push", Enabled: true, Channel: "web"}
	err := repo.UpdatePreferences(context.Background(), pref)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}
