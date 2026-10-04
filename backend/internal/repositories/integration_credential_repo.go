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

// Credential kinds. Integration credentials are created by a person for an
// external system and listed in their settings; widget credentials are issued
// automatically to the app's home screen widgets, one per device.
const (
	CredentialKindIntegration = "integration"
	CredentialKindWidget      = "widget"
)

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

const integrationCredentialColumns = `id, user_id, name, kind, token_prefix, group_ids, scopes, created_at,
       last_used_at, revoked_at, expires_at, COALESCE(device_id, ''),
       COALESCE(last_used_ip, ''), COALESCE(last_user_agent, '')`

func scanIntegrationCredential(row pgx.Row, c *models.IntegrationCredential) error {
	return row.Scan(&c.ID, &c.UserID, &c.Name, &c.Kind, &c.TokenPrefix, &c.GroupIDs, &c.Scopes,
		&c.CreatedAt, &c.LastUsedAt, &c.RevokedAt, &c.ExpiresAt, &c.DeviceID,
		&c.LastUsedIP, &c.LastUserAgent)
}

func (r *IntegrationCredentialRepository) Create(ctx context.Context, credential *models.IntegrationCredential, tokenHash string) error {
	return insertIntegrationCredential(ctx, r.db, credential, tokenHash)
}

type credentialQuerier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// insertIntegrationCredential stores credential and reads back created_at.
// A zero CreatedAt lets the database stamp it, which keeps a widget
// credential's creation on the same clock as users.auth_valid_after.
func insertIntegrationCredential(ctx context.Context, db credentialQuerier, credential *models.IntegrationCredential, tokenHash string) error {
	if credential.ID == uuid.Nil {
		credential.ID = uuid.New()
	}
	if credential.Kind == "" {
		credential.Kind = CredentialKindIntegration
	}
	return db.QueryRow(ctx, `
		INSERT INTO integration_credentials
		  (id, user_id, name, kind, token_prefix, token_hash, group_ids, scopes,
		   device_id, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULLIF($9, ''), $10, COALESCE($11, NOW()))
		RETURNING created_at
	`, credential.ID, credential.UserID, credential.Name, credential.Kind, credential.TokenPrefix,
		tokenHash, credential.GroupIDs, credential.Scopes, credential.DeviceID, credential.ExpiresAt,
		nullableTime(credential.CreatedAt)).Scan(&credential.CreatedAt)
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

// ListByUser returns the credentials a person manages in settings. Widget
// credentials are managed by the app itself and are not listed.
func (r *IntegrationCredentialRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]models.IntegrationCredential, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+integrationCredentialColumns+`
		FROM integration_credentials
		WHERE user_id = $1 AND kind = 'integration'
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	credentials := make([]models.IntegrationCredential, 0)
	for rows.Next() {
		var c models.IntegrationCredential
		if err := scanIntegrationCredential(rows, &c); err != nil {
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
// A widget credential is also dead once it has expired or once the owner's
// auth cutoff (users.auth_valid_after) has moved past its creation, which
// every "sign out everywhere" path advances.
func (r *IntegrationCredentialRepository) GetActiveByHash(ctx context.Context, tokenHash string) (*models.IntegrationCredential, error) {
	var c models.IntegrationCredential
	err := scanIntegrationCredential(r.db.QueryRow(ctx, `
		SELECT `+integrationCredentialColumns+`
		FROM integration_credentials ic
		WHERE ic.token_hash = $1 AND ic.revoked_at IS NULL
		  AND (ic.expires_at IS NULL OR ic.expires_at > NOW())
		  AND (ic.kind <> 'widget' OR ic.created_at > (
		        SELECT u.auth_valid_after FROM users u WHERE u.id = ic.user_id))
	`, tokenHash), &c)
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

// ReplaceWidgetCredential revokes the device's live widget credential, if
// any, and stores credential in its place. Both happen in one transaction so
// a device never holds two live widget credentials and never loses its only
// one to a failed insert.
func (r *IntegrationCredentialRepository) ReplaceWidgetCredential(ctx context.Context, credential *models.IntegrationCredential, tokenHash string) error {
	if credential.Kind != CredentialKindWidget || credential.DeviceID == "" || credential.ExpiresAt == nil {
		return fmt.Errorf("replace widget credential: kind, device id and expiry are required")
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	// The device's WidgetKit push token belongs to the install, not to one
	// credential, so it moves to the new row.
	var pushToken *string
	err = tx.QueryRow(ctx, `
		UPDATE integration_credentials SET revoked_at = NOW()
		WHERE user_id = $1 AND device_id = $2 AND kind = 'widget' AND revoked_at IS NULL
		RETURNING push_token
	`, credential.UserID, credential.DeviceID).Scan(&pushToken)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("revoke previous widget credential: %w", err)
	}
	if err := insertIntegrationCredential(ctx, tx, credential, tokenHash); err != nil {
		return fmt.Errorf("store widget credential: %w", err)
	}
	if pushToken != nil {
		if _, err := tx.Exec(ctx, `UPDATE integration_credentials SET push_token = $2 WHERE id = $1`,
			credential.ID, *pushToken); err != nil {
			return fmt.Errorf("carry widget push token: %w", err)
		}
	}
	return tx.Commit(ctx)
}

// RevokeWidgetCredential revokes the device's live widget credential. It is
// idempotent: a device without one is not an error.
func (r *IntegrationCredentialRepository) RevokeWidgetCredential(ctx context.Context, userID uuid.UUID, deviceID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE integration_credentials SET revoked_at = NOW()
		WHERE user_id = $1 AND device_id = $2 AND kind = 'widget' AND revoked_at IS NULL
	`, userID, deviceID)
	return err
}

func (r *IntegrationCredentialRepository) GetByID(ctx context.Context, userID, id uuid.UUID) (*models.IntegrationCredential, error) {
	var c models.IntegrationCredential
	err := scanIntegrationCredential(r.db.QueryRow(ctx, `
		SELECT `+integrationCredentialColumns+`
		FROM integration_credentials WHERE id = $1 AND user_id = $2
	`, id, userID), &c)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrIntegrationCredentialNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get integration credential: %w", err)
	}
	return &c, nil
}
