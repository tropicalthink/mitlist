package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// NotificationRepository provides data access for notifications and preferences.
type NotificationRepository struct {
	db DBTX
}

// NewNotificationRepository creates a new NotificationRepository.
func NewNotificationRepository(db DBTX) *NotificationRepository {
	return &NotificationRepository{db: db}
}

// CreateNotification inserts a new notification and returns it with generated fields.
func (r *NotificationRepository) CreateNotification(ctx context.Context, n *models.Notification) error {
	query := `
		INSERT INTO notifications (id, user_id, group_id, type, title, body, data, is_read, read_at, created_at)
		VALUES ($1, $2, NULLIF($3, '00000000-0000-0000-0000-000000000000'::uuid), $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
	`
	return r.db.QueryRow(ctx, query,
		n.ID, n.UserID, n.GroupID, n.Type, n.Title, n.Body, n.Data, n.IsRead, n.ReadAt, n.CreatedAt,
	).Scan(&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt)
}

// GetNotificationByID retrieves a notification by its ID.
func (r *NotificationRepository) GetNotificationByID(ctx context.Context, id uuid.UUID) (*models.Notification, error) {
	query := `
		SELECT id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
		FROM notifications
		WHERE id = $1
	`
	var n models.Notification
	err := r.db.QueryRow(ctx, query, id).Scan(
		&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("notification not found: %w", err)
		}
		return nil, err
	}
	return &n, nil
}

// ListNotificationsByUser lists notifications for a user, newest first.
func (r *NotificationRepository) ListNotificationsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Notification, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	query := `
		SELECT id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return notifications, nil
}

// ListNotificationsByUserAndGroups applies the household allow-list carried by
// a long-lived integration credential at the query boundary.
func (r *NotificationRepository) ListNotificationsByUserAndGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, limit, offset int) ([]models.Notification, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
		FROM notifications
		WHERE user_id = $1 AND group_id = ANY($2::uuid[])
		ORDER BY created_at DESC, id DESC
		LIMIT $3 OFFSET $4
	`, userID, groupIDs, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, rows.Err()
}

// ListNotificationsByUserBefore performs stable keyset pagination. The ID
// tie-breaker prevents skips when multiple rows have the same created_at.
func (r *NotificationRepository) ListNotificationsByUserBefore(ctx context.Context, userID uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
		FROM notifications
		WHERE user_id = $1 AND (created_at, id) < ($2, $3)
		ORDER BY created_at DESC, id DESC
		LIMIT $4
	`, userID, before, beforeID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, rows.Err()
}

func (r *NotificationRepository) ListNotificationsByUserAndGroupsBefore(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, read_at, created_at
		FROM notifications
		WHERE user_id = $1 AND group_id = ANY($2::uuid[]) AND (created_at, id) < ($3, $4)
		ORDER BY created_at DESC, id DESC
		LIMIT $5
	`, userID, groupIDs, before, beforeID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.GroupID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, rows.Err()
}

// CountUnreadNotifications returns the canonical unread inbox count for a user.
func (r *NotificationRepository) CountUnreadNotifications(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM notifications
		WHERE user_id = $1 AND is_read = false
	`, userID).Scan(&count)
	return count, err
}

func (r *NotificationRepository) CountUnreadNotificationsByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM notifications
		WHERE user_id = $1 AND group_id = ANY($2::uuid[]) AND is_read = false
	`, userID, groupIDs).Scan(&count)
	return count, err
}

// MarkAsRead marks a single notification as read.
func (r *NotificationRepository) MarkAsRead(ctx context.Context, id uuid.UUID) error {
	query := `
		UPDATE notifications
		SET is_read = true, read_at = NOW()
		WHERE id = $1
	`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("notification not found")
	}
	return nil
}

// MarkAllAsRead marks all notifications for a user as read.
func (r *NotificationRepository) MarkAllAsRead(ctx context.Context, userID uuid.UUID) error {
	query := `
		UPDATE notifications
		SET is_read = true, read_at = NOW()
		WHERE user_id = $1 AND is_read = false
	`
	_, err := r.db.Exec(ctx, query, userID)
	return err
}

