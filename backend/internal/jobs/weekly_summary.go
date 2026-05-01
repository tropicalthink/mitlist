package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// WeeklySummary aggregates activity for the past week and sends a summary push
// to group admins. Disabled by default.
type WeeklySummary struct {
	repo weeklySummaryRepo
	push Pusher
	log  *logger.Logger
}

// NewWeeklySummary creates a new WeeklySummary job.
func NewWeeklySummary(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *WeeklySummary {
	return &WeeklySummary{repo: &weeklySummaryRepoImpl{pool: pool}, push: push, log: log}
}

func newWeeklySummary(repo weeklySummaryRepo, push Pusher, log *logger.Logger) *WeeklySummary {
	return &WeeklySummary{repo: repo, push: push, log: log}
}

// Run executes the weekly summary job.
func (s *WeeklySummary) Run() {
	ctx := context.Background()
	s.log.Info().Msg("weekly summary job started")

	since := time.Now().UTC().Add(-7 * 24 * time.Hour)

	activities, err := s.repo.ListWeeklyActivity(ctx, since)
	if err != nil {
		s.log.Error().Err(err).Msg("failed to query weekly activity")
		return
	}

	for _, act := range activities {
		s.log.Info().
			Str("group_id", act.GroupID.String()).
			Int("activity_count", act.Count).
			Msg("weekly activity summary")

		if err := s.notifyMembers(ctx, act.GroupID, act.Count); err != nil {
			s.log.Error().Err(err).Str("group_id", act.GroupID.String()).Msg("failed to notify members")
		}
	}
}

func (s *WeeklySummary) notifyMembers(ctx context.Context, groupID uuid.UUID, count int) error {
	members, err := s.repo.ListGroupMembers(ctx, groupID)
	if err != nil {
		return fmt.Errorf("query members: %w", err)
	}

	payload := fmt.Sprintf(`{"title":"Weekly Summary","body":"Your household had %d activities this week"}`, count)

	for _, userID := range members {
		pref, err := s.repo.GetUserPreference(ctx, userID, groupID)
		if err != nil {
			s.log.Warn().Err(err).Str("user_id", userID.String()).Msg("failed to load preference")
			continue
		}
		if !pref.PushEnabled || !pref.WeeklyDigest {
			s.log.Debug().
				Str("user_id", userID.String()).
				Str("group_id", groupID.String()).
				Msg("skipping weekly digest: user opted out")
			continue
		}

		if err := s.push.SendToUser(userID, payload); err != nil {
			s.log.Warn().Err(err).Str("user_id", userID.String()).Msg("failed to send weekly summary push")
		}
	}
	return nil
}

type weeklySummaryRepoImpl struct {
	pool *pgxpool.Pool
}

func (r *weeklySummaryRepoImpl) ListWeeklyActivity(ctx context.Context, since time.Time) ([]groupActivity, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT group_id, COUNT(*) as count FROM (
			SELECT l.group_id FROM list_items li JOIN lists l ON l.id = li.list_id WHERE li.created_at >= $1
			UNION ALL
			SELECT group_id FROM expenses WHERE created_at >= $1
			UNION ALL
			SELECT ch.group_id FROM chore_completions cc JOIN chore_assignments ca ON ca.id = cc.assignment_id JOIN chores ch ON ch.id = ca.chore_id WHERE cc.completed_at >= $1
			UNION ALL
			SELECT group_id FROM meal_plans WHERE created_at >= $1
			UNION ALL
			SELECT gm.group_id
			FROM recipes rcp
			JOIN group_memberships gm ON gm.user_id = rcp.user_id
			WHERE rcp.created_at >= $1
		) events
		GROUP BY group_id
	`, since)
	if err != nil {
		return nil, fmt.Errorf("query weekly activity: %w", err)
	}
	defer rows.Close()

	var activities []groupActivity
	for rows.Next() {
		var ga groupActivity
		if err := rows.Scan(&ga.GroupID, &ga.Count); err != nil {
			return nil, fmt.Errorf("scan activity: %w", err)
		}
		activities = append(activities, ga)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return activities, nil
}

func (r *weeklySummaryRepoImpl) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT user_id FROM group_memberships WHERE group_id = $1
	`, groupID)
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
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return members, nil
}

func (r *weeklySummaryRepoImpl) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
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
