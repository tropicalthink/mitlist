package repositories

import (
	"context"
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
		INSERT INTO oauth_accounts (id, user_id, provider, provider_user_id, access_token, refresh_token, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.Exec(ctx, query,
		account.ID,
		account.UserID,
		account.Provider,
		account.ProviderUserID,
		account.AccessToken,
		account.RefreshToken,
		account.ExpiresAt,
	)
	if err != nil {
		return err
	}
	return nil
}

// GetOAuthByProviderID retrieves an OAuth account by provider and provider user ID.
func (r *AuthRepository) GetOAuthByProviderID(ctx context.Context, provider, providerUserID string) (*models.OAuthAccount, error) {
	query := `
		SELECT id, user_id, provider, provider_user_id, access_token, refresh_token, expires_at
		FROM oauth_accounts
		WHERE provider = $1 AND provider_user_id = $2
	`
	var account models.OAuthAccount
	err := r.db.QueryRow(ctx, query, provider, providerUserID).Scan(
		&account.ID,
		&account.UserID,
		&account.Provider,
		&account.ProviderUserID,
		&account.AccessToken,
		&account.RefreshToken,
		&account.ExpiresAt,
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
		INSERT INTO password_reset_tokens (id, user_id, token, expires_at, used_at)
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
		SELECT id, user_id, token, expires_at, used_at
		FROM password_reset_tokens
		WHERE token = $1
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
	`
	_, err := r.db.Exec(ctx, query,
		sub.ID,
		sub.UserID,
		sub.Endpoint,
		sub.P256dh,
		sub.Auth,
		sub.CreatedAt,
	)
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
		ON CONFLICT (user_id, token) DO UPDATE SET platform = EXCLUDED.platform
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
