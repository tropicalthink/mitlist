package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestUserRepository_Create(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	user := &models.User{
		Email:        "test@example.com",
		PasswordHash: "hash",
		FirstName:    "Test",
		LastName:     "User",
		IsActive:     true,
		IsVerified:   true,
	}

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), user.Email, user.PasswordHash, user.FirstName, user.LastName, nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(
			pgxmock.AnyArg(), user.Email, user.PasswordHash, user.FirstName, user.LastName,
			pgxmock.AnyArg(), user.IsActive, user.IsVerified, user.IsGuest,
			pgxmock.AnyArg(), pgxmock.AnyArg(),
		).
		WillReturnRows(rows)

	err := repo.Create(context.Background(), user)
	require.NoError(t, err)
	assertUUID(t, user.ID)
	assert.NotZero(t, user.CreatedAt)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_Create_GeneratesUUID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	user := &models.User{
		Email:     "test@example.com",
		FirstName: "Test",
		LastName:  "User",
	}

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), user.Email, "", user.FirstName, user.LastName, nil,
		false, false, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(
			pgxmock.AnyArg(), user.Email, "", user.FirstName, user.LastName,
			pgxmock.AnyArg(), false, false, false,
			pgxmock.AnyArg(), pgxmock.AnyArg(),
		).
		WillReturnRows(rows)

	err := repo.Create(context.Background(), user)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, user.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		id, "test@example.com", "hash", "Test", "User", nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("SELECT .* FROM users WHERE id = .* AND deleted_at IS NULL").
		WithArgs(id).
		WillReturnRows(rows)

	user, err := repo.GetByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, user.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM users WHERE id = .* AND deleted_at IS NULL").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	user, err := repo.GetByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, user)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByEmail(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), "test@example.com", "hash", "Test", "User", nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("SELECT .* FROM users WHERE email = .* AND deleted_at IS NULL").
		WithArgs("test@example.com").
		WillReturnRows(rows)

	user, err := repo.GetByEmail(context.Background(), "test@example.com")
	require.NoError(t, err)
	assert.Equal(t, "test@example.com", user.Email)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByEmail_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	mock.ExpectQuery("SELECT .* FROM users WHERE email = .* AND deleted_at IS NULL").
		WithArgs("missing@example.com").
		WillReturnError(pgx.ErrNoRows)

	user, err := repo.GetByEmail(context.Background(), "missing@example.com")
	require.Error(t, err)
	assert.Nil(t, user)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByOAuth(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), "test@example.com", "hash", "Test", "User", nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("SELECT .* FROM users u JOIN oauth_accounts oa").
		WithArgs("google", "google123").
		WillReturnRows(rows)

	user, err := repo.GetByOAuth(context.Background(), "google", "google123")
	require.NoError(t, err)
	assert.NotNil(t, user)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_GetByOAuth_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	mock.ExpectQuery("SELECT .* FROM users u JOIN oauth_accounts oa").
		WithArgs("google", "missing").
		WillReturnError(pgx.ErrNoRows)

	user, err := repo.GetByOAuth(context.Background(), "google", "missing")
	require.Error(t, err)
	assert.Nil(t, user)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_Update(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id FROM users WHERE id = .* FOR UPDATE").
		WithArgs(id).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(id))
	mock.ExpectExec("UPDATE users SET").
		WithArgs(
			"new@example.com", "newhash", "New", "Name", pgxmock.AnyArg(),
			true, true, false, pgxmock.AnyArg(), id,
		).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	user := &models.User{
		ID:           id,
		Email:        "new@example.com",
		PasswordHash: "newhash",
		FirstName:    "New",
		LastName:     "Name",
		IsActive:     true,
		IsVerified:   true,
	}

	err := repo.Update(context.Background(), user)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_Update_LockNotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id FROM users WHERE id = .* FOR UPDATE").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)
	mock.ExpectRollback()

	user := &models.User{ID: id, Email: "new@example.com"}
	err := repo.Update(context.Background(), user)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_Update_RowsAffectedZero(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT id FROM users WHERE id = .* FOR UPDATE").
		WithArgs(id).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(id))
	mock.ExpectExec("UPDATE users SET").
		WithArgs(
			"new@example.com", "newhash", "New", "Name", pgxmock.AnyArg(),
			true, true, false, pgxmock.AnyArg(), id,
		).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	mock.ExpectRollback()

	user := &models.User{
		ID:           id,
		Email:        "new@example.com",
		PasswordHash: "newhash",
		FirstName:    "New",
		LastName:     "Name",
		IsActive:     true,
		IsVerified:   true,
	}

	err := repo.Update(context.Background(), user)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_SoftDelete(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE users SET deleted_at = .* WHERE id = .* AND deleted_at IS NULL").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.SoftDelete(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_SoftDelete_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE users SET deleted_at = .* WHERE id = .* AND deleted_at IS NULL").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	err := repo.SoftDelete(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_List(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), "a@example.com", "hash", "A", "B", nil,
		true, true, false, fixedTime(), fixedTime(),
	).AddRow(
		fixedUUID(), "b@example.com", "hash", "C", "D", nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("SELECT .* FROM users WHERE deleted_at IS NULL").
		WithArgs(50, 0).
		WillReturnRows(rows)

	users, err := repo.List(context.Background(), 0, 0)
	require.NoError(t, err)
	assert.Len(t, users, 2)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUserRepository_List_MaxLimit(t *testing.T) {
	mock := newMockDB(t)
	repo := NewUserRepository(mock)

	rows := pgxmock.NewRows([]string{
		"id", "email", "password_hash", "first_name", "last_name", "avatar_url",
		"is_active", "is_verified", "is_guest", "created_at", "updated_at",
	}).AddRow(
		fixedUUID(), "a@example.com", "hash", "A", "B", nil,
		true, true, false, fixedTime(), fixedTime(),
	)

	mock.ExpectQuery("SELECT .* FROM users WHERE deleted_at IS NULL").
		WithArgs(500, 0).
		WillReturnRows(rows)

	users, err := repo.List(context.Background(), 1000, 0)
	require.NoError(t, err)
	assert.Len(t, users, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}
