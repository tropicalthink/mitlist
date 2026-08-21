package jobs

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type listNotificationBatch struct {
	ID           uuid.UUID
	GroupID      uuid.UUID
	ActorID      uuid.UUID
	ListID       uuid.UUID
	ActorName    string
	ListName     string
	LastItemName string
	GroupName    string
	ItemCount    int
	ItemNames    []string
	UpdatedAt    time.Time
}

type listNotificationBatchRepo interface {
	ClaimDueListNotificationBatches(ctx context.Context, now time.Time, limit int) ([]listNotificationBatch, error)
	DeleteClaimedListNotificationBatch(ctx context.Context, id uuid.UUID, updatedAt time.Time) error
}

type postgresListNotificationBatchRepo struct{ db repositories.DBTX }

func (r *postgresListNotificationBatchRepo) ClaimDueListNotificationBatches(ctx context.Context, now time.Time, limit int) ([]listNotificationBatch, error) {
	rows, err := r.db.Query(ctx, `
		WITH due AS (
			SELECT id
			FROM list_notification_batches
			WHERE deliver_after <= $1
			  AND (claimed_at IS NULL OR claimed_at < NOW() - INTERVAL '5 minutes')
			ORDER BY deliver_after, id
			FOR UPDATE SKIP LOCKED
			LIMIT $2
		), claimed AS (
			UPDATE list_notification_batches b
			SET claimed_at = NOW()
			FROM due
			WHERE b.id = due.id
			RETURNING b.id, b.group_id, b.actor_id, b.list_id, b.actor_name,
				b.list_name, b.last_item_name, b.item_count, b.item_names, b.updated_at
		)
		SELECT c.id, c.group_id, c.actor_id, c.list_id, c.actor_name,
			c.list_name, c.last_item_name, c.item_count, c.item_names, c.updated_at, g.name
		FROM claimed c
		JOIN groups g ON g.id = c.group_id
		ORDER BY c.updated_at, c.id
	`, now, limit)
	if err != nil {
		return nil, fmt.Errorf("claim list notification batches: %w", err)
	}
	defer rows.Close()

	var batches []listNotificationBatch
	for rows.Next() {
		var batch listNotificationBatch
		if err := rows.Scan(
			&batch.ID, &batch.GroupID, &batch.ActorID, &batch.ListID,
			&batch.ActorName, &batch.ListName, &batch.LastItemName,
			&batch.ItemCount, &batch.ItemNames, &batch.UpdatedAt, &batch.GroupName,
		); err != nil {
			return nil, err
		}
		batches = append(batches, batch)
	}
	return batches, rows.Err()
}

func (r *postgresListNotificationBatchRepo) DeleteClaimedListNotificationBatch(ctx context.Context, id uuid.UUID, updatedAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		DELETE FROM list_notification_batches
		WHERE id = $1 AND updated_at = $2 AND claimed_at IS NOT NULL
	`, id, updatedAt)
	return err
}

// joinDigestItemNames renders the remembered item names for the digest body.
// The batch stores at most the first few names; when the count outgrew that
// cap an ellipsis marks the truncation.
func joinDigestItemNames(names []string, itemCount int) string {
	if len(names) == 0 {
		return ""
	}
	joined := strings.Join(names, ", ")
	if itemCount > len(names) {
		joined += ", …"
	}
	return joined
}

// ListNotificationDigest turns rapid list-item additions into one useful inbox
// entry and push instead of notifying once per item.
type ListNotificationDigest struct {
	repo       listNotificationBatchRepo
	dispatcher NotificationDispatcher
	log        *logger.Logger
}

func NewListNotificationDigest(db repositories.DBTX, dispatcher NotificationDispatcher, log *logger.Logger) *ListNotificationDigest {
	return &ListNotificationDigest{
		repo:       &postgresListNotificationBatchRepo{db: db},
		dispatcher: dispatcher,
		log:        log,
	}
}

func (j *ListNotificationDigest) Run() {
	batches, err := j.repo.ClaimDueListNotificationBatches(context.Background(), time.Now().UTC(), 200)
	if err != nil {
		j.log.Error().Err(err).Msg("failed to claim list notification batches")
		return
	}
	for _, batch := range batches {
		itemNames := joinDigestItemNames(batch.ItemNames, batch.ItemCount)
		body := fmt.Sprintf("%s added %s to %s in %s.", batch.ActorName, batch.LastItemName, batch.ListName, batch.GroupName)
		if batch.ItemCount > 1 {
			body = fmt.Sprintf("%s added %d items to %s in %s.", batch.ActorName, batch.ItemCount, batch.ListName, batch.GroupName)
			if itemNames != "" {
				body = fmt.Sprintf("%s added %d items to %s in %s: %s", batch.ActorName, batch.ItemCount, batch.ListName, batch.GroupName, itemNames)
			}
		}
		payload := models.NotificationPayload{
			Screen:     models.ScreenListDetail,
			EntityType: models.EntityTypeList,
			ID:         batch.ListID.String(),
			GroupID:    batch.GroupID.String(),
			ActorName:  batch.ActorName,
			EntityName: batch.ListName,
			ItemName:   batch.LastItemName,
			Copy: models.NewNotificationCopy(models.NotificationTemplateListItemsAdded, map[string]string{
				"actor_name":     batch.ActorName,
				"item_count":     fmt.Sprintf("%d", batch.ItemCount),
				"last_item_name": batch.LastItemName,
				"item_names":     itemNames,
				"list_name":      batch.ListName,
				"group_name":     batch.GroupName,
			}),
		}
		if err := j.dispatcher.DispatchToGroup(
			context.Background(), batch.GroupID, batch.ActorID,
			models.NotificationTypeListItemsAddedDigest, batch.ListName+" updated", body, payload,
		); err != nil {
			j.log.Error().Err(err).Str("batch_id", batch.ID.String()).Msg("failed to dispatch list notification digest")
			continue
		}
		if err := j.repo.DeleteClaimedListNotificationBatch(context.Background(), batch.ID, batch.UpdatedAt); err != nil {
			j.log.Error().Err(err).Str("batch_id", batch.ID.String()).Msg("failed to finish list notification digest")
		}
	}
}
