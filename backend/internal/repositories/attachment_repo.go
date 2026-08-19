package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

var (
	ErrStorageQuotaExceeded = errors.New("storage quota exceeded")
	ErrAttachmentNotPending = errors.New("attachment is not pending")
)

type AttachmentRepository struct {
	db *pgxpool.Pool
}

func NewAttachmentRepository(db *pgxpool.Pool) *AttachmentRepository {
	return &AttachmentRepository{db: db}
}

func (r *AttachmentRepository) GetStorageUsage(ctx context.Context, groupID uuid.UUID) (*models.AttachmentStorageUsage, error) {
	const q = `
		SELECT storage_used_bytes, storage_reserved_bytes
		FROM groups
		WHERE id = $1
	`
	var usage models.AttachmentStorageUsage
	if err := r.db.QueryRow(ctx, q, groupID).Scan(&usage.UsedBytes, &usage.ReservedBytes); err != nil {
		if err == pgx.ErrNoRows {
			return nil, err
		}
		return nil, fmt.Errorf("get attachment storage usage: %w", err)
	}
	return &usage, nil
}

// Reserve atomically accounts for the declared upload size and creates its
// pending attachment. This prevents concurrent upload intents from exceeding
// the household limit.
func (r *AttachmentRepository) Reserve(ctx context.Context, a *models.Attachment, limitBytes int64) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin attachment reservation: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// $3 is cast explicitly: compared bare against the literal 0, Postgres
	// infers the parameter as int4, and any limit above ~2.1 GB then fails to
	// encode — so every upload intent 500s on a household quota of 3 GB or more.
	const reserve = `
		UPDATE groups
		SET storage_reserved_bytes = storage_reserved_bytes + $1
		WHERE id = $2
		  AND ($3::bigint <= 0 OR storage_used_bytes + storage_reserved_bytes + $1 <= $3::bigint)
	`
	ct, err := tx.Exec(ctx, reserve, a.ByteSize, a.GroupID, limitBytes)
	if err != nil {
		return fmt.Errorf("reserve group storage: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return ErrStorageQuotaExceeded
	}

	const insert = `
		INSERT INTO attachments
			(group_id, user_id, purpose, object_key, content_type, byte_size, status, reservation_expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at
	`
	if err := tx.QueryRow(ctx, insert, a.GroupID, a.UserID, a.Purpose, a.ObjectKey, a.ContentType,
		a.ByteSize, a.Status, a.ReservationExpiresAt).Scan(&a.ID, &a.CreatedAt); err != nil {
		return fmt.Errorf("create reserved attachment: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit attachment reservation: %w", err)
	}
	return nil
}

// Create inserts an already-materialized attachment while keeping accounting
// consistent. Runtime upload flows should use Reserve and FinalizeReservation.
func (r *AttachmentRepository) Create(ctx context.Context, a *models.Attachment) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin attachment create: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	column := ""
	switch a.Status {
	case models.AttachmentStatusReady:
		column = "storage_used_bytes"
	case models.AttachmentStatusPending:
		column = "storage_reserved_bytes"
	}
	if column != "" {
		if _, err := tx.Exec(ctx, `UPDATE groups SET `+column+` = `+column+` + $1 WHERE id = $2`, a.ByteSize, a.GroupID); err != nil {
			return fmt.Errorf("account created attachment: %w", err)
		}
	}
	const q = `
		INSERT INTO attachments
			(group_id, user_id, purpose, object_key, content_type, byte_size, status, reservation_expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at
	`
	if err := tx.QueryRow(ctx, q, a.GroupID, a.UserID, a.Purpose, a.ObjectKey, a.ContentType,
		a.ByteSize, a.Status, a.ReservationExpiresAt).Scan(&a.ID, &a.CreatedAt); err != nil {
		return fmt.Errorf("create attachment: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit attachment create: %w", err)
	}
	return nil
}

func (r *AttachmentRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Attachment, error) {
	const q = `
		SELECT id, group_id, user_id, purpose, object_key, content_type, byte_size, status, created_at,
		       reservation_expires_at
		FROM attachments
		WHERE id = $1
	`
	var a models.Attachment
	if err := r.db.QueryRow(ctx, q, id).Scan(&a.ID, &a.GroupID, &a.UserID, &a.Purpose, &a.ObjectKey,
		&a.ContentType, &a.ByteSize, &a.Status, &a.CreatedAt, &a.ReservationExpiresAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, err
		}
		return nil, fmt.Errorf("get attachment: %w", err)
	}
	return &a, nil
}

