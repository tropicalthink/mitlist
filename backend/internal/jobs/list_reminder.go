package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// ListReminder sends one-time reminders for lists with remind_at set.
// Runs every minute. It mirrors PinwallReminder: the whole household receives
// the reminder (the person who set it included), gated by the shared
// "reminders" notification preference.
type ListReminder struct {
	repo       listReminderRepo
	log        *logger.Logger
	push       Pusher
	dispatcher NotificationDispatcher // preferred; manual batch+push used as fallback
}

// dueListReminder is one claimed reminder plus the context the notification needs.
type dueListReminder struct {
	List      models.List
	OpenItems int
}

type listReminderRepo interface {
	ListDueReminders(ctx context.Context, before time.Time, limit int) ([]dueListReminder, error)
	ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error)
	GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error)
	CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error
	MarkReminderSent(ctx context.Context, listID uuid.UUID, sentAt time.Time) (bool, error)
}

func NewListReminder(db repositories.DBTX, push Pusher, log *logger.Logger) *ListReminder {
	return &ListReminder{repo: &listReminderRepoImpl{db: db}, log: log, push: push}
}

// NewListReminderWithDispatcher creates a ListReminder that routes through the dispatcher.
func NewListReminderWithDispatcher(db repositories.DBTX, dispatcher NotificationDispatcher, log *logger.Logger) *ListReminder {
	return &ListReminder{repo: &listReminderRepoImpl{db: db}, log: log, dispatcher: dispatcher}
}

func (r *ListReminder) Run() {
	ctx := context.Background()
	now := time.Now().UTC()
	r.log.Info().Time("now", now).Msg("list reminder job started")

	due, err := r.repo.ListDueReminders(ctx, now, 200)
	if err != nil {
		r.log.Error().Err(err).Msg("failed to list due list reminders")
		return
	}
	if len(due) == 0 {
		return
	}

	groupCache := make(map[uuid.UUID]*groupReminderCache)
	for _, d := range due {
		cache, ok := groupCache[d.List.GroupID]
		if !ok {
			members, err := r.repo.ListGroupMembers(ctx, d.List.GroupID)
			if err != nil {
				r.log.Warn().Err(err).Str("group_id", d.List.GroupID.String()).Msg("failed to list group members")
				continue
			}
			prefs, err := r.repo.GetPreferencesByGroup(ctx, d.List.GroupID)
			if err != nil {
				r.log.Warn().Err(err).Str("group_id", d.List.GroupID.String()).Msg("failed to load group preferences")
				prefs = map[uuid.UUID]*models.NotificationPreference{}
			}
			cache = &groupReminderCache{members: members, prefs: prefs}
			groupCache[d.List.GroupID] = cache
		}
		if err := r.sendForList(ctx, d, cache); err != nil {
			r.log.Warn().Err(err).Str("list_id", d.List.ID.String()).Msg("failed to process list reminder")
		}
	}
}

// reminderBody is the language-neutral fallback body; clients render the
// localized copy from the payload template.
func reminderBody(list models.List, openItems int) string {
	switch openItems {
	case 0:
		return list.Name
	case 1:
		return list.Name + " · 1 item left"
	default:
		return fmt.Sprintf("%s · %d items left", list.Name, openItems)
	}
}

func (r *ListReminder) sendForList(ctx context.Context, d dueListReminder, cache *groupReminderCache) error {
	list := d.List
	if list.RemindAt == nil {
		return nil
	}

	sentAt := time.Now().UTC()
	title := "List reminder"
	body := reminderBody(list, d.OpenItems)

	notifPayload := models.NotificationPayload{
		Screen:     models.ScreenListDetail,
		EntityType: models.EntityTypeList,
		ID:         list.ID.String(),
		GroupID:    list.GroupID.String(),
		EntityName: list.Name,
		DedupeKey:  "list-reminder:" + list.ID.String() + ":" + strconv.FormatInt(list.RemindAt.UTC().Unix(), 10),
		Copy: models.NewNotificationCopy(models.NotificationTemplateListReminder, map[string]string{
			"list_name":  list.Name,
			"item_count": strconv.Itoa(d.OpenItems),
		}),
	}

	if r.dispatcher != nil {
		// uuid.Nil actor: the person who set the reminder must receive it too.
		var dispatchErr error
		if reliable, ok := r.dispatcher.(ReliableNotificationDispatcher); ok {
			dispatchErr = reliable.DispatchToGroupAndWait(ctx, list.GroupID, uuid.Nil, models.NotificationTypeListReminder,
				title, body, notifPayload)
		} else {
			dispatchErr = r.dispatcher.DispatchToGroup(ctx, list.GroupID, uuid.Nil, models.NotificationTypeListReminder,
				title, body, notifPayload)
		}
		if dispatchErr != nil {
			return fmt.Errorf("dispatch list reminder: %w", dispatchErr)
		}
		ok, err := r.repo.MarkReminderSent(ctx, list.ID, sentAt)
		if err != nil {
			return fmt.Errorf("mark reminder sent: %w", err)
		}
		if ok {
			r.log.Info().
				Str("list_id", list.ID.String()).
				Time("remind_at", list.RemindAt.UTC()).
				Msg("list reminder dispatched")
		}
		return nil
	}

	// Fallback: manual batch+push (used when no dispatcher is injected).
	data, _ := json.Marshal(notifPayload)

	toDeliver := make([]models.Notification, 0, len(cache.members))
	for _, userID := range cache.members {
		pref := cache.prefs[userID]
		if pref == nil {
			pref = models.DefaultNotificationPreference(userID, list.GroupID)
		}
		if !pref.PushEnabled || !pref.PinwallReminder {
			continue
		}
		toDeliver = append(toDeliver, models.Notification{
			ID:        uuid.New(),
			UserID:    userID,
			GroupID:   list.GroupID,
			Type:      models.NotificationTypeListReminder,
			Title:     title,
			Body:      body,
			Data:      data,
			CreatedAt: sentAt,
		})
	}

	if len(toDeliver) == 0 {
		return nil
	}

	if err := r.createNotificationBatch(ctx, toDeliver); err != nil {
		return fmt.Errorf("create notifications batch: %w", err)
	}

	pushPayload := map[string]interface{}{
		"title": title,
		"body":  body,
		"data":  notifPayload,
	}
	pushBytes, _ := json.Marshal(pushPayload)
	pushStr := string(pushBytes)

	delivered := 0
	for _, n := range toDeliver {
		if r.push != nil {
			if err := r.push.SendToUser(n.UserID, pushStr); err != nil {
				r.log.Warn().Err(err).Str("user_id", n.UserID.String()).Str("list_id", list.ID.String()).Msg("failed to send reminder push")
				continue
			}
		}
		delivered++
	}

	// Only mark sent once at least one member got it, so a transient failure
	// leaves the reminder for the next tick instead of losing it.
	if delivered == 0 {
		return nil
	}

	ok, err := r.repo.MarkReminderSent(ctx, list.ID, sentAt)
	if err != nil {
		return fmt.Errorf("mark reminder sent: %w", err)
	}
	if !ok {
		return nil
	}

	r.log.Info().
		Str("list_id", list.ID.String()).
		Int("delivered", delivered).
		Time("remind_at", list.RemindAt.UTC()).
		Msg("list reminder delivered")
	return nil
}

