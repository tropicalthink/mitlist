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

func TestAssistantRepository_CreateSession(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)

	s := &models.ChatSession{
		UserID: fixedUUID(),
		Title:  "Test Session",
	}

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "created_at", "updated_at"}).
		AddRow(fixedUUID(), s.UserID, s.Title, fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO chat_sessions").
		WithArgs(pgxmock.AnyArg(), s.UserID, s.Title, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateSession(context.Background(), s)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NotEqual(t, uuid.Nil, created.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_GetSessionByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Test", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM chat_sessions WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	s, err := repo.GetSessionByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, s.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_GetSessionByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM chat_sessions WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	s, err := repo.GetSessionByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, s)
	assert.ErrorIs(t, err, ErrSessionNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_ListSessionsByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "created_at", "updated_at"}).
		AddRow(fixedUUID(), uid, "Test", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM chat_sessions WHERE user_id = .*").
		WithArgs(uid, 50, 0).
		WillReturnRows(rows)

	sessions, err := repo.ListSessionsByUser(context.Background(), uid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, sessions, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_ListSessionsByUser_Limits(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "created_at", "updated_at"}).
		AddRow(fixedUUID(), uid, "Test", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM chat_sessions WHERE user_id = .*").
		WithArgs(uid, 500, 0).
		WillReturnRows(rows)

	sessions, err := repo.ListSessionsByUser(context.Background(), uid, 1000, 0)
	require.NoError(t, err)
	assert.Len(t, sessions, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_UpdateSession(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Updated", fixedTime(), fixedTime())

	mock.ExpectQuery("UPDATE chat_sessions SET").
		WithArgs("Updated", pgxmock.AnyArg(), id).
		WillReturnRows(rows)

	s := &models.ChatSession{ID: id, Title: "Updated"}
	updated, err := repo.UpdateSession(context.Background(), s)
	require.NoError(t, err)
	assert.Equal(t, "Updated", updated.Title)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_UpdateSession_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE chat_sessions SET").
		WithArgs("Updated", pgxmock.AnyArg(), id).
		WillReturnError(pgx.ErrNoRows)

	s := &models.ChatSession{ID: id, Title: "Updated"}
	updated, err := repo.UpdateSession(context.Background(), s)
	require.Error(t, err)
	assert.Nil(t, updated)
	assert.ErrorIs(t, err, ErrSessionNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_DeleteSession(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chat_sessions WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteSession(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_DeleteSession_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chat_sessions WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteSession(context.Background(), id)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrSessionNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_CreateMessage(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)

	m := &models.ChatMessage{
		SessionID: fixedUUID(),
		Role:      "user",
		Content:   "Hello",
	}

	rows := pgxmock.NewRows([]string{"id", "session_id", "role", "content", "created_at"}).
		AddRow(fixedUUID(), m.SessionID, m.Role, m.Content, fixedTime())

	mock.ExpectQuery("INSERT INTO chat_messages").
		WithArgs(pgxmock.AnyArg(), m.SessionID, m.Role, m.Content, pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateMessage(context.Background(), m)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_ListMessagesBySession(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	sid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "session_id", "role", "content", "created_at"}).
		AddRow(fixedUUID(), sid, "user", "Hello", fixedTime())

	mock.ExpectQuery("SELECT .* FROM chat_messages WHERE session_id = .*").
		WithArgs(sid, 50, 0).
		WillReturnRows(rows)

	messages, err := repo.ListMessagesBySession(context.Background(), sid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, messages, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAssistantRepository_ListMessagesBySession_Limits(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAssistantRepository(mock)
	sid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "session_id", "role", "content", "created_at"}).
		AddRow(fixedUUID(), sid, "user", "Hello", fixedTime())

	mock.ExpectQuery("SELECT .* FROM chat_messages WHERE session_id = .*").
		WithArgs(sid, 500, 0).
		WillReturnRows(rows)

	messages, err := repo.ListMessagesBySession(context.Background(), sid, 1000, 0)
	require.NoError(t, err)
	assert.Len(t, messages, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}
