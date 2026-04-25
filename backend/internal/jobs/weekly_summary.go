package jobs

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/pkg/logger"
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

		if err := s.notifyAdmins(ctx, act.GroupID, act.Count); err != nil {
			s.log.Error().Err(err).Str("group_id", act.GroupID.String()).Msg("failed to notify admins")
		}
	}
}

func (s *WeeklySummary) notifyAdmins(ctx context.Context, groupID uuid.UUID, count int) error {
	admins, err := s.repo.ListGroupAdmins(ctx, groupID)
	if err != nil {
		return fmt.Errorf("query admins: %w", err)
	}

	payload := fmt.Sprintf(`{"title":"Weekly Summary","body":"Your group had %d activities this week"}`, count)
	for _, userID := range admins {
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
		SELECT group_id, COUNT(*) as count
		FROM activity_logs
		WHERE created_at >= $1
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

func (r *weeklySummaryRepoImpl) ListGroupAdmins(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT user_id FROM group_memberships WHERE group_id = $1 AND role = 'admin'
	`, groupID)
	if err != nil {
		return nil, fmt.Errorf("query admins: %w", err)
	}
	defer rows.Close()

	var admins []uuid.UUID
	for rows.Next() {
		var userID uuid.UUID
		if err := rows.Scan(&userID); err != nil {
			return nil, fmt.Errorf("scan admin: %w", err)
		}
		admins = append(admins, userID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return admins, nil
}