func (r *ListReminder) createNotificationBatch(ctx context.Context, notifications []models.Notification) error {
	if idempotent, ok := r.repo.(interface {
		CreateNotificationsBatchIdempotent(context.Context, []models.Notification) error
	}); ok {
		return idempotent.CreateNotificationsBatchIdempotent(ctx, notifications)
	}
	return r.repo.CreateNotificationsBatch(ctx, notifications)
}

type listReminderRepoImpl struct {
	db repositories.DBTX
}

// ListDueReminders claims up to limit due reminders with a 5-minute lease so
// concurrent runs never double-send, and returns each list with its count of
// unchecked items for the notification body.
func (r *listReminderRepoImpl) ListDueReminders(ctx context.Context, before time.Time, limit int) ([]dueListReminder, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := r.db.Query(ctx, `
		WITH due AS (
			SELECT id
			FROM lists
			WHERE remind_at IS NOT NULL
			  AND reminder_sent_at IS NULL
			  AND archived_at IS NULL
			  AND remind_at <= $1
			  AND (reminder_claimed_at IS NULL OR reminder_claimed_at < NOW() - INTERVAL '5 minutes')
			ORDER BY remind_at ASC
			FOR UPDATE SKIP LOCKED
			LIMIT $2
		), claimed AS (
			UPDATE lists AS l
			SET reminder_claimed_at = NOW()
			FROM due
			WHERE l.id = due.id
			RETURNING l.id, l.group_id, l.name, l.type, l.remind_at, l.reminder_sent_at
		)
		SELECT c.id, c.group_id, c.name, c.type, c.remind_at, c.reminder_sent_at,
			(SELECT COUNT(*) FROM list_items li
			 WHERE li.list_id = c.id AND li.deleted_at IS NULL AND li.checked = FALSE) AS open_items
		FROM claimed c
		ORDER BY c.remind_at ASC
	`, before, limit)
	if err != nil {
		return nil, fmt.Errorf("query due list reminders: %w", err)
	}
	defer rows.Close()

	var out []dueListReminder
	for rows.Next() {
		var d dueListReminder
		if err := rows.Scan(&d.List.ID, &d.List.GroupID, &d.List.Name, &d.List.Type, &d.List.RemindAt, &d.List.ReminderSentAt, &d.OpenItems); err != nil {
			return nil, fmt.Errorf("scan due list reminder: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (r *listReminderRepoImpl) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, `SELECT user_id FROM group_memberships WHERE group_id = $1 AND left_at IS NULL`, groupID)
	if err != nil {
		return nil, fmt.Errorf("query members: %w", err)
	}
	defer rows.Close()

	var members []uuid.UUID
	for rows.Next() {
		var userID uuid.UUID
		if err := rows.Scan(&userID); err != nil {
			return nil, fmt.Errorf("scan member: %w", err)
		}
		members = append(members, userID)
	}
	return members, rows.Err()
}

func (r *listReminderRepoImpl) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	return repositories.NewNotificationRepository(r.db).GetPreferencesByGroup(ctx, groupID)
}

func (r *listReminderRepoImpl) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	return repositories.NewNotificationRepository(r.db).CreateNotificationsBatch(ctx, notifications)
}

func (r *listReminderRepoImpl) CreateNotificationsBatchIdempotent(ctx context.Context, notifications []models.Notification) error {
	return repositories.NewNotificationRepository(r.db).CreateNotificationsBatchIdempotent(ctx, notifications)
}

func (r *listReminderRepoImpl) MarkReminderSent(ctx context.Context, listID uuid.UUID, sentAt time.Time) (bool, error) {
	ct, err := r.db.Exec(ctx, `
		UPDATE lists
		SET reminder_sent_at = $2, reminder_claimed_at = NULL
		WHERE id = $1 AND reminder_sent_at IS NULL
	`, listID, sentAt)
	if err != nil {
		return false, err
	}
	return ct.RowsAffected() > 0, nil
}
