package repositories

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestAuthRepository_CreateOAuthAccount(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	account := &models.OAuthAccount{
		UserID:         fixedUUID(),
		Provider:       "google",
		ProviderUserID: "google123",
	}

	mock.ExpectExec("INSERT INTO oauth_accounts").
		WithArgs(pgxmock.AnyArg(), account.UserID, account.Provider, account.ProviderUserID).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateOAuthAccount(context.Background(), account)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_GetOAuthByProviderID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	id := fixedUUID()
	rows := pgxmock.NewRows([]string{"id", "user_id", "provider", "provider_user_id"}).
		AddRow(id, fixedUUID(), "google", "google123")

	mock.ExpectQuery("SELECT .* FROM oauth_accounts WHERE provider = .* AND provider_user_id = .*").
		WithArgs("google", "google123").
		WillReturnRows(rows)

	account, err := repo.GetOAuthByProviderID(context.Background(), "google", "google123")
	require.NoError(t, err)
	assert.Equal(t, "google", account.Provider)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_GetOAuthByProviderID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	mock.ExpectQuery("SELECT .* FROM oauth_accounts WHERE provider = .* AND provider_user_id = .*").
		WithArgs("google", "missing").
		WillReturnError(pgx.ErrNoRows)

	account, err := repo.GetOAuthByProviderID(context.Background(), "google", "missing")
	require.Error(t, err)
	assert.Nil(t, account)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_CreatePasswordResetToken(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	token := &models.PasswordResetToken{
		UserID:    fixedUUID(),
		Token:     "abc123",
		ExpiresAt: fixedTime(),
	}

	mock.ExpectExec("INSERT INTO password_reset_tokens").
		WithArgs(pgxmock.AnyArg(), token.UserID, token.Token, token.ExpiresAt, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreatePasswordResetToken(context.Background(), token)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_GetPasswordResetToken(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	id := fixedUUID()
	rows := pgxmock.NewRows([]string{"id", "user_id", "token_hash", "expires_at", "used_at"}).
		AddRow(id, fixedUUID(), "abc123", fixedTime(), nil)

	mock.ExpectQuery("SELECT .* FROM password_reset_tokens WHERE token_hash = .*").
		WithArgs("abc123").
		WillReturnRows(rows)

	token, err := repo.GetPasswordResetToken(context.Background(), "abc123")
	require.NoError(t, err)
	assert.Equal(t, "abc123", token.Token)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_GetPasswordResetToken_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	mock.ExpectQuery("SELECT .* FROM password_reset_tokens WHERE token_hash = .*").
		WithArgs("missing").
		WillReturnError(pgx.ErrNoRows)

	token, err := repo.GetPasswordResetToken(context.Background(), "missing")
	require.Error(t, err)
	assert.Nil(t, token)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_ConsumeToken(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE password_reset_tokens SET used_at = .* WHERE id = .* AND used_at IS NULL").
		WithArgs(pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.ConsumeToken(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_ConsumeToken_AlreadyUsed(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE password_reset_tokens SET used_at = .* WHERE id = .* AND used_at IS NULL").
		WithArgs(pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	err := repo.ConsumeToken(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "already used")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_CreatePushSubscription(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)

	sub := &models.PushSubscription{
		UserID:   fixedUUID(),
		Endpoint: "https://push.example.com",
		P256dh:   "p256dh",
		Auth:     "auth",
	}

	mock.ExpectExec("INSERT INTO push_subscriptions").
		WithArgs(pgxmock.AnyArg(), sub.UserID, sub.Endpoint, sub.P256dh, sub.Auth, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreatePushSubscription(context.Background(), sub)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_ListPushSubscriptionsByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)
	userID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "endpoint", "p256dh", "auth", "created_at"}).
		AddRow(fixedUUID(), userID, "https://push.example.com", "p256dh", "auth", fixedTime())

	mock.ExpectQuery("SELECT .* FROM push_subscriptions WHERE user_id = .*").
		WithArgs(userID).
		WillReturnRows(rows)

	subs, err := repo.ListPushSubscriptionsByUser(context.Background(), userID)
	require.NoError(t, err)
	assert.Len(t, subs, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_DeletePushSubscription(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM push_subscriptions WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeletePushSubscription(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestAuthRepository_DeletePushSubscription_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewAuthRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM push_subscriptions WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeletePushSubscription(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func strPtr(s string) *string {
	return &s
}
