package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

type ExpenseAttachmentRepository struct {
	db *pgxpool.Pool
}

func NewExpenseAttachmentRepository(db *pgxpool.Pool) *ExpenseAttachmentRepository {
	return &ExpenseAttachmentRepository{db: db}
}

func (r *ExpenseAttachmentRepository) Add(ctx context.Context, expenseID, attachmentID uuid.UUID) error {
	const q = `
		INSERT INTO expense_attachments (expense_id, attachment_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`
	if _, err := r.db.Exec(ctx, q, expenseID, attachmentID); err != nil {
		return fmt.Errorf("add expense attachment: %w", err)
	}
	return nil
}

func (r *ExpenseAttachmentRepository) Remove(ctx context.Context, expenseID, attachmentID uuid.UUID) error {
	const q = `DELETE FROM expense_attachments WHERE expense_id = $1 AND attachment_id = $2`
	ct, err := r.db.Exec(ctx, q, expenseID, attachmentID)
	if err != nil {
		return fmt.Errorf("remove expense attachment: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *ExpenseAttachmentRepository) ListReadyAttachmentsByExpense(ctx context.Context, expenseID uuid.UUID) ([]models.Attachment, error) {
	const q = `
		SELECT a.id, a.group_id, a.user_id, a.purpose, a.object_key, a.content_type, a.byte_size, a.status, a.created_at,
		       a.reservation_expires_at
		FROM expense_attachments ea
		JOIN attachments a ON a.id = ea.attachment_id
		WHERE ea.expense_id = $1 AND a.status = 'ready'
		ORDER BY ea.created_at DESC
	`
	rows, err := r.db.Query(ctx, q, expenseID)
	if err != nil {
		return nil, fmt.Errorf("list expense attachments: %w", err)
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Attachment])
}
