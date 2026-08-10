package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// UserRepository provides data access for users.
type UserRepository struct {
	db DBTX
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(db DBTX) *UserRepository {
	return &UserRepository{db: db}
}

// Create inserts a new user and populates generated fields.
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now().UTC()
	user.CreatedAt = now
	user.UpdatedAt = now

	query := `
		INSERT INTO users (id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.ID,
		user.Email,
		user.PasswordHash,
		user.FirstName,
		user.LastName,
		user.AvatarURL,
		user.IsActive,
		user.IsVerified,
		user.IsGuest,
		user.CreatedAt,
		user.UpdatedAt,
	).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.AvatarURL,
		&user.IsActive,
		&user.IsVerified,
		&user.IsGuest,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
}

// GetByID retrieves a user by ID, excluding soft-deleted records.
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`
	var user models.User
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.AvatarURL,
		&user.IsActive,
		&user.IsVerified,
		&user.IsGuest,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// GetByEmail retrieves a user by email, excluding soft-deleted records.
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at
		FROM users
		WHERE email = $1 AND deleted_at IS NULL
	`
	var user models.User
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.AvatarURL,
		&user.IsActive,
		&user.IsVerified,
		&user.IsGuest,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// GetByOAuth retrieves a user linked to the given OAuth provider and provider user ID.
func (r *UserRepository) GetByOAuth(ctx context.Context, provider, providerUserID string) (*models.User, error) {
	query := `
		SELECT u.id, u.email, u.password_hash, u.first_name, u.last_name, u.avatar_url, u.is_active, u.is_verified, u.is_guest, u.created_at, u.updated_at
		FROM users u
		JOIN oauth_accounts oa ON oa.user_id = u.id
		WHERE oa.provider = $1 AND oa.provider_user_id = $2 AND u.deleted_at IS NULL
	`
	var user models.User
	err := r.db.QueryRow(ctx, query, provider, providerUserID).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FirstName,
		&user.LastName,
		&user.AvatarURL,
		&user.IsActive,
		&user.IsVerified,
		&user.IsGuest,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// Update updates a user, using SELECT FOR UPDATE to prevent races.
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	lockQuery := `SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`
	var id uuid.UUID
	if err := tx.QueryRow(ctx, lockQuery, user.ID).Scan(&id); err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("user not found")
		}
		return err
	}

	user.UpdatedAt = time.Now().UTC()
	updateQuery := `
		UPDATE users
		SET email = $1, password_hash = $2, first_name = $3, last_name = $4, avatar_url = $5,
		    is_active = $6, is_verified = $7, is_guest = $8, updated_at = $9
		WHERE id = $10 AND deleted_at IS NULL
	`
	cmd, err := tx.Exec(ctx, updateQuery,
		user.Email,
		user.PasswordHash,
		user.FirstName,
		user.LastName,
		user.AvatarURL,
		user.IsActive,
		user.IsVerified,
		user.IsGuest,
		user.UpdatedAt,
		user.ID,
	)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}

	return tx.Commit(ctx)
}

// SoftDelete removes account credentials and personal profile data while
// retaining the user row as an anonymized tombstone for shared-household
// foreign keys. It also advances auth_valid_after so already-issued access
// tokens stop working immediately, and revokes refresh sessions and recovery
// credentials in the same transaction.
func (r *UserRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	now := time.Now().UTC()
	cmd, err := tx.Exec(ctx, `
		UPDATE users
		SET email = 'deleted+' || id::text || '@deleted.invalid',
		    password_hash = '', first_name = '', last_name = '', avatar_url = NULL,
		    is_active = FALSE, is_verified = FALSE, is_guest = FALSE,
		    auth_valid_after = $1, deleted_at = $1, updated_at = $1
		WHERE id = $2 AND deleted_at IS NULL
	`, now, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}
	for _, query := range []string{
		`DELETE FROM auth_sessions WHERE user_id = $1`,
		`DELETE FROM password_reset_tokens WHERE user_id = $1`,
		`DELETE FROM email_verification_tokens WHERE user_id = $1`,
		`DELETE FROM push_subscriptions WHERE user_id = $1`,
		`DELETE FROM device_tokens WHERE user_id = $1`,
		`DELETE FROM oauth_accounts WHERE user_id = $1`,
	} {
		if _, err := tx.Exec(ctx, query, id); err != nil {
			return err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	return nil
}

// List returns a paginated list of users, excluding soft-deleted records.
func (r *UserRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, email, password_hash, first_name, last_name, avatar_url, is_active, is_verified, is_guest, created_at, updated_at
		FROM users
		WHERE deleted_at IS NULL
		ORDER BY created_at DESC, id DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		if err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.FirstName,
			&user.LastName,
			&user.AvatarURL,
			&user.IsActive,
			&user.IsVerified,
			&user.IsGuest,
			&user.CreatedAt,
			&user.UpdatedAt,
		); err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return users, nil
}