func (r *AttachmentRepository) UpdateObjectKey(ctx context.Context, id uuid.UUID, objectKey string) error {
	const q = `UPDATE attachments SET object_key = $1 WHERE id = $2`
	ct, err := r.db.Exec(ctx, q, objectKey, id)
	if err != nil {
		return fmt.Errorf("update attachment object_key: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// FinalizeReservation atomically converts reserved bytes into used bytes.
func (r *AttachmentRepository) FinalizeReservation(ctx context.Context, id uuid.UUID, byteSize, limitBytes int64) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin attachment finalization: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var groupID uuid.UUID
	var reservedBytes int64
	var status models.AttachmentStatus
	if err := tx.QueryRow(ctx, `SELECT group_id, byte_size, status FROM attachments WHERE id = $1 FOR UPDATE`, id).
		Scan(&groupID, &reservedBytes, &status); err != nil {
		return err
	}
	if status != models.AttachmentStatusPending {
		return ErrAttachmentNotPending
	}

	const consume = `
		UPDATE groups
		SET storage_reserved_bytes = GREATEST(0, storage_reserved_bytes - $1),
		    storage_used_bytes = storage_used_bytes + $2
		WHERE id = $3
		  AND ($4 <= 0 OR storage_used_bytes + storage_reserved_bytes - $1 + $2 <= $4)
	`
	ct, err := tx.Exec(ctx, consume, reservedBytes, byteSize, groupID, limitBytes)
	if err != nil {
		return fmt.Errorf("consume storage reservation: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return ErrStorageQuotaExceeded
	}

	ct, err = tx.Exec(ctx, `
		UPDATE attachments
		SET status = 'ready', byte_size = $1, reservation_expires_at = NULL
		WHERE id = $2 AND status = 'pending'
	`, byteSize, id)
	if err != nil {
		return fmt.Errorf("finalize attachment: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return ErrAttachmentNotPending
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit attachment finalization: %w", err)
	}
	return nil
}

// MarkFailed releases a pending attachment's reservation. It is idempotent for
// attachments that have already left the pending state.
func (r *AttachmentRepository) MarkFailed(ctx context.Context, id uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin failed attachment update: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var groupID uuid.UUID
	var reservedBytes int64
	var status models.AttachmentStatus
	if err := tx.QueryRow(ctx, `SELECT group_id, byte_size, status FROM attachments WHERE id = $1 FOR UPDATE`, id).
		Scan(&groupID, &reservedBytes, &status); err != nil {
		return err
	}
	if status == models.AttachmentStatusPending {
		if _, err := tx.Exec(ctx, `
			UPDATE groups
			SET storage_reserved_bytes = GREATEST(0, storage_reserved_bytes - $1)
			WHERE id = $2
		`, reservedBytes, groupID); err != nil {
			return fmt.Errorf("release failed attachment reservation: %w", err)
		}
		if _, err := tx.Exec(ctx, `
			UPDATE attachments SET status = 'failed', reservation_expires_at = NULL WHERE id = $1
		`, id); err != nil {
			return fmt.Errorf("mark attachment failed: %w", err)
		}
	} else if status != models.AttachmentStatusFailed {
		return ErrAttachmentNotPending
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit failed attachment update: %w", err)
	}
	return nil
}

func (r *AttachmentRepository) ListCleanupCandidates(ctx context.Context, expiredBefore time.Time, limit int) ([]models.Attachment, error) {
	if limit <= 0 {
		limit = 100
	}
	const q = `
		SELECT id, group_id, user_id, purpose, object_key, content_type, byte_size, status, created_at,
		       reservation_expires_at
		FROM attachments
		WHERE status = 'failed'
		   OR (status = 'pending' AND reservation_expires_at <= $1)
		ORDER BY created_at
		LIMIT $2
	`
	rows, err := r.db.Query(ctx, q, expiredBefore, limit)
	if err != nil {
		return nil, fmt.Errorf("list attachment cleanup candidates: %w", err)
	}
	defer rows.Close()
	var attachments []models.Attachment
	for rows.Next() {
		var a models.Attachment
		if err := rows.Scan(&a.ID, &a.GroupID, &a.UserID, &a.Purpose, &a.ObjectKey, &a.ContentType,
			&a.ByteSize, &a.Status, &a.CreatedAt, &a.ReservationExpiresAt); err != nil {
			return nil, fmt.Errorf("scan attachment cleanup candidate: %w", err)
		}
		attachments = append(attachments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate attachment cleanup candidates: %w", err)
	}
	return attachments, nil
}

// Delete removes an attachment and releases either its used or reserved bytes.
func (r *AttachmentRepository) Delete(ctx context.Context, id uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin attachment delete: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var groupID uuid.UUID
	var byteSize int64
	var status models.AttachmentStatus
	if err := tx.QueryRow(ctx, `SELECT group_id, byte_size, status FROM attachments WHERE id = $1 FOR UPDATE`, id).
		Scan(&groupID, &byteSize, &status); err != nil {
		return err
	}
	if status == models.AttachmentStatusReady {
		if _, err := tx.Exec(ctx, `
			UPDATE groups SET storage_used_bytes = GREATEST(0, storage_used_bytes - $1) WHERE id = $2
		`, byteSize, groupID); err != nil {
			return fmt.Errorf("release used attachment storage: %w", err)
		}
	} else if status == models.AttachmentStatusPending {
		if _, err := tx.Exec(ctx, `
			UPDATE groups SET storage_reserved_bytes = GREATEST(0, storage_reserved_bytes - $1) WHERE id = $2
		`, byteSize, groupID); err != nil {
			return fmt.Errorf("release reserved attachment storage: %w", err)
		}
	}
	if _, err := tx.Exec(ctx, `DELETE FROM attachments WHERE id = $1`, id); err != nil {
		return fmt.Errorf("delete attachment: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit attachment delete: %w", err)
	}
	return nil
}
