package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/choreschedule"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// ChoreScheduler queries active scheduled chores and creates assignments
// using deterministic member rotation. Run daily at 00:01.
type ChoreScheduler struct {
	repo choreSchedulerRepo
	log  *logger.Logger
}

// NewChoreScheduler creates a new ChoreScheduler.
func NewChoreScheduler(db repositories.DBTX, log *logger.Logger) *ChoreScheduler {
	return &ChoreScheduler{repo: &choreSchedulerRepoImpl{db: db}, log: log}
}

func newChoreScheduler(repo choreSchedulerRepo, log *logger.Logger) *ChoreScheduler {
	return &ChoreScheduler{repo: repo, log: log}
}

// Run executes the chore scheduling job.
func (s *ChoreScheduler) Run() {
	ctx := context.Background()
	s.log.Info().Msg("chore scheduler started")

	chores, err := s.repo.ListActiveScheduledChores(ctx)
	if err != nil {
		s.log.Error().Err(err).Msg("failed to list active scheduled chores")
		return
	}

	for _, chore := range chores {
		if err := s.scheduleChore(ctx, chore); err != nil {
			s.log.Error().Err(err).Str("chore_id", chore.ID.String()).Msg("failed to schedule chore")
		}
	}
}

func (s *ChoreScheduler) scheduleChore(ctx context.Context, chore models.Chore) error {
	state, err := s.repo.GetRotationState(ctx, chore.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			s.log.Warn().Str("chore_id", chore.ID.String()).Msg("no rotation state found, skipping")
			return nil
		}
		return fmt.Errorf("get rotation state: %w", err)
	}

	if chore.AssignmentType == "no-assignment" {
		s.log.Info().Str("chore_id", chore.ID.String()).Msg("unassigned chore, skipping assignment creation")
		return nil
	}

	if len(state.MemberOrder) == 0 {
		s.log.Warn().Str("chore_id", chore.ID.String()).Msg("empty member order, skipping")
		return nil
	}

	if state.CurrentIndex < 0 || state.CurrentIndex >= len(state.MemberOrder) {
		s.log.Warn().
			Str("chore_id", chore.ID.String()).
			Int("current_index", state.CurrentIndex).
			Int("member_count", len(state.MemberOrder)).
			Msg("invalid rotation state, repairing")
		state.CurrentIndex = 0
	}

	assigneeID := state.MemberOrder[state.CurrentIndex]
	now := time.Now().UTC()

	assignment := models.ChoreAssignment{
		ID:      uuid.New(),
		ChoreID: chore.ID,
		UserID:  assigneeID,
		Status:  "pending",
		DueDate: choreschedule.NextDueForRule(now, choreschedule.Rule{
			Frequency:     chore.Frequency,
			Interval:      chore.PeriodInterval,
			PeriodConfig:  chore.PeriodConfig,
			StartDate:     chore.StartDate,
			TrackDateOnly: chore.TrackDateOnly,
			Rollover:      chore.Rollover,
		}),
		AssignedAt: now,
	}

	nextIndex := (state.CurrentIndex + 1) % len(state.MemberOrder)
	if err := s.repo.ScheduleChore(ctx, &assignment, state.ID, nextIndex); err != nil {
		return fmt.Errorf("schedule chore: %w", err)
	}

	s.log.Info().
		Str("chore_id", chore.ID.String()).
		Str("assignee_id", assigneeID.String()).
		Int("next_index", nextIndex).
		Msg("chore scheduled")
	return nil
}

type choreSchedulerRepoImpl struct {
	db repositories.DBTX
}

func (r *choreSchedulerRepoImpl) ListActiveScheduledChores(ctx context.Context) ([]models.Chore, error) {
	query := `
		SELECT id, group_id, name, description, rotation_type, frequency,
			period_interval, period_config, start_date, track_date_only, rollover,
			assignment_type, assignment_config, is_active, created_at, updated_at
		FROM chores
		WHERE is_active = true
		  AND frequency <> 'none'
		  AND NOT EXISTS (
			SELECT 1
			FROM chore_assignments
			WHERE chore_assignments.chore_id = chores.id
			  AND chore_assignments.status = 'pending'
		  )
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query active scheduled chores: %w", err)
	}
	defer rows.Close()

	var chores []models.Chore
	for rows.Next() {
		var c models.Chore
		if err := rows.Scan(
			&c.ID, &c.GroupID, &c.Name, &c.Description,
			&c.RotationType, &c.Frequency, &c.PeriodInterval, &c.PeriodConfig,
			&c.StartDate, &c.TrackDateOnly, &c.Rollover, &c.AssignmentType,
			&c.AssignmentConfig, &c.IsActive,
			&c.CreatedAt, &c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan chore: %w", err)
		}
		chores = append(chores, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return chores, nil
}

func (r *choreSchedulerRepoImpl) GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error) {
	var state models.ChoreRotationState
	err := r.db.QueryRow(ctx, `
		SELECT id, chore_id, member_order, current_index
		FROM chore_rotation_states
		WHERE chore_id = $1
	`, choreID).Scan(&state.ID, &state.ChoreID, &state.MemberOrder, &state.CurrentIndex)
	if err != nil {
		return nil, err
	}
	return &state, nil
}

func (r *choreSchedulerRepoImpl) ScheduleChore(ctx context.Context, assignment *models.ChoreAssignment, stateID uuid.UUID, nextIndex int) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO chore_assignments (id, chore_id, user_id, status, due_date, assigned_at, completed_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, assignment.ID, assignment.ChoreID, assignment.UserID, assignment.Status, assignment.DueDate, assignment.AssignedAt, assignment.CompletedAt)
	if err != nil {
		return fmt.Errorf("create assignment: %w", err)
	}

	_, err = tx.Exec(ctx, `
		UPDATE chore_rotation_states
		SET current_index = $1
		WHERE id = $2
	`, nextIndex, stateID)
	if err != nil {
		return fmt.Errorf("update rotation state: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}
	return nil
}
