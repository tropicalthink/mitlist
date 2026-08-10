package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// AuthRepository provides data access for auth-related entities.
type AuthRepository struct {
	db DBTX
}

// NewAuthRepository creates a new AuthRepository.
func NewAuthRepository(db DBTX) *AuthRepository {
	return &AuthRepository{db: db}
}

// CreateOAuthAccount inserts a new OAuth account link.
func (r *AuthRepository) CreateOAuthAccount(ctx context.Context, account *models.OAuthAccount) error {
	if account.ID == uuid.Nil {
		account.ID = uuid.New()
	}
	query := `
		INSERT INTO oauth_accounts (id, user_id, provider, provider_user_id)
		VALUES ($1, $2, $3, $4)
	`
	_, err := r.db.Exec(ctx, query,
		account.ID,
		account.UserID,
		account.Provider,
		account.ProviderUserID,
	)
	if err != nil {
		return err
	}
	return nil
}

// GetOAuthByProviderID retrieves an OAuth account by provider and provider user ID.
func (r *AuthRepository) GetOAuthByProviderID(ctx context.Context, provider, providerUserID string) (*models.OAuthAccount, error) {
	query := `
		SELECT id, user_id, provider, provider_user_id
		FROM oauth_accounts
		WHERE provider = $1 AND provider_user_id = $2
	`
	var account models.OAuthAccount
	err := r.db.QueryRow(ctx, query, provider, providerUserID).Scan(
		&account.ID,
		&account.UserID,
		&account.Provider,
		&account.ProviderUserID,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("oauth account not found")
		}
		return nil, err
	}
	return &account, nil
}

// CreatePasswordResetToken inserts a new password reset token.
func (r *AuthRepository) CreatePasswordResetToken(ctx context.Context, token *models.PasswordResetToken) error {
	if token.ID == uuid.Nil {
		token.ID = uuid.New()
	}
	query := `
		INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at, used_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.db.Exec(ctx, query,
		token.ID,
		token.UserID,
		token.Token,
		token.ExpiresAt,
		token.UsedAt,
	)
	if err != nil {
		return err
	}
	return nil
}

// GetPasswordResetToken retrieves a token by its raw token string.
func (r *AuthRepository) GetPasswordResetToken(ctx context.Context, token string) (*models.PasswordResetToken, error) {
	query := `
		SELECT id, user_id, token_hash, expires_at, used_at
		FROM password_reset_tokens
		WHERE token_hash = $1
	`
	var t models.PasswordResetToken
	err := r.db.QueryRow(ctx, query, token).Scan(
		&t.ID,
		&t.UserID,
		&t.Token,
		&t.ExpiresAt,
		&t.UsedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("token not found")
		}
		return nil, err
	}
	return &t, nil
}

// ConsumePasswordReset atomically consumes a live reset credential, changes the
// password, and revokes every existing refresh session for the account.
func (r *AuthRepository) ConsumePasswordReset(ctx context.Context, tokenHash, passwordHash string) (uuid.UUID, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback(ctx)
	var userID uuid.UUID
	err = tx.QueryRow(ctx, `
		UPDATE password_reset_tokens
		SET used_at = NOW()
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()
		RETURNING user_id
	`, tokenHash).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, fmt.Errorf("token not found or already used")
	}
	if err != nil {
		return uuid.Nil, err
	}
	if _, err = tx.Exec(ctx, `UPDATE users SET password_hash = $1, auth_valid_after = NOW(), updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL`, passwordHash, userID); err != nil {
		return uuid.Nil, err
	}
	if _, err = tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID); err != nil {
		return uuid.Nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}

func (r *AuthRepository) UpdatePasswordAndRevokeSessions(ctx context.Context, userID uuid.UUID, passwordHash string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	cmd, err := tx.Exec(ctx, `UPDATE users SET password_hash = $1, auth_valid_after = NOW(), updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL`, passwordHash, userID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}
	if _, err = tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// CreateUnverifiedUser atomically creates an account and its first verification
// credential, so an account can never be stranded without a verification path.
func (r *AuthRepository) CreateUnverifiedUser(ctx context.Context, user *models.User, tokenHash string, expiresAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now().UTC()
	user.CreatedAt, user.UpdatedAt = now, now
	if err = tx.QueryRow(ctx, `
		INSERT INTO users (id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,FALSE,$8,$9,$10)
		RETURNING id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at
	`, user.ID, user.Email, user.PasswordHash, user.FirstName, user.LastName, user.AvatarURL,
		user.IsActive, user.IsGuest, user.CreatedAt, user.UpdatedAt).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.AvatarURL, &user.IsActive, &user.IsVerified, &user.IsGuest, &user.CreatedAt, &user.UpdatedAt,
	); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `INSERT INTO email_verification_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,$3)`, user.ID, tokenHash, expiresAt); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *AuthRepository) CreateEmailVerification(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `DELETE FROM email_verification_tokens WHERE user_id = $1 AND used_at IS NULL`, userID); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `INSERT INTO email_verification_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,$3)`, userID, tokenHash, expiresAt); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *AuthRepository) ConsumeEmailVerification(ctx context.Context, tokenHash string) (uuid.UUID, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback(ctx)
	var userID uuid.UUID
	if err = tx.QueryRow(ctx, `
		UPDATE email_verification_tokens SET used_at = NOW()
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()
		RETURNING user_id
	`, tokenHash).Scan(&userID); err != nil {
		return uuid.Nil, err
	}
	// Verification is also the point at which a converted guest becomes a
	// durable account. Ordinary registrations already have is_guest = FALSE.
	cmd, err := tx.Exec(ctx, `UPDATE users SET is_verified = TRUE, is_guest = FALSE, updated_at = NOW() WHERE id = $1 AND is_active AND deleted_at IS NULL`, userID)
	if err != nil || cmd.RowsAffected() != 1 {
		if err != nil {
			return uuid.Nil, err
		}
		return uuid.Nil, pgx.ErrNoRows
	}
	if _, err = tx.Exec(ctx, `DELETE FROM email_verification_tokens WHERE user_id = $1 AND used_at IS NULL`, userID); err != nil {
		return uuid.Nil, err
	}
	if err = tx.Commit(ctx); err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}

// ReserveLoginAttempt atomically consumes one attempt from a database-backed
// fixed window, so throttling remains effective across API replicas.
func (r *AuthRepository) ReserveLoginAttempt(ctx context.Context, identifier string, limit int, window time.Duration) (bool, error) {
	var allowed bool
	err := r.db.QueryRow(ctx, `
		INSERT INTO auth_login_limits (identifier, attempt_count, window_started_at)
		VALUES ($1, 1, NOW())
		ON CONFLICT (identifier) DO UPDATE SET
			attempt_count = CASE
				WHEN auth_login_limits.window_started_at <= NOW() - make_interval(secs => $2) THEN 1
				ELSE auth_login_limits.attempt_count + 1
			END,
			window_started_at = CASE
				WHEN auth_login_limits.window_started_at <= NOW() - make_interval(secs => $2) THEN NOW()
				ELSE auth_login_limits.window_started_at
			END
		RETURNING attempt_count <= $3
	`, identifier, int(window.Seconds()), limit).Scan(&allowed)
	return allowed, err
}

func (r *AuthRepository) ClearLoginAttempts(ctx context.Context, identifier string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM auth_login_limits WHERE identifier = $1`, identifier)
	return err
}

