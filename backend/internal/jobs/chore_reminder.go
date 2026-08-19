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

// ChoreReminder queries pending chore assignments due within 24 hours (or
// overdue) and sends push notifications to assignees. Run daily at 09:00.
type ChoreReminder struct {
	repo       choreReminderRepo
	push       Pusher
	dispatcher NotificationDispatcher // preferred; push used as fallback
	log        *logger.Logger
}

// NewChoreReminder creates a new ChoreReminder.
func NewChoreReminder(db repositories.DBTX, push Pusher, log *logger.Logger) *ChoreReminder {
	return &ChoreReminder{repo: &choreReminderRepoImpl{db: db}, push: push, log: log}
}

// NewChoreReminderWithDispatcher creates a ChoreReminder that persists feed rows via the dispatcher.
func NewChoreReminderWithDispatcher(db repositories.DBTX, dispatcher NotificationDispatcher, log *logger.Logger) *ChoreReminder {
	return &ChoreReminder{repo: &choreReminderRepoImpl{db: db}, dispatcher: dispatcher, log: log}
}

func newChoreReminder(repo choreReminderRepo, push Pusher, log *logger.Logger) *ChoreReminder {
	return &ChoreReminder{repo: repo, push: push, log: log}
}

type pushPayload struct {
	Title string                     `json:"title"`
	Body  string                     `json:"body"`
	Data  models.NotificationPayload `json:"data"`
}

// Run executes the chore reminder job.
func (r *ChoreReminder) Run() {
	ctx := context.Background()
	r.log.Info().Msg("chore reminder job started")

	cutoff := time.Now().UTC().Add(24 * time.Hour)
	assignments, err := r.repo.ListPendingAssignmentsDueSoon(ctx, cutoff)
	if err != nil {
		r.log.Error().Err(err).Msg("failed to list pending assignments")
		return
	}

	for _, a := range assignments {
		if err := r.remindAssignment(ctx, a); err != nil {
			r.log.Error().Err(err).Str("assignment_id", a.ID.String()).Msg("failed to send chore reminder")
		}
	}
}

func (r *ChoreReminder) remindAssignment(ctx context.Context, a models.ChoreAssignment) error {
	groupID, err := r.repo.GetChoreGroupID(ctx, a.ChoreID)
	if err != nil {
		return fmt.Errorf("get chore group: %w", err)
	}

	pref, err := r.repo.GetUserPreference(ctx, a.UserID, groupID)
	if err != nil {
		r.log.Warn().Err(err).Str("user_id", a.UserID.String()).Msg("failed to load notification preference")
		// Conservative: skip push if we can't verify preferences.
		return nil
	}
	nType := models.NotificationTypeChoreDue
	title := "Chore due soon"
	bodySuffix := " is due soon"
	enabled := pref.ChoreDue
	if a.DueDate != nil {
		now := time.Now().UTC()
		tomorrow := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
		if a.DueDate.Before(tomorrow) {
			nType = models.NotificationTypeChoreDueDayOf
			title = "Chore due today"
			bodySuffix = " is due today"
			enabled = pref.ChoreDueDayOf
		}
	}
	if !enabled {
		r.log.Debug().
			Str("user_id", a.UserID.String()).
			Str("chore_id", a.ChoreID.String()).
			Msg("skipping chore reminder: user opted out")
		return r.repo.MarkReminderSent(ctx, a.ID, time.Now().UTC())
	}

	choreName, err := r.repo.GetChoreName(ctx, a.ChoreID)
	if err != nil {
		return fmt.Errorf("get chore name: %w", err)
	}

	notifPayload := models.NotificationPayload{
		Screen:     models.ScreenChoreDetail,
		EntityType: models.EntityTypeChore,
		ID:         a.ChoreID.String(),
		GroupID:    groupID.String(),
		DedupeKey:  "chore-reminder:" + a.ID.String(),
	}
	template := models.NotificationTemplateChoreDueSoon
	if nType == models.NotificationTypeChoreDueDayOf {
		template = models.NotificationTemplateChoreDueToday
	}
	notifPayload.Copy = models.NewNotificationCopy(template, map[string]string{
		"chore_name": choreName,
	})

	if r.dispatcher != nil {
		var dispatchErr error
		if reliable, ok := r.dispatcher.(ReliableNotificationDispatcher); ok {
			dispatchErr = reliable.DispatchToUsersAndWait(ctx, []uuid.UUID{a.UserID}, groupID, nType,
				title, choreName+bodySuffix, notifPayload)
		} else {
			dispatchErr = r.dispatcher.DispatchToUsers(ctx, []uuid.UUID{a.UserID}, groupID, nType,
				title, choreName+bodySuffix, notifPayload)
		}
		if dispatchErr != nil {
			err := fmt.Errorf("dispatch chore reminder: %w", dispatchErr)
			r.log.Warn().Err(err).Str("assignment_id", a.ID.String()).Msg("failed to dispatch chore reminder")
			return err
		}
		if err := r.repo.MarkReminderSent(ctx, a.ID, time.Now().UTC()); err != nil {
			return fmt.Errorf("mark reminder sent: %w", err)
		}
		r.log.Info().Str("assignment_id", a.ID.String()).Str("user_id", a.UserID.String()).Msg("chore reminder dispatched")
		return nil
	}
	if !pref.PushEnabled {
		return r.repo.MarkReminderSent(ctx, a.ID, time.Now().UTC())
	}

	pushPayload := pushPayload{
		Title: title,
		Body:  choreName + bodySuffix,
		Data:  notifPayload,
	}
	data, _ := json.Marshal(pushPayload)
	pushErr := r.push.SendToUser(a.UserID, string(data))
	if pushErr != nil {
		r.log.Warn().Err(pushErr).Str("assignment_id", a.ID.String()).Msg("failed to send chore reminder push")
	} else {
		if err := r.repo.MarkReminderSent(ctx, a.ID, time.Now().UTC()); err != nil {
			return fmt.Errorf("mark reminder sent: %w", err)
		}
		r.log.Info().Str("assignment_id", a.ID.String()).Str("user_id", a.UserID.String()).Msg("chore reminder sent")
	}
	return nil
}

