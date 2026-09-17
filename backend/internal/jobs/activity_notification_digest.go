package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type activityNotificationBatch struct {
	ID           uuid.UUID
	GroupID      uuid.UUID
	ActorID      uuid.UUID
	Type         string
	ActorName    string
	LastItemName string
	ItemNames    []string
	ItemCount    int
	Title        string
	Body         string
	Payload      json.RawMessage
	GroupName    string
	UpdatedAt    time.Time
}

type activityNotificationBatchRepo interface {
	ClaimDueActivityNotificationBatches(ctx context.Context, now time.Time, limit int) ([]activityNotificationBatch, error)
	DeleteClaimedActivityNotificationBatch(ctx context.Context, id uuid.UUID, updatedAt time.Time) error
}

type postgresActivityNotificationBatchRepo struct{ db repositories.DBTX }

func (r *postgresActivityNotificationBatchRepo) ClaimDueActivityNotificationBatches(ctx context.Context, now time.Time, limit int) ([]activityNotificationBatch, error) {
	rows, err := r.db.Query(ctx, `
		WITH due AS (
			SELECT id
			FROM activity_notification_batches
			WHERE deliver_after <= $1
			  AND (claimed_at IS NULL OR claimed_at < NOW() - INTERVAL '5 minutes')
			ORDER BY deliver_after, id
			FOR UPDATE SKIP LOCKED
			LIMIT $2
		), claimed AS (
			UPDATE activity_notification_batches b
			SET claimed_at = NOW()
			FROM due
			WHERE b.id = due.id
			RETURNING b.id, b.group_id, b.actor_id, b.n_type, b.actor_name,
				b.last_item_name, b.item_names, b.item_count, b.title, b.body, b.payload, b.updated_at
		)
		SELECT c.id, c.group_id, c.actor_id, c.n_type, c.actor_name,
			c.last_item_name, c.item_names, c.item_count, c.title, c.body, c.payload, c.updated_at, g.name
		FROM claimed c
		JOIN groups g ON g.id = c.group_id
		ORDER BY c.updated_at, c.id
	`, now, limit)
	if err != nil {
		return nil, fmt.Errorf("claim activity notification batches: %w", err)
	}
	defer rows.Close()

	var batches []activityNotificationBatch
	for rows.Next() {
		var batch activityNotificationBatch
		if err := rows.Scan(
			&batch.ID, &batch.GroupID, &batch.ActorID, &batch.Type, &batch.ActorName,
			&batch.LastItemName, &batch.ItemNames, &batch.ItemCount, &batch.Title, &batch.Body,
			&batch.Payload, &batch.UpdatedAt, &batch.GroupName,
		); err != nil {
			return nil, err
		}
		batches = append(batches, batch)
	}
	return batches, rows.Err()
}

func (r *postgresActivityNotificationBatchRepo) DeleteClaimedActivityNotificationBatch(ctx context.Context, id uuid.UUID, updatedAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		DELETE FROM activity_notification_batches
		WHERE id = $1 AND updated_at = $2 AND claimed_at IS NOT NULL
	`, id, updatedAt)
	return err
}

// ActivityNotificationDigest delivers coalesced interactive notifications once
// the actor's burst of edits has gone quiet. A batch holding a single event is
// replayed exactly as it would have been sent immediately; a larger batch
// becomes one summary notification per type.
type ActivityNotificationDigest struct {
	repo       activityNotificationBatchRepo
	dispatcher ImmediateNotificationDispatcher
	log        *logger.Logger
}

func NewActivityNotificationDigest(db repositories.DBTX, dispatcher ImmediateNotificationDispatcher, log *logger.Logger) *ActivityNotificationDigest {
	return &ActivityNotificationDigest{
		repo:       &postgresActivityNotificationBatchRepo{db: db},
		dispatcher: dispatcher,
		log:        log,
	}
}

func (j *ActivityNotificationDigest) Run() {
	ctx := context.Background()
	batches, err := j.repo.ClaimDueActivityNotificationBatches(ctx, time.Now().UTC(), 200)
	if err != nil {
		j.log.Error().Err(err).Msg("failed to claim activity notification batches")
		return
	}
	for _, batch := range batches {
		nType, title, body, payload := renderActivityDigest(batch)
		if err := j.dispatcher.DispatchToGroupNow(ctx, batch.GroupID, batch.ActorID, nType, title, body, payload); err != nil {
			j.log.Error().Err(err).
				Str("batch_id", batch.ID.String()).
				Str("notification_type", batch.Type).
				Msg("failed to dispatch activity notification digest")
			continue
		}
		if err := j.repo.DeleteClaimedActivityNotificationBatch(ctx, batch.ID, batch.UpdatedAt); err != nil {
			j.log.Error().Err(err).Str("batch_id", batch.ID.String()).Msg("failed to finish activity notification digest")
		}
	}
}

// renderActivityDigest turns a claimed batch into the notification to send. The
// stored payload is always the latest event's, so its deep link stays valid for
// the single-event replay and points at the most recent entity otherwise.
func renderActivityDigest(batch activityNotificationBatch) (string, string, string, models.NotificationPayload) {
	var payload models.NotificationPayload
	if len(batch.Payload) > 0 {
		_ = json.Unmarshal(batch.Payload, &payload)
	}
	payload.GroupID = batch.GroupID.String()
	payload.ActorName = batch.ActorName
	if batch.ItemCount <= 1 {
		return batch.Type, batch.Title, batch.Body, payload
	}

	names := joinDigestItemNames(batch.ItemNames, batch.ItemCount)
	count := fmt.Sprintf("%d", batch.ItemCount)
	switch batch.Type {
	case models.NotificationTypeMealPlanChanged:
		body := fmt.Sprintf("%s made %d changes to the meal plan in %s.", batch.ActorName, batch.ItemCount, batch.GroupName)
		if names != "" {
			body = fmt.Sprintf("%s made %d changes to the meal plan in %s: %s", batch.ActorName, batch.ItemCount, batch.GroupName, names)
		}
		payload.Screen = models.ScreenMealPlan
		payload.EntityType = models.EntityTypeMealPlan
		payload.EntityName = "Meal plan"
		payload.ItemName = batch.LastItemName
		payload.Copy = models.NewNotificationCopy(models.NotificationTemplateMealPlanChangedDigest, map[string]string{
			"actor_name":   batch.ActorName,
			"group_name":   batch.GroupName,
			"change_count": count,
			"item_names":   names,
		})
		return batch.Type, "Meal plan updated", body, payload
	case models.NotificationTypeExpenseCreated:
		body := fmt.Sprintf("%s added %d expenses in %s.", batch.ActorName, batch.ItemCount, batch.GroupName)
		if names != "" {
			body = fmt.Sprintf("%s added %d expenses in %s: %s", batch.ActorName, batch.ItemCount, batch.GroupName, names)
		}
		payload.Screen = models.ScreenExpenseDetail
		payload.EntityType = models.EntityTypeExpense
		payload.EntityName = batch.LastItemName
		payload.Copy = models.NewNotificationCopy(models.NotificationTemplateExpensesCreatedDigest, map[string]string{
			"actor_name":    batch.ActorName,
			"group_name":    batch.GroupName,
			"expense_count": count,
			"expense_names": names,
		})
		return batch.Type, "Expenses added", body, payload
	default:
		// Unknown coalesced type: fall back to the latest event's own copy with a
		// count so nothing is silently lost.
		body := fmt.Sprintf("%s (%d updates)", batch.Body, batch.ItemCount)
		return batch.Type, batch.Title, body, payload
	}
}
