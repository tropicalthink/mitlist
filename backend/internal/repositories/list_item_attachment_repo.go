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

// ListReadyAttachmentsByList returns every ready attachment for the list's
// non-deleted items, keyed by list item id, so a screen can hydrate all photo
// thumbnails with one query instead of one per item.
func (r *ListItemAttachmentRepository) ListReadyAttachmentsByList(ctx context.Context, listID uuid.UUID) (map[uuid.UUID][]models.Attachment, error) {
	const q = `
		SELECT lia.list_item_id, a.id, a.group_id, a.user_id, a.purpose, a.object_key, a.content_type, a.byte_size, a.status, a.created_at
		FROM list_item_attachments lia
		JOIN attachments a ON a.id = lia.attachment_id
		JOIN list_items li ON li.id = lia.list_item_id
		WHERE li.list_id = $1 AND li.deleted_at IS NULL AND a.status = 'ready'
		ORDER BY lia.created_at DESC
	`
	rows, err := r.db.Query(ctx, q, listID)
	if err != nil {
		return nil, fmt.Errorf("list attachments by list: %w", err)
	}
	defer rows.Close()

	out := make(map[uuid.UUID][]models.Attachment)
	for rows.Next() {
		var itemID uuid.UUID
		var a models.Attachment
		if err := rows.Scan(&itemID, &a.ID, &a.GroupID, &a.UserID, &a.Purpose, &a.ObjectKey, &a.ContentType, &a.ByteSize, &a.Status, &a.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan attachment by list: %w", err)
		}
		out[itemID] = append(out[itemID], a)
	}
	return out, rows.Err()
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
