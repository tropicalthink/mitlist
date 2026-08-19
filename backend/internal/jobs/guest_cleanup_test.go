package jobs

import (
	"testing"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/require"
)

func newGuestCleanupDB(t *testing.T) pgxmock.PgxPoolIface {
	t.Helper()
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { pool.Close() })
	return pool
}

func TestGuestCleanup_LocksInactiveGuestsAndRetainsData(t *testing.T) {
	pool := newGuestCleanupDB(t)
	guestID := uuid.New()

	pool.ExpectBegin()
	pool.ExpectQuery("SELECT id FROM users").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(guestID))
	pool.ExpectExec(`UPDATE users SET is_active = FALSE, guest_locked_at = NOW\(\), auth_valid_after = NOW\(\)`).
		WithArgs([]uuid.UUID{guestID}).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	pool.ExpectQuery("SELECT id FROM users").
		WillReturnRows(pgxmock.NewRows([]string{"id"}))
	pool.ExpectCommit()

	NewGuestCleanup(pool, logger.New("test")).Run()
	require.NoError(t, pool.ExpectationsWereMet())
}

func TestGuestCleanup_RetiresOnlyGuestsPastLockedGrace(t *testing.T) {
	pool := newGuestCleanupDB(t)
	guestID := uuid.New()

	pool.ExpectBegin()
	pool.ExpectQuery("SELECT id FROM users").
		WillReturnRows(pgxmock.NewRows([]string{"id"}))
	pool.ExpectQuery("SELECT id FROM users").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(guestID))
	pool.ExpectExec(`UPDATE users SET email = 'deleted\+' `).
		WithArgs([]uuid.UUID{guestID}).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	for _, table := range []string{
		"auth_sessions", "password_reset_tokens", "email_verification_tokens",
		"push_subscriptions", "device_tokens", "oauth_accounts",
	} {
		pool.ExpectExec(`DELETE FROM ` + table + ` WHERE user_id = ANY\(\$1\)`).
			WithArgs([]uuid.UUID{guestID}).
			WillReturnResult(pgxmock.NewResult("DELETE", 1))
	}
	pool.ExpectCommit()

	NewGuestCleanup(pool, logger.New("test")).Run()
	require.NoError(t, pool.ExpectationsWereMet())
}
