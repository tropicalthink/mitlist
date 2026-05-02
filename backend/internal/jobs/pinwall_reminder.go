package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// PinwallReminder sends one-time reminders for pinwall posts with remind_at set.
// Runs every minute.
type PinwallReminder struct {
	repo pinwallReminderRepo
	log  *logger.Logger
	notif *services.NotificationService
}

func NewPinwallReminder(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *PinwallReminder {
	repo := &pinwallReminderRepoImpl{pool: pool}
	notificationRepo := repositories.NewNotificationRepository(pool)
	pushSvc := pushAdapter{push: push}
	notif := services.NewNotificationService(notificationRepo, nil, pushSvc)
	return &PinwallReminder{repo: repo, log: log, notif: notif}
}

type pushAdapter struct {
	push Pusher
}

func (a pushAdapter) SendToUser(userID uuid.UUID, payload string) error {
	return a.push.SendToUser(userID, payload)
}

func (a pushAdapter) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	return a.push.BroadcastToGroup(groupID, payload)
}

type pinwallReminderRepo interface {
	ListDueReminders(ctx context.Context, before time.Time, limit int) ([]models.PinwallPost, error)
	ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error)
	GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
	MarkReminderSent(ctx context.Context, postID uuid.UUID, sentAt time.Time) (bool, error)
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

	for _, p := range posts {
		if err := r.sendForPost(ctx, p); err != nil {
			r.log.Warn().Err(err).Str("post_id", p.ID.String()).Msg("failed to process pinwall reminder")
		}
	}
}

func (r *PinwallReminder) sendForPost(ctx context.Context, post models.PinwallPost) error {
	// Guard: remind_at must exist; DB query should enforce this.
	if post.RemindAt == nil {
		return nil
	}

	members, err := r.repo.ListGroupMembers(ctx, post.GroupID)
	if err != nil {
		return fmt.Errorf("list group members: %w", err)
	}

	sentAt := time.Now().UTC()

	payload := models.NotificationPayload{
		Screen:     models.ScreenHouseholdHub,
		EntityType: models.EntityTypePinwallPost,
		ID:         post.ID.String(),
		GroupID:    post.GroupID.String(),
	}
	data, _ := json.Marshal(payload)

	delivered := 0
	for _, userID := range members {
		// UX choice: don't push the author; they already set the reminder time.
		if userID == post.UserID {
			continue
		}

		pref, err := r.repo.GetUserPreference(ctx, userID, post.GroupID)
		if err != nil {
			// Conservative: skip if we can't verify preferences.
			continue
		}
		if !pref.PushEnabled || !pref.PinwallReminder {
			continue
		}

		n := &models.Notification{
			UserID:  userID,
			GroupID: post.GroupID,
			Type:    "pinwall_reminder",
			Title:   "Reminder",
			Body:    post.Content,
			Data:    data,
		}
		if err := r.notif.CreateNotification(ctx, n); err != nil {
			r.log.Warn().Err(err).Str("user_id", userID.String()).Str("post_id", post.ID.String()).Msg("failed to create reminder notification")
			continue
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
	pool *pgxpool.Pool
}

func (r *pinwallReminderRepoImpl) ListDueReminders(ctx context.Context, before time.Time, limit int) ([]models.PinwallPost, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := r.pool.Query(ctx, `
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
	rows, err := r.pool.Query(ctx, `SELECT user_id FROM group_memberships WHERE group_id = $1`, groupID)
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
	err := r.pool.QueryRow(ctx, `
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
			return &models.NotificationPreference{
				UserID:          userID,
				GroupID:         groupID,
				ChoreDue:        true,
				ChoreDueDayOf:   true,
				ListItemAdded:   true,
				ExpenseCreated:  true,
				MealPlanChanged: true,
				WeeklyDigest:    true,
				PinwallReminder: true,
				PushEnabled:     true,
			}, nil
		}
		return nil, err
	}
	return &p, nil
}

func (r *pinwallReminderRepoImpl) MarkReminderSent(ctx context.Context, postID uuid.UUID, sentAt time.Time) (bool, error) {
	ct, err := r.pool.Exec(ctx, `
		UPDATE pinwall_posts
		SET reminder_sent_at = $2
		WHERE id = $1 AND reminder_sent_at IS NULL
	`, postID, sentAt)
	if err != nil {
		return false, err
	}
	return ct.RowsAffected() > 0, nil
}