// ConsumeToken marks a password reset token as used.
func (r *AuthRepository) ConsumeToken(ctx context.Context, id uuid.UUID) error {
	query := `
		UPDATE password_reset_tokens
		SET used_at = $1
		WHERE id = $2 AND used_at IS NULL
	`
	now := time.Now().UTC()
	cmd, err := r.db.Exec(ctx, query, now, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("token not found or already used")
	}
	return nil
}

// CreatePushSubscription inserts a new push subscription.
func (r *AuthRepository) CreatePushSubscription(ctx context.Context, sub *models.PushSubscription) error {
	if sub.ID == uuid.Nil {
		sub.ID = uuid.New()
	}
	now := time.Now().UTC()
	sub.CreatedAt = now
	query := `
		INSERT INTO push_subscriptions (id, user_id, endpoint, p256dh, auth, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (endpoint) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			p256dh = EXCLUDED.p256dh,
			auth = EXCLUDED.auth,
			created_at = EXCLUDED.created_at
		RETURNING id, created_at
	`
	err := r.db.QueryRow(ctx, query,
		sub.ID,
		sub.UserID,
		sub.Endpoint,
		sub.P256dh,
		sub.Auth,
		sub.CreatedAt,
	).Scan(&sub.ID, &sub.CreatedAt)
	if err != nil {
		return err
	}
	return nil
}