func (r *NotificationRepository) MarkAllAsReadByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE notifications
		SET is_read = true, read_at = NOW()
		WHERE user_id = $1 AND group_id = ANY($2::uuid[]) AND is_read = false
	`, userID, groupIDs)
	return err
}

// DeleteNotification removes a notification by ID.
func (r *NotificationRepository) DeleteNotification(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM notifications WHERE id = $1`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("notification not found")
	}
	return nil
}

// GetPreference retrieves notification preferences for a user and group.
func (r *NotificationRepository) GetPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	query := `
		SELECT id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, pinwall_reminder, push_enabled, email_enabled, created_at, updated_at
		FROM notification_preferences
		WHERE user_id = $1 AND group_id = $2
	`
	var p models.NotificationPreference
	err := r.db.QueryRow(ctx, query, userID, groupID).Scan(
		&p.ID, &p.UserID, &p.GroupID, &p.ChoreDue, &p.ChoreDueDayOf, &p.ListItemAdded,
		&p.ExpenseCreated, &p.MealPlanChanged, &p.WeeklyDigest, &p.PinwallReminder, &p.PushEnabled, &p.EmailEnabled,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("notification preference not found: %w", err)
		}
		return nil, err
	}
	return &p, nil
}

// GetPreferencesByUser retrieves all notification preferences for a user across groups.
func (r *NotificationRepository) GetPreferencesByUser(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error) {
	query := `
		SELECT id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, pinwall_reminder, push_enabled, email_enabled, created_at, updated_at
		FROM notification_preferences
		WHERE user_id = $1
		ORDER BY group_id ASC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var prefs []models.NotificationPreference
	for rows.Next() {
		var p models.NotificationPreference
		if err := rows.Scan(
			&p.ID, &p.UserID, &p.GroupID, &p.ChoreDue, &p.ChoreDueDayOf, &p.ListItemAdded,
			&p.ExpenseCreated, &p.MealPlanChanged, &p.WeeklyDigest, &p.PinwallReminder, &p.PushEnabled, &p.EmailEnabled,
			&p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		prefs = append(prefs, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return prefs, nil
}

// GetPreferencesByGroup retrieves notification preferences for all members of a group.
func (r *NotificationRepository) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	query := `
		SELECT id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, pinwall_reminder, push_enabled, email_enabled, created_at, updated_at
		FROM notification_preferences
		WHERE group_id = $1
	`
	rows, err := r.db.Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make(map[uuid.UUID]*models.NotificationPreference)
	for rows.Next() {
		var p models.NotificationPreference
		if err := rows.Scan(
			&p.ID, &p.UserID, &p.GroupID, &p.ChoreDue, &p.ChoreDueDayOf, &p.ListItemAdded,
			&p.ExpenseCreated, &p.MealPlanChanged, &p.WeeklyDigest, &p.PinwallReminder, &p.PushEnabled, &p.EmailEnabled,
			&p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		pCopy := p
		out[p.UserID] = &pCopy
	}
	return out, rows.Err()
}

// CreateNotificationsBatch inserts multiple notifications.
func (r *NotificationRepository) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	if len(notifications) == 0 {
		return nil
	}
	ids := make([]uuid.UUID, len(notifications))
	userIDs := make([]uuid.UUID, len(notifications))
	groupIDs := make([]uuid.UUID, len(notifications))
	types := make([]string, len(notifications))
	titles := make([]string, len(notifications))
	bodies := make([]string, len(notifications))
	data := make([][]byte, len(notifications))
	isRead := make([]bool, len(notifications))
	createdAt := make([]time.Time, len(notifications))
	for i := range notifications {
		n := &notifications[i]
		if n.ID == uuid.Nil {
			n.ID = uuid.New()
		}
		if n.CreatedAt.IsZero() {
			n.CreatedAt = time.Now().UTC()
		}
		n.IsRead = false
		ids[i] = n.ID
		userIDs[i] = n.UserID
		groupIDs[i] = n.GroupID
		types[i] = n.Type
		titles[i] = n.Title
		bodies[i] = n.Body
		data[i] = n.Data
		isRead[i] = n.IsRead
		createdAt[i] = n.CreatedAt
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO notifications (id, user_id, group_id, type, title, body, data, is_read, read_at, created_at)
		SELECT id, user_id, NULLIF(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, NULL::timestamptz, created_at
		FROM unnest($1::uuid[], $2::uuid[], $3::uuid[], $4::text[], $5::text[], $6::text[], $7::jsonb[], $8::bool[], $9::timestamptz[]) AS t(
			id, user_id, group_id, type, title, body, data, is_read, created_at
		)
	`, ids, userIDs, groupIDs, types, titles, bodies, data, isRead, createdAt)
	if err != nil {
		return fmt.Errorf("create notification batch: %w", err)
	}
	return nil
}

