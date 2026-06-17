package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// PinwallReminder sends one-time reminders for pinwall posts with remind_at set.
// Runs every minute.
type PinwallReminder struct {
	repo  pinwallReminderRepo
	log   *logger.Logger
	push  Pusher
}

func NewPinwallReminder(db repositories.DBTX, push Pusher, log *logger.Logger) *PinwallReminder {
	repo := &pinwallReminderRepoImpl{db: db}
	return &PinwallReminder{repo: repo, log: log, push: push}
}

type pinwallReminderRepo interface {
	ListDueReminders(ctx context.Context, before time.Time, limit int) ([]models.PinwallPost, error)
	ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error)
	GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
	GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error)
	CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error
	MarkReminderSent(ctx context.Context, postID uuid.UUID, sentAt time.Time) (bool, error)
}

type groupReminderCache struct {
	members []uuid.UUID
	prefs   map[uuid.UUID]*models.NotificationPreference
}

func (r *PinwallReminder) Run() {
	ctx := context.Background()
	now := time.Now().UTC()
	r.log.Info().Time("now", now).Msg("pinwall reminder job started")

	posts, err := r.repo.ListDueReminders(ctx, now, 200)
	if err != nil {
		r.log.Error().Err(err).Msg("failed to list due pinwall reminders")
		return
	}
	if len(posts) == 0 {
		return
	}

	groupCache := make(map[uuid.UUID]*groupReminderCache)
	for _, p := range posts {
		cache, ok := groupCache[p.GroupID]
		if !ok {
			members, err := r.repo.ListGroupMembers(ctx, p.GroupID)
			if err != nil {
				r.log.Warn().Err(err).Str("group_id", p.GroupID.String()).Msg("failed to list group members")
				continue
			}
			prefs, err := r.repo.GetPreferencesByGroup(ctx, p.GroupID)
			if err != nil {
				r.log.Warn().Err(err).Str("group_id", p.GroupID.String()).Msg("failed to load group preferences")
				prefs = map[uuid.UUID]*models.NotificationPreference{}
			}
			cache = &groupReminderCache{members: members, prefs: prefs}
			groupCache[p.GroupID] = cache
		}
		if err := r.sendForPost(ctx, p, cache); err != nil {
			r.log.Warn().Err(err).Str("post_id", p.ID.String()).Msg("failed to process pinwall reminder")
		}
	}
}

func (r *PinwallReminder) sendForPost(ctx context.Context, post models.PinwallPost, cache *groupReminderCache) error {
	// Guard: remind_at must exist; DB query should enforce this.
	if post.RemindAt == nil {
		return nil
	}

	sentAt := time.Now().UTC()

	payload := models.NotificationPayload{
		Screen:     models.ScreenHouseholdHub,
		EntityType: models.EntityTypePinwallPost,
		ID:         post.ID.String(),
		GroupID:    post.GroupID.String(),
	}
	data, _ := json.Marshal(payload)

	defaultPref := func(userID uuid.UUID) *models.NotificationPreference {
		return models.DefaultNotificationPreference(userID, post.GroupID)
	}

	toDeliver := make([]models.Notification, 0, len(cache.members))
	for _, userID := range cache.members {
		if userID == post.UserID {
			continue
		}
		pref := cache.prefs[userID]
		if pref == nil {
			pref = defaultPref(userID)
		}
		if !pref.PushEnabled || !pref.PinwallReminder {
			continue
		}
		toDeliver = append(toDeliver, models.Notification{
			ID:        uuid.New(),
			UserID:    userID,
			GroupID:   post.GroupID,
			Type:      "pinwall_reminder",
			Title:     "Reminder",
			Body:      post.Content,
			Data:      data,
			CreatedAt: sentAt,
		})
	}

	if len(toDeliver) == 0 {
		return nil
	}

	if err := r.repo.CreateNotificationsBatch(ctx, toDeliver); err != nil {
		return fmt.Errorf("create notifications batch: %w", err)
	}

	pushPayload := map[string]interface{}{
		"title": "Reminder",
		"body":  post.Content,
		"data":  payload,
	}
	pushBytes, _ := json.Marshal(pushPayload)
	pushStr := string(pushBytes)

	delivered := 0
	for _, n := range toDeliver {
		if r.push != nil {
			if err := r.push.SendToUser(n.UserID, pushStr); err != nil {
				r.log.Warn().Err(err).Str("user_id", n.UserID.String()).Str("post_id", post.ID.String()).Msg("failed to send reminder push")
				continue
			}
		}
		delivered++
	}

	// Only mark sent if we delivered to at least one member. This avoids losing a
	// reminder entirely in the (rare) case that preference lookups fail.
	if delivered == 0 {
		return nil
	}

	ok, err := r.repo.MarkReminderSent(ctx, post.ID, sentAt)
	if err != nil {
		return fmt.Errorf("mark reminder sent: %w", err)
	}
	if !ok {
		return nil
	}

	r.log.Info().
		Str("post_id", post.ID.String()).
		Int("delivered", delivered).
		Time("remind_at", post.RemindAt.UTC()).
		Msg("pinwall reminder delivered")
	return nil
}

