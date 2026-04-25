package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

// VaultRepository provides data access for vault items and shares.
type VaultRepository struct {
	db DBTX
}

// NewVaultRepository creates a new VaultRepository.
func NewVaultRepository(db DBTX) *VaultRepository {
	return &VaultRepository{db: db}
}

// CreateVaultItem inserts a new vault item and returns it with generated fields.
func (r *VaultRepository) CreateVaultItem(ctx context.Context, item *models.VaultItem) error {
	query := `
		INSERT INTO vault_items (id, group_id, type, title, content, reminder_date, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, group_id, type, title, content, reminder_date, created_by, created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		item.ID, item.GroupID, item.Type, item.Title, item.Content, item.ReminderDate, item.CreatedBy, item.CreatedAt, item.UpdatedAt,
	).Scan(&item.ID, &item.GroupID, &item.Type, &item.Title, &item.Content, &item.ReminderDate, &item.CreatedBy, &item.CreatedAt, &item.UpdatedAt)
}

// GetVaultItemByID retrieves a vault item by its ID.
func (r *VaultRepository) GetVaultItemByID(ctx context.Context, id uuid.UUID) (*models.VaultItem, error) {
	query := `
		SELECT id, group_id, type, title, content, reminder_date, created_by, created_at, updated_at
		FROM vault_items
		WHERE id = $1
	`
	var item models.VaultItem
	err := r.db.QueryRow(ctx, query, id).Scan(
		&item.ID, &item.GroupID, &item.Type, &item.Title, &item.Content, &item.ReminderDate, &item.CreatedBy, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("vault item not found: %w", err)
		}
		return nil, err
	}
	return &item, nil
}

// ListVaultItemsByGroup lists vault items for a group, newest first.
func (r *VaultRepository) ListVaultItemsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.VaultItem, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	query := `
		SELECT id, group_id, type, title, content, reminder_date, created_by, created_at, updated_at
		FROM vault_items
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.VaultItem
	for rows.Next() {
		var item models.VaultItem
		if err := rows.Scan(
			&item.ID, &item.GroupID, &item.Type, &item.Title, &item.Content, &item.ReminderDate, &item.CreatedBy, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

// UpdateVaultItem updates an existing vault item.
func (r *VaultRepository) UpdateVaultItem(ctx context.Context, item *models.VaultItem) error {
	query := `
		UPDATE vault_items
		SET type = $1, title = $2, content = $3, reminder_date = $4, updated_at = NOW()
		WHERE id = $5
	`
	cmd, err := r.db.Exec(ctx, query, item.Type, item.Title, item.Content, item.ReminderDate, item.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("vault item not found")
	}
	return nil
}

// DeleteVaultItem removes a vault item by ID.
func (r *VaultRepository) DeleteVaultItem(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM vault_items WHERE id = $1`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("vault item not found")
	}
	return nil
}

// CreateShare inserts a new vault share and returns it with generated fields.
func (r *VaultRepository) CreateShare(ctx context.Context, share *models.VaultShare) error {
	query := `
		INSERT INTO vault_shares (id, vault_item_id, shared_with_user_id, permission, created_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, vault_item_id, shared_with_user_id, permission, created_at
	`
	return r.db.QueryRow(ctx, query,
		share.ID, share.VaultItemID, share.SharedWithUserID, share.Permission, share.CreatedAt,
	).Scan(&share.ID, &share.VaultItemID, &share.SharedWithUserID, &share.Permission, &share.CreatedAt)
}

// ListShares lists all shares for a vault item.
func (r *VaultRepository) ListShares(ctx context.Context, vaultItemID uuid.UUID) ([]models.VaultShare, error) {
	query := `
		SELECT id, vault_item_id, shared_with_user_id, permission, created_at
		FROM vault_shares
		WHERE vault_item_id = $1
		ORDER BY created_at DESC, id DESC
	`
	rows, err := r.db.Query(ctx, query, vaultItemID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var shares []models.VaultShare
	for rows.Next() {
		var s models.VaultShare
		if err := rows.Scan(&s.ID, &s.VaultItemID, &s.SharedWithUserID, &s.Permission, &s.CreatedAt); err != nil {
			return nil, err
		}
		shares = append(shares, s)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return shares, nil
}

// DeleteShare removes a vault share by ID.
func (r *VaultRepository) DeleteShare(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM vault_shares WHERE id = $1`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("vault share not found")
	}
	return nil
}
