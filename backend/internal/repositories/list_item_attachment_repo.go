package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

type ListItemAttachmentRepository struct {
	db *pgxpool.Pool
}

func NewListItemAttachmentRepository(db *pgxpool.Pool) *ListItemAttachmentRepository {
	return &ListItemAttachmentRepository{db: db}
}

func (r *ListItemAttachmentRepository) Add(ctx context.Context, listItemID, attachmentID uuid.UUID) error {
	const q = `
		INSERT INTO list_item_attachments (list_item_id, attachment_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`
	if _, err := r.db.Exec(ctx, q, listItemID, attachmentID); err != nil {
		return fmt.Errorf("add list item attachment: %w", err)
	}
	return nil
}

func (r *ListItemAttachmentRepository) Remove(ctx context.Context, listItemID, attachmentID uuid.UUID) error {
	const q = `DELETE FROM list_item_attachments WHERE list_item_id = $1 AND attachment_id = $2`
	ct, err := r.db.Exec(ctx, q, listItemID, attachmentID)
	if err != nil {
		return fmt.Errorf("remove list item attachment: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *ListItemAttachmentRepository) ListReadyAttachmentsByListItem(ctx context.Context, listItemID uuid.UUID) ([]models.Attachment, error) {
	const q = `
		SELECT a.id, a.group_id, a.user_id, a.purpose, a.object_key, a.content_type, a.byte_size, a.status, a.created_at
		FROM list_item_attachments lia
		JOIN attachments a ON a.id = lia.attachment_id
		WHERE lia.list_item_id = $1 AND a.status = 'ready'
		ORDER BY lia.created_at DESC
	`
	rows, err := r.db.Query(ctx, q, listItemID)
	if err != nil {
		return nil, fmt.Errorf("list list item attachments: %w", err)
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Attachment])
}

