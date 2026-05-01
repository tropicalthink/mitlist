package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

type PinwallAttachmentRepository struct {
	db *pgxpool.Pool
}

func NewPinwallAttachmentRepository(db *pgxpool.Pool) *PinwallAttachmentRepository {
	return &PinwallAttachmentRepository{db: db}
}

func (r *PinwallAttachmentRepository) Add(ctx context.Context, postID, attachmentID uuid.UUID) error {
	const q = `
		INSERT INTO pinwall_post_attachments (pinwall_post_id, attachment_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`
	if _, err := r.db.Exec(ctx, q, postID, attachmentID); err != nil {
		return fmt.Errorf("add pinwall attachment: %w", err)
	}
	return nil
}

func (r *PinwallAttachmentRepository) Remove(ctx context.Context, postID, attachmentID uuid.UUID) error {
	const q = `DELETE FROM pinwall_post_attachments WHERE pinwall_post_id = $1 AND attachment_id = $2`
	ct, err := r.db.Exec(ctx, q, postID, attachmentID)
	if err != nil {
		return fmt.Errorf("remove pinwall attachment: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *PinwallAttachmentRepository) ListReadyAttachmentsByPost(ctx context.Context, postID uuid.UUID) ([]models.Attachment, error) {
	const q = `
		SELECT a.id, a.group_id, a.user_id, a.purpose, a.object_key, a.content_type, a.byte_size, a.status, a.created_at
		FROM pinwall_post_attachments pa
		JOIN attachments a ON a.id = pa.attachment_id
		WHERE pa.pinwall_post_id = $1 AND a.status = 'ready'
		ORDER BY pa.created_at DESC
	`
	rows, err := r.db.Query(ctx, q, postID)
	if err != nil {
		return nil, fmt.Errorf("list pinwall attachments: %w", err)
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Attachment])
}

