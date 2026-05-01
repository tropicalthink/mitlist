package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

type AttachmentRepository struct {
	db *pgxpool.Pool
}

func NewAttachmentRepository(db *pgxpool.Pool) *AttachmentRepository {
	return &AttachmentRepository{db: db}
}

func (r *AttachmentRepository) Create(ctx context.Context, a *models.Attachment) error {
	const q = `
		INSERT INTO attachments (group_id, user_id, purpose, object_key, content_type, byte_size, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at
	`
	if err := r.db.QueryRow(ctx, q, a.GroupID, a.UserID, a.Purpose, a.ObjectKey, a.ContentType, a.ByteSize, a.Status).
		Scan(&a.ID, &a.CreatedAt); err != nil {
		return fmt.Errorf("create attachment: %w", err)
	}
	return nil
}

func (r *AttachmentRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Attachment, error) {
	const q = `
		SELECT id, group_id, user_id, purpose, object_key, content_type, byte_size, status, created_at
		FROM attachments
		WHERE id = $1
	`
	var a models.Attachment
	if err := r.db.QueryRow(ctx, q, id).
		Scan(&a.ID, &a.GroupID, &a.UserID, &a.Purpose, &a.ObjectKey, &a.ContentType, &a.ByteSize, &a.Status, &a.CreatedAt); err != nil {
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

func (r *AttachmentRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status models.AttachmentStatus) error {
	const q = `UPDATE attachments SET status = $1 WHERE id = $2`
	ct, err := r.db.Exec(ctx, q, status, id)
	if err != nil {
		return fmt.Errorf("update attachment status: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *AttachmentRepository) Delete(ctx context.Context, id uuid.UUID) error {
	const q = `DELETE FROM attachments WHERE id = $1`
	ct, err := r.db.Exec(ctx, q, id)
	if err != nil {
		return fmt.Errorf("delete attachment: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *AttachmentRepository) SumReadyBytesByGroup(ctx context.Context, groupID uuid.UUID) (int64, error) {
	const q = `
		SELECT COALESCE(SUM(byte_size), 0)
		FROM attachments
		WHERE group_id = $1 AND status = 'ready'
	`
	var sum int64
	if err := r.db.QueryRow(ctx, q, groupID).Scan(&sum); err != nil {
		return 0, fmt.Errorf("sum attachment bytes: %w", err)
	}
	return sum, nil
}

