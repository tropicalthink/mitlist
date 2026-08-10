package jobs

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// GuestCleanup retires abandoned guest accounts in bulk. The user row is kept
// as an anonymized tombstone so shared-household foreign keys remain valid;
// credentials, sessions, subscriptions and recovery tokens are removed.
type GuestCleanup struct {
	db  repositories.DBTX
	log *logger.Logger
}

func NewGuestCleanup(db repositories.DBTX, log *logger.Logger) *GuestCleanup {
	return &GuestCleanup{db: db, log: log}
}

func (j *GuestCleanup) Run() {
	if j.db == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	tx, err := j.db.Begin(ctx)
	if err != nil {
		j.log.WithError(err).Error().Msg("begin guest cleanup failed")
		return
	}
	defer tx.Rollback(ctx)
	rows, err := tx.Query(ctx, `
		SELECT id FROM users
		WHERE is_guest AND deleted_at IS NULL AND created_at < NOW() - INTERVAL '30 days'
		FOR UPDATE
	`)
	if err != nil {
		j.log.WithError(err).Error().Msg("list expired guests failed")
		return
	}
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			j.log.WithError(err).Error().Msg("scan expired guest failed")
			return
		}
		ids = append(ids, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		j.log.WithError(err).Error().Msg("read expired guests failed")
		return
	}
	if len(ids) == 0 {
		_ = tx.Rollback(ctx)
		return
	}
	_, err = tx.Exec(ctx, `
		UPDATE users
		SET email = 'deleted+' || id::text || '@deleted.invalid', password_hash = '',
		    first_name = '', last_name = '', avatar_url = NULL, is_active = FALSE,
		    is_verified = FALSE, is_guest = FALSE, auth_valid_after = NOW(),
		    deleted_at = NOW(), updated_at = NOW()
		WHERE id = ANY($1)
	`, ids)
	if err != nil {
		j.log.WithError(err).Error().Msg("retire expired guests failed")
		return
	}
	for _, table := range []string{
		"auth_sessions", "password_reset_tokens", "email_verification_tokens",
		"push_subscriptions", "device_tokens", "oauth_accounts",
	} {
		if _, err := tx.Exec(ctx, "DELETE FROM "+table+" WHERE user_id = ANY($1)", ids); err != nil {
			j.log.WithField("table", table).WithError(err).Error().Msg("clean expired guest records failed")
			return
		}
	}
	if err := tx.Commit(ctx); err != nil {
		j.log.WithError(err).Error().Msg("commit guest cleanup failed")
		return
	}
	j.log.Info().Int("guests", len(ids)).Msg("expired guests retired")
}
