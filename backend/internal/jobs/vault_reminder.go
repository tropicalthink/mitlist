package jobs

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/pkg/logger"
)

// VaultReminder queries vault items with due reminders, sends push
// notifications, and clears the reminder date. Run hourly.
type VaultReminder struct {
	repo vaultReminderRepo
	push Pusher
	log  *logger.Logger
}

// NewVaultReminder creates a new VaultReminder.
func NewVaultReminder(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *VaultReminder {
	return &VaultReminder{repo: &vaultReminderRepoImpl{pool: pool}, push: push, log: log}
}

func newVaultReminder(repo vaultReminderRepo, push Pusher, log *logger.Logger) *VaultReminder {
	return &VaultReminder{repo: repo, push: push, log: log}
}

type vaultPushPayload struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

// Run executes the vault reminder job.
func (r *VaultReminder) Run() {
	ctx := context.Background()
	r.log.Info().Msg("vault reminder job started")

	items, err := r.repo.ListDueVaultItems(ctx)
	if err != nil {
		r.log.Error().Err(err).Msg("failed to list due vault items")
		return
	}

	for _, item := range items {
		if err := r.processVaultItem(ctx, item); err != nil {
			r.log.Error().Err(err).Str("item_id", item.ID.String()).Msg("failed to process vault item")
		}
	}
}

func (r *VaultReminder) processVaultItem(ctx context.Context, item models.VaultItem) error {
	vaultPushPayload := vaultPushPayload{Title: "Vault Reminder", Body: "Reminder for " + item.Title}
	data, _ := json.Marshal(vaultPushPayload)
	pushErr := r.push.BroadcastToGroup(item.GroupID, string(data))
	if pushErr != nil {
		r.log.Warn().Err(pushErr).Str("item_id", item.ID.String()).Msg("failed to send vault reminder push")
	}

	if err := r.repo.ClearVaultReminder(ctx, item.ID); err != nil {
		return fmt.Errorf("clear reminder date: %w", err)
	}

	if pushErr != nil {
		r.log.Warn().Str("item_id", item.ID.String()).Msg("vault reminder cleared but push failed")
	} else {
		r.log.Info().Str("item_id", item.ID.String()).Msg("vault reminder sent and cleared")
	}
	return nil
}

type vaultReminderRepoImpl struct {
	pool *pgxpool.Pool
}

func (r *vaultReminderRepoImpl) ListDueVaultItems(ctx context.Context) ([]models.VaultItem, error) {
	query := `
		SELECT id, group_id, type, title, content, reminder_date, created_by, created_at, updated_at
		FROM vault_items
		WHERE reminder_date IS NOT NULL AND reminder_date <= NOW()
	`
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query due vault items: %w", err)
	}
	defer rows.Close()

	var items []models.VaultItem
	for rows.Next() {
		var item models.VaultItem
		if err := rows.Scan(
			&item.ID, &item.GroupID, &item.Type, &item.Title,
			&item.Content, &item.ReminderDate, &item.CreatedBy,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan vault item: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return items, nil
}

func (r *vaultReminderRepoImpl) ClearVaultReminder(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE vault_items
		SET reminder_date = NULL
		WHERE id = $1
	`, id)
	if err != nil {
		return fmt.Errorf("clear reminder date: %w", err)
	}
	return nil
}