type pinwallReminderRepoImpl struct {
	db repositories.DBTX
}

func (r *pinwallReminderRepoImpl) ListDueReminders(ctx context.Context, before time.Time, limit int) ([]models.PinwallPost, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, group_id, user_id, content, created_at, remind_at, reminder_sent_at
		FROM pinwall_posts
		WHERE remind_at IS NOT NULL
		  AND reminder_sent_at IS NULL
		  AND remind_at <= $1
		ORDER BY remind_at ASC
		LIMIT $2
	`, before, limit)
	if err != nil {
		return nil, fmt.Errorf("query due reminders: %w", err)
	}
	defer rows.Close()

	var out []models.PinwallPost
	for rows.Next() {
		var p models.PinwallPost
		if err := rows.Scan(&p.ID, &p.GroupID, &p.UserID, &p.Content, &p.CreatedAt, &p.RemindAt, &p.ReminderSentAt); err != nil {
			return nil, fmt.Errorf("scan due reminder: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *pinwallReminderRepoImpl) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, `SELECT user_id FROM group_memberships WHERE group_id = $1`, groupID)
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

func (r *pinwallReminderRepoImpl) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	var p models.NotificationPreference
	err := r.db.QueryRow(ctx, `
		SELECT id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, pinwall_reminder, push_enabled, created_at, updated_at
		FROM notification_preferences
		WHERE user_id = $1 AND group_id = $2
	`, userID, groupID).Scan(
		&p.ID, &p.UserID, &p.GroupID, &p.ChoreDue, &p.ChoreDueDayOf, &p.ListItemAdded,
		&p.ExpenseCreated, &p.MealPlanChanged, &p.WeeklyDigest, &p.PinwallReminder, &p.PushEnabled,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return models.DefaultNotificationPreference(userID, groupID), nil
		}
		return nil, err
	}
	return &p, nil
}

func (r *pinwallReminderRepoImpl) GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error) {
	repo := repositories.NewNotificationRepository(r.db)
	return repo.GetPreferencesByGroup(ctx, groupID)
}

func (r *pinwallReminderRepoImpl) CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error {
	repo := repositories.NewNotificationRepository(r.db)
	return repo.CreateNotificationsBatch(ctx, notifications)
}

func (r *pinwallReminderRepoImpl) MarkReminderSent(ctx context.Context, postID uuid.UUID, sentAt time.Time) (bool, error) {
	ct, err := r.db.Exec(ctx, `
		UPDATE pinwall_posts
		SET reminder_sent_at = $2
		WHERE id = $1 AND reminder_sent_at IS NULL
	`, postID, sentAt)
	if err != nil {
		return false, err
	}
	return ct.RowsAffected() > 0, nil
}

