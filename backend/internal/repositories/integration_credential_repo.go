package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ErrIntegrationCredentialNotFound is returned for an unknown or revoked
// integration credential. Callers should treat both cases identically.
var ErrIntegrationCredentialNotFound = errors.New("integration credential not found")

// IntegrationCredentialRepository stores integration credential metadata. Raw
// bearer tokens are never passed to this repository; tokenHash is a SHA-256
// digest produced by the service.
type IntegrationCredentialRepository struct{ db DBTX }

func NewIntegrationCredentialRepository(db DBTX) *IntegrationCredentialRepository {
	return &IntegrationCredentialRepository{db: db}
}

// NewIntegrationCredentialRepo is retained as a concise constructor alias for
// callers that use the other repository naming convention.
func NewIntegrationCredentialRepo(db DBTX) *IntegrationCredentialRepository {
	return NewIntegrationCredentialRepository(db)
}

func (r *IntegrationCredentialRepository) Create(ctx context.Context, credential *models.IntegrationCredential, tokenHash string) error {
	if credential.ID == uuid.Nil {
		credential.ID = uuid.New()
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO integration_credentials
		  (id, user_id, name, token_prefix, token_hash, group_ids, scopes, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, NOW()))
	`, credential.ID, credential.UserID, credential.Name, credential.TokenPrefix,
		tokenHash, credential.GroupIDs, credential.Scopes, nullableTime(credential.CreatedAt))
	return err
}

func (r *IntegrationCredentialRepository) CreateCredential(ctx context.Context, credential *models.IntegrationCredential, tokenHash string) error {
	return r.Create(ctx, credential, tokenHash)
}

func nullableTime(t interface{ IsZero() bool }) interface{} { // kept private to avoid pgtype imports
	if t.IsZero() {
		return nil
	}
	return t
}

func (r *IntegrationCredentialRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]models.IntegrationCredential, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, name, token_prefix, group_ids, scopes, created_at,
		       last_used_at, revoked_at, COALESCE(last_used_ip, ''), COALESCE(last_user_agent, '')
		FROM integration_credentials WHERE user_id = $1 ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	credentials := make([]models.IntegrationCredential, 0)
	for rows.Next() {
		var c models.IntegrationCredential
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.TokenPrefix, &c.GroupIDs, &c.Scopes,
			&c.CreatedAt, &c.LastUsedAt, &c.RevokedAt, &c.LastUsedIP, &c.LastUserAgent); err != nil {
			return nil, err
		}
		credentials = append(credentials, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return credentials, nil
}

func (r *IntegrationCredentialRepository) ListCredentialsByUser(ctx context.Context, userID uuid.UUID) ([]models.IntegrationCredential, error) {
	return r.ListByUser(ctx, userID)
}

// GetActiveByHash returns only live credentials, making revoked tokens
// indistinguishable from random invalid tokens at the authentication boundary.
func (r *IntegrationCredentialRepository) GetActiveByHash(ctx context.Context, tokenHash string) (*models.IntegrationCredential, error) {
	var c models.IntegrationCredential
	err := r.db.QueryRow(ctx, `
		SELECT id, user_id, name, token_prefix, group_ids, scopes, created_at,
		       last_used_at, revoked_at, COALESCE(last_used_ip, ''), COALESCE(last_user_agent, '')
		FROM integration_credentials
		WHERE token_hash = $1 AND revoked_at IS NULL
	`, tokenHash).Scan(&c.ID, &c.UserID, &c.Name, &c.TokenPrefix, &c.GroupIDs, &c.Scopes,
		&c.CreatedAt, &c.LastUsedAt, &c.RevokedAt, &c.LastUsedIP, &c.LastUserAgent)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrIntegrationCredentialNotFound
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *IntegrationCredentialRepository) GetCredentialByTokenHash(ctx context.Context, tokenHash string) (*models.IntegrationCredential, error) {
	return r.GetActiveByHash(ctx, tokenHash)
}

func (r *IntegrationCredentialRepository) TouchLastUsed(ctx context.Context, id uuid.UUID, ip, userAgent string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE integration_credentials
		SET last_used_at = NOW(), last_used_ip = $2, last_user_agent = $3
		WHERE id = $1 AND revoked_at IS NULL
		  AND (
			last_used_at IS NULL
			OR last_used_at < NOW() - INTERVAL '5 minutes'
			OR last_used_ip IS DISTINCT FROM $2
			OR last_user_agent IS DISTINCT FROM $3
		  )
	`, id, ip, userAgent)
	return err
}

func (r *IntegrationCredentialRepository) UpdateLastUsed(ctx context.Context, id uuid.UUID, ip, userAgent string) error {
	return r.TouchLastUsed(ctx, id, ip, userAgent)
}

func (r *IntegrationCredentialRepository) Revoke(ctx context.Context, userID, id uuid.UUID) error {
	result, err := r.db.Exec(ctx, `
		UPDATE integration_credentials SET revoked_at = COALESCE(revoked_at, NOW())
		WHERE id = $1 AND user_id = $2
	`, id, userID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrIntegrationCredentialNotFound
	}
	return nil
}

func (r *IntegrationCredentialRepository) RevokeCredential(ctx context.Context, userID, id uuid.UUID) error {
	return r.Revoke(ctx, userID, id)
}

func (r *IntegrationCredentialRepository) GetByID(ctx context.Context, userID, id uuid.UUID) (*models.IntegrationCredential, error) {
	var c models.IntegrationCredential
	err := r.db.QueryRow(ctx, `
		SELECT id, user_id, name, token_prefix, group_ids, scopes, created_at,
		       last_used_at, revoked_at, COALESCE(last_used_ip, ''), COALESCE(last_user_agent, '')
		FROM integration_credentials WHERE id = $1 AND user_id = $2
	`, id, userID).Scan(&c.ID, &c.UserID, &c.Name, &c.TokenPrefix, &c.GroupIDs, &c.Scopes,
		&c.CreatedAt, &c.LastUsedAt, &c.RevokedAt, &c.LastUsedIP, &c.LastUserAgent)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrIntegrationCredentialNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get integration credential: %w", err)
	}
	return &c, nil
}