// CreateNotificationsBatchIdempotent persists scheduled notification rows by
// their user/type/dedupe_key tuple. Existing rows are updated with the latest
// copy/body and their canonical IDs are copied back into notifications so a
// retry can deliver the same inbox item instead of creating another one.
func (r *NotificationRepository) CreateNotificationsBatchIdempotent(ctx context.Context, notifications []models.Notification) error {
	if len(notifications) == 0 {
		return nil
	}
	ids := make([]uuid.UUID, len(notifications))
	userIDs := make([]uuid.UUID, len(notifications))
	groupIDs := make([]uuid.UUID, len(notifications))
	types := make([]string, len(notifications))
	titles := make([]string, len(notifications))
	bodies := make([]string, len(notifications))
	data := make([][]byte, len(notifications))
	isRead := make([]bool, len(notifications))
	createdAt := make([]time.Time, len(notifications))
	for i := range notifications {
		n := &notifications[i]
		if n.ID == uuid.Nil {
			n.ID = uuid.New()
		}
		if n.CreatedAt.IsZero() {
			n.CreatedAt = time.Now().UTC()
		}
		n.IsRead = false
		ids[i], userIDs[i], groupIDs[i] = n.ID, n.UserID, n.GroupID
		types[i], titles[i], bodies[i], data[i] = n.Type, n.Title, n.Body, n.Data
		isRead[i], createdAt[i] = n.IsRead, n.CreatedAt
	}
	rows, err := r.db.Query(ctx, `
		INSERT INTO notifications (id, user_id, group_id, type, title, body, data, is_read, read_at, created_at)
		SELECT id, user_id, NULLIF(group_id, '00000000-0000-0000-0000-000000000000'::uuid), type, title, body, data, is_read, NULL::timestamptz, created_at
		FROM unnest($1::uuid[], $2::uuid[], $3::uuid[], $4::text[], $5::text[], $6::text[], $7::jsonb[], $8::bool[], $9::timestamptz[]) AS t(
			id, user_id, group_id, type, title, body, data, is_read, created_at
		)
		ON CONFLICT (user_id, type, (data->>'dedupe_key'))
			WHERE data->>'dedupe_key' IS NOT NULL
		DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, data = EXCLUDED.data
		RETURNING id, user_id
	`, ids, userIDs, groupIDs, types, titles, bodies, data, isRead, createdAt)
	if err != nil {
		return fmt.Errorf("create idempotent notification batch: %w", err)
	}
	defer rows.Close()
	canonicalIDs := make(map[uuid.UUID]uuid.UUID, len(notifications))
	for rows.Next() {
		var id, userID uuid.UUID
		if err := rows.Scan(&id, &userID); err != nil {
			return fmt.Errorf("scan idempotent notification: %w", err)
		}
		canonicalIDs[userID] = id
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("idempotent notification rows: %w", err)
	}
	for i := range notifications {
		if id, ok := canonicalIDs[notifications[i].UserID]; ok {
			notifications[i].ID = id
		}
	}
	return nil
}

// listNotificationBatchMaxNames caps how many item names a batch remembers for
// the digest body; the count keeps growing past it.
const listNotificationBatchMaxNames = 8