// ListPushSubscriptionsByUser returns all push subscriptions for a user.
func (r *AuthRepository) ListPushSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.PushSubscription, error) {
	query := `
		SELECT id, user_id, endpoint, p256dh, auth, created_at
		FROM push_subscriptions
		WHERE user_id = $1
		ORDER BY created_at DESC, id DESC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var subs []models.PushSubscription
	for rows.Next() {
		var sub models.PushSubscription
		if err := rows.Scan(
			&sub.ID,
			&sub.UserID,
			&sub.Endpoint,
			&sub.P256dh,
			&sub.Auth,
			&sub.CreatedAt,
		); err != nil {
			return nil, err
		}
		subs = append(subs, sub)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return subs, nil
}

// ListPushSubscriptionsByUserIDs returns push subscriptions grouped by user_id.
func (r *AuthRepository) ListPushSubscriptionsByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.PushSubscription, error) {
	out := make(map[uuid.UUID][]models.PushSubscription)
	if len(userIDs) == 0 {
		return out, nil
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, endpoint, p256dh, auth, created_at
		FROM push_subscriptions
		WHERE user_id = ANY($1)
		ORDER BY user_id ASC, created_at DESC, id DESC
	`, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var sub models.PushSubscription
		if err := rows.Scan(&sub.ID, &sub.UserID, &sub.Endpoint, &sub.P256dh, &sub.Auth, &sub.CreatedAt); err != nil {
			return nil, err
		}
		out[sub.UserID] = append(out[sub.UserID], sub)
	}
	return out, rows.Err()
}

// DeletePushSubscription removes a push subscription by ID.
func (r *AuthRepository) DeletePushSubscription(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM push_subscriptions WHERE id = $1`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("push subscription not found")
	}
	return nil
}

// ---------------------------------------------------------------------------
// Device tokens (FCM — mobile push)
// ---------------------------------------------------------------------------

// SaveDeviceToken upserts an FCM device token for a user.
func (r *AuthRepository) SaveDeviceToken(ctx context.Context, userID uuid.UUID, platform, token string) (*models.DeviceToken, error) {
	query := `
		INSERT INTO device_tokens (user_id, platform, token)
		VALUES ($1, $2, $3)
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			platform = EXCLUDED.platform,
			created_at = NOW()
		RETURNING id, user_id, platform, token, created_at
	`
	var dt models.DeviceToken
	err := r.db.QueryRow(ctx, query, userID, platform, token).Scan(
		&dt.ID, &dt.UserID, &dt.Platform, &dt.Token, &dt.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &dt, nil
}

// ListDeviceTokensByUser returns all device tokens for a user.
func (r *AuthRepository) ListDeviceTokensByUser(ctx context.Context, userID uuid.UUID) ([]models.DeviceToken, error) {
	query := `
		SELECT id, user_id, platform, token, created_at
		FROM device_tokens
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []models.DeviceToken
	for rows.Next() {
		var dt models.DeviceToken
		if err := rows.Scan(&dt.ID, &dt.UserID, &dt.Platform, &dt.Token, &dt.CreatedAt); err != nil {
			return nil, err
		}
		tokens = append(tokens, dt)
	}
	return tokens, rows.Err()
}

// ListDeviceTokensByUserIDs returns device tokens grouped by user_id.
func (r *AuthRepository) ListDeviceTokensByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.DeviceToken, error) {
	out := make(map[uuid.UUID][]models.DeviceToken)
	if len(userIDs) == 0 {
		return out, nil
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, platform, token, created_at
		FROM device_tokens
		WHERE user_id = ANY($1)
		ORDER BY user_id ASC, created_at DESC
	`, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var dt models.DeviceToken
		if err := rows.Scan(&dt.ID, &dt.UserID, &dt.Platform, &dt.Token, &dt.CreatedAt); err != nil {
			return nil, err
		}
		out[dt.UserID] = append(out[dt.UserID], dt)
	}
	return out, rows.Err()
}

// DeleteDeviceToken removes a device token by ID, scoped to the owning user.
func (r *AuthRepository) DeleteDeviceToken(ctx context.Context, userID, id uuid.UUID) error {
	query := `DELETE FROM device_tokens WHERE id = $1 AND user_id = $2`
	cmd, err := r.db.Exec(ctx, query, id, userID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("device token not found")
	}
	return nil
}

func (r *AuthRepository) CreateOAuthHandoff(ctx context.Context, codeHash string, userID uuid.UUID, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx, `INSERT INTO oauth_handoffs (code_hash, user_id, expires_at) VALUES ($1, $2, $3)`, codeHash, userID, expiresAt)
	return err
}

func (r *AuthRepository) ConsumeOAuthHandoff(ctx context.Context, codeHash string) (uuid.UUID, error) {
	var userID uuid.UUID
	err := r.db.QueryRow(ctx, `
		UPDATE oauth_handoffs SET used_at = NOW()
		WHERE code_hash = $1 AND used_at IS NULL AND expires_at > NOW()
		RETURNING user_id
	`, codeHash).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, fmt.Errorf("oauth handoff not found or already used")
	}
	return userID, err
}
