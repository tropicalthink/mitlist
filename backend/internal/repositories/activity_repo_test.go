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

func TestActivityRepository_LogActivity(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)

	a := &models.ActivityLog{
		GroupID:    fixedUUID(),
		UserID:     fixedUUID(),
		Action:     "create",
		EntityType: "list",
		EntityID:   fixedUUID(),
		Metadata:   []byte(`{"name":"test"}`),
		CreatedAt:  fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "group_id", "user_id", "action", "entity_type", "entity_id", "metadata", "created_at"}).
		AddRow(fixedUUID(), a.GroupID, a.UserID, a.Action, a.EntityType, a.EntityID, a.Metadata, fixedTime())

	mock.ExpectQuery("INSERT INTO activity_logs").
		WithArgs(pgxmock.AnyArg(), a.GroupID, a.UserID, a.Action, a.EntityType, a.EntityID, a.Metadata, pgxmock.AnyArg()).
		WillReturnRows(rows)

	err := repo.LogActivity(context.Background(), a)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, a.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestActivityRepository_GetActivityLogByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "user_id", "action", "entity_type", "entity_id", "metadata", "created_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), "create", "list", fixedUUID(), []byte(`{}`), fixedTime())

	mock.ExpectQuery("SELECT .* FROM activity_logs WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	a, err := repo.GetActivityLogByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, a.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestActivityRepository_GetActivityLogByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM activity_logs WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	a, err := repo.GetActivityLogByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, a)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestActivityRepository_ListActivityLogsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "user_id", "action", "entity_type", "entity_id", "metadata", "created_at"}).
		AddRow(fixedUUID(), gid, fixedUUID(), "create", "list", fixedUUID(), []byte(`{}`), fixedTime())

	mock.ExpectQuery("SELECT .* FROM activity_logs WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	logs, err := repo.ListActivityLogsByGroup(context.Background(), gid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, logs, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestActivityRepository_DeleteActivityLog(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM activity_logs WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteActivityLog(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestActivityRepository_DeleteActivityLog_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM activity_logs WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteActivityLog(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}