// QueueListItemNotification coalesces additions by the same person to the same
// list into one pending digest. Each add pushes delivery out by three minutes;
// the client flushes the batch when the person leaves the list screen, so the
// sliding window only fires for sessions that never end cleanly (app killed,
// offline sync). A fifteen-minute cap guarantees delivery regardless.
func (r *NotificationRepository) QueueListItemNotification(ctx context.Context, groupID, actorID, listID uuid.UUID, actorName, listName, itemName string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO list_notification_batches (
			group_id, actor_id, list_id, actor_name, list_name, last_item_name, item_names
		) VALUES ($1, $2, $3, $4, $5, $6, ARRAY[$6::TEXT])
		ON CONFLICT (group_id, actor_id, list_id) DO UPDATE SET
			actor_name = EXCLUDED.actor_name,
			list_name = EXCLUDED.list_name,
			last_item_name = EXCLUDED.last_item_name,
			item_count = CASE
				WHEN list_notification_batches.claimed_at IS NULL THEN list_notification_batches.item_count + 1
				ELSE 1
			END,
			item_names = CASE
				WHEN list_notification_batches.claimed_at IS NOT NULL THEN ARRAY[$6::TEXT]
				WHEN COALESCE(array_length(list_notification_batches.item_names, 1), 0) >= $7 THEN list_notification_batches.item_names
				ELSE list_notification_batches.item_names || $6::TEXT
			END,
			first_at = CASE
				WHEN list_notification_batches.claimed_at IS NULL THEN list_notification_batches.first_at
				ELSE NOW()
			END,
			updated_at = NOW(),
			deliver_after = CASE
				WHEN list_notification_batches.claimed_at IS NULL THEN LEAST(
					list_notification_batches.first_at + INTERVAL '15 minutes',
					NOW() + INTERVAL '3 minutes'
				)
				ELSE NOW() + INTERVAL '3 minutes'
			END,
			claimed_at = NULL
	`, groupID, actorID, listID, actorName, listName, itemName, listNotificationBatchMaxNames)
	if err != nil {
		return fmt.Errorf("queue list notification: %w", err)
	}
	return nil
}

// FlushListNotificationBatches makes any pending list digest for this actor and
// list deliverable immediately. Called when the person leaves the list screen so
// the household gets one summary right after the adding session ends.
// updated_at is intentionally left untouched: the digest job deletes a claimed
// batch only when updated_at is unchanged, and a flush must not make a batch
// that is mid-delivery look freshly modified.
func (r *NotificationRepository) FlushListNotificationBatches(ctx context.Context, actorID, listID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE list_notification_batches
		SET deliver_after = NOW()
		WHERE actor_id = $1 AND list_id = $2 AND claimed_at IS NULL
	`, actorID, listID)
	if err != nil {
		return fmt.Errorf("flush list notification batches: %w", err)
	}
	return nil
}

// UpsertPreference inserts or updates notification preferences for a user/group.
func (r *NotificationRepository) UpsertPreference(ctx context.Context, pref *models.NotificationPreference) error {
	query := `
		INSERT INTO notification_preferences (
			id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, pinwall_reminder, push_enabled, email_enabled, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
		ON CONFLICT (user_id, group_id)
		DO UPDATE SET
			chore_due = EXCLUDED.chore_due,
			chore_due_day_of = EXCLUDED.chore_due_day_of,
			list_item_added = EXCLUDED.list_item_added,
			expense_created = EXCLUDED.expense_created,
			meal_plan_changed = EXCLUDED.meal_plan_changed,
			weekly_digest = EXCLUDED.weekly_digest,
			pinwall_reminder = EXCLUDED.pinwall_reminder,
			push_enabled = EXCLUDED.push_enabled,
			email_enabled = EXCLUDED.email_enabled,
			updated_at = NOW()
		RETURNING id, created_at, updated_at
	`
	pref.ID = uuid.New()
	return r.db.QueryRow(ctx, query,
		pref.ID, pref.UserID, pref.GroupID, pref.ChoreDue, pref.ChoreDueDayOf, pref.ListItemAdded,
		pref.ExpenseCreated, pref.MealPlanChanged, pref.WeeklyDigest, pref.PinwallReminder, pref.PushEnabled, pref.EmailEnabled,
	).Scan(&pref.ID, &pref.CreatedAt, &pref.UpdatedAt)
}
