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
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// ChoreReminder queries pending chore assignments due within 24 hours (or
// overdue) and sends push notifications to assignees. Run daily at 09:00.
type ChoreReminder struct {
	repo choreReminderRepo
	push Pusher
	log  *logger.Logger
}

// NewChoreReminder creates a new ChoreReminder.
func NewChoreReminder(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *ChoreReminder {
	return &ChoreReminder{repo: &choreReminderRepoImpl{pool: pool}, push: push, log: log}
}

func newChoreReminder(repo choreReminderRepo, push Pusher, log *logger.Logger) *ChoreReminder {
	return &ChoreReminder{repo: repo, push: push, log: log}
}

type pushPayload struct {
	Title string `json:"title"`
	Body  string `json:"body"`
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
	if !pref.PushEnabled || !pref.ChoreDue {
		r.log.Debug().
			Str("user_id", a.UserID.String()).
			Str("chore_id", a.ChoreID.String()).
			Msg("skipping chore reminder: user opted out")
		return nil
	}

	choreName, err := r.repo.GetChoreName(ctx, a.ChoreID)
	if err != nil {
		return fmt.Errorf("get chore name: %w", err)
	}

	pushPayload := pushPayload{Title: "Chore Reminder", Body: choreName + " is due soon"}
	data, _ := json.Marshal(pushPayload)
	pushErr := r.push.SendToUser(a.UserID, string(data))
	if pushErr != nil {
		r.log.Warn().Err(pushErr).Str("assignment_id", a.ID.String()).Msg("failed to send chore reminder push")
	} else {
		r.log.Info().Str("assignment_id", a.ID.String()).Str("user_id", a.UserID.String()).Msg("chore reminder sent")
	}
	return nil
}

type choreReminderRepoImpl struct {
	pool *pgxpool.Pool
}

func (r *choreReminderRepoImpl) ListPendingAssignmentsDueSoon(ctx context.Context, cutoff time.Time) ([]models.ChoreAssignment, error) {
	query := `
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at
		FROM chore_assignments
		WHERE status = 'pending' AND (due_date IS NULL OR due_date <= $1)
	`
	rows, err := r.pool.Query(ctx, query, cutoff)
	if err != nil {
		return nil, fmt.Errorf("query pending assignments: %w", err)
	}
	defer rows.Close()

	var assignments []models.ChoreAssignment
	for rows.Next() {
		var a models.ChoreAssignment
		if err := rows.Scan(
			&a.ID, &a.ChoreID, &a.UserID, &a.Status,
			&a.DueDate, &a.AssignedAt, &a.CompletedAt,
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

func (r *choreReminderRepoImpl) GetChoreName(ctx context.Context, choreID uuid.UUID) (string, error) {
	var name string
	err := r.pool.QueryRow(ctx, `SELECT name FROM chores WHERE id = $1`, choreID).Scan(&name)
	if err != nil {
		return "", err
	}
	return name, nil
}

func (r *choreReminderRepoImpl) GetChoreGroupID(ctx context.Context, choreID uuid.UUID) (uuid.UUID, error) {
	var groupID uuid.UUID
	err := r.pool.QueryRow(ctx, `SELECT group_id FROM chores WHERE id = $1`, choreID).Scan(&groupID)
	return groupID, err
}

func (r *choreReminderRepoImpl) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	var p models.NotificationPreference
	err := r.pool.QueryRow(ctx, `
		SELECT id, user_id, group_id, chore_due, chore_due_day_of, list_item_added,
			expense_created, meal_plan_changed, weekly_digest, push_enabled, created_at, updated_at
		FROM notification_preferences
		WHERE user_id = $1 AND group_id = $2
	`, userID, groupID).Scan(
		&p.ID, &p.UserID, &p.GroupID, &p.ChoreDue, &p.ChoreDueDayOf, &p.ListItemAdded,
		&p.ExpenseCreated, &p.MealPlanChanged, &p.WeeklyDigest, &p.PushEnabled,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Return defaults when no preference row exists.
			return &models.NotificationPreference{
				UserID:          userID,
				GroupID:         groupID,
				ChoreDue:        true,
				ChoreDueDayOf:   true,
				ListItemAdded:   true,
				ExpenseCreated:  true,
				MealPlanChanged: true,
				WeeklyDigest:    true,
				PushEnabled:     true,
			}, nil
		}
		return nil, err
	}
	return &p, nil
}