type choreReminderRepoImpl struct {
	db repositories.DBTX
}

func (r *choreReminderRepoImpl) ListPendingAssignmentsDueSoon(ctx context.Context, cutoff time.Time) ([]models.ChoreAssignment, error) {
	query := `
		WITH due AS (
			SELECT id
			FROM chore_assignments
			WHERE status = 'pending'
			  AND due_date IS NOT NULL
			  AND due_date <= $1
			  AND reminder_sent_at IS NULL
			  AND (reminder_claimed_at IS NULL OR reminder_claimed_at < NOW() - INTERVAL '5 minutes')
			ORDER BY due_date ASC
			FOR UPDATE SKIP LOCKED
		), claimed AS (
			UPDATE chore_assignments AS assignment
			SET reminder_claimed_at = NOW()
			FROM due
			WHERE assignment.id = due.id
			RETURNING assignment.id, assignment.chore_id, assignment.user_id,
				assignment.status, assignment.due_date, assignment.assigned_at,
				assignment.completed_at, assignment.reminder_sent_at
		)
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, reminder_sent_at
		FROM claimed
	`
	rows, err := r.db.Query(ctx, query, cutoff)
	if err != nil {
		return nil, fmt.Errorf("query pending assignments: %w", err)
	}
	defer rows.Close()

	var assignments []models.ChoreAssignment
	for rows.Next() {
		var a models.ChoreAssignment
		if err := rows.Scan(
			&a.ID, &a.ChoreID, &a.UserID, &a.Status,
			&a.DueDate, &a.AssignedAt, &a.CompletedAt, &a.ReminderSentAt,
		); err != nil {
			return nil, fmt.Errorf("scan assignment: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return assignments, nil
}

func (r *choreReminderRepoImpl) MarkReminderSent(ctx context.Context, assignmentID uuid.UUID, sentAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		UPDATE chore_assignments
		SET reminder_sent_at = $2, reminder_claimed_at = NULL
		WHERE id = $1 AND reminder_sent_at IS NULL
	`, assignmentID, sentAt)
	return err
}

func (r *choreReminderRepoImpl) GetChoreName(ctx context.Context, choreID uuid.UUID) (string, error) {
	var name string
	err := r.db.QueryRow(ctx, `SELECT name FROM chores WHERE id = $1`, choreID).Scan(&name)
	if err != nil {
		return "", err
	}
	return name, nil
}

func (r *choreReminderRepoImpl) GetChoreGroupID(ctx context.Context, choreID uuid.UUID) (uuid.UUID, error) {
	var groupID uuid.UUID
	err := r.db.QueryRow(ctx, `SELECT group_id FROM chores WHERE id = $1`, choreID).Scan(&groupID)
	return groupID, err
}

func (r *choreReminderRepoImpl) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
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
			// Return defaults when no preference row exists.
			return models.DefaultNotificationPreference(userID, groupID), nil
		}
		return nil, err
	}
	return &p, nil
}
