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

// ChoreRepository handles chore persistence.
type ChoreRepository struct {
	pool DBTX
}

// NewChoreRepository creates a new ChoreRepository.
func NewChoreRepository(pool DBTX) *ChoreRepository {
	return &ChoreRepository{pool: pool}
}

// CreateChore inserts a new chore.
func (r *ChoreRepository) CreateChore(ctx context.Context, chore *models.Chore) error {
	chore.ID = uuid.New()
	query := `
		INSERT INTO chores (
			id, group_id, name, description, rotation_type, frequency,
			period_interval, period_config, start_date, track_date_only, rollover,
			assignment_type, assignment_config, is_active, supplies, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query,
		chore.ID, chore.GroupID, chore.Name, chore.Description,
		chore.RotationType, chore.Frequency, chore.PeriodInterval, chore.PeriodConfig,
		chore.StartDate, chore.TrackDateOnly, chore.Rollover, chore.AssignmentType,
		chore.AssignmentConfig, chore.IsActive, chore.Supplies,
	).Scan(&chore.CreatedAt, &chore.UpdatedAt)
}

// GetChoreByID retrieves a chore by ID.
func (r *ChoreRepository) GetChoreByID(ctx context.Context, id uuid.UUID) (*models.Chore, error) {
	query := `
		SELECT id, group_id, name, description, rotation_type, frequency,
			period_interval, period_config, start_date, track_date_only, rollover,
			assignment_type, assignment_config, is_active, supplies, created_at, updated_at
		FROM chores
		WHERE id = $1
	`
	var c models.Chore
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&c.ID, &c.GroupID, &c.Name, &c.Description,
		&c.RotationType, &c.Frequency, &c.PeriodInterval, &c.PeriodConfig,
		&c.StartDate, &c.TrackDateOnly, &c.Rollover, &c.AssignmentType,
		&c.AssignmentConfig, &c.IsActive, &c.Supplies,
		&c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("chore not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	return &c, nil
}

// ListChoresByGroup retrieves chores for a group with pagination.
func (r *ChoreRepository) ListChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Chore, error) {
	query := `
		SELECT id, group_id, name, description, rotation_type, frequency,
			period_interval, period_config, start_date, track_date_only, rollover,
			assignment_type, assignment_config, is_active, supplies, created_at, updated_at
		FROM chores
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	limit = clampLimit(limit)
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list chores: %w", err)
	}
	defer rows.Close()

	var chores []models.Chore
	for rows.Next() {
		var c models.Chore
		if err := rows.Scan(
			&c.ID, &c.GroupID, &c.Name, &c.Description,
			&c.RotationType, &c.Frequency, &c.PeriodInterval, &c.PeriodConfig,
			&c.StartDate, &c.TrackDateOnly, &c.Rollover, &c.AssignmentType,
			&c.AssignmentConfig, &c.IsActive, &c.Supplies,
			&c.CreatedAt, &c.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan chore: %w", err)
		}
		chores = append(chores, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("chore rows error: %w", err)
	}
	return chores, nil
}

// ListCurrentChoresByGroup returns chores with their latest pending and last finished assignment.
func (r *ChoreRepository) ListCurrentChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.CurrentChore, error) {
	query := `
		SELECT
			c.id, c.group_id, c.name, c.description, c.rotation_type, c.frequency,
			c.period_interval, c.period_config, c.start_date, c.track_date_only, c.rollover,
			c.assignment_type, c.assignment_config, c.is_active, c.created_at, c.updated_at,
			pa.id, pa.chore_id, pa.user_id, pa.status, pa.due_date, pa.assigned_at, pa.completed_at, pa.skip_reason,
			la.id, la.chore_id, la.user_id, la.status, la.due_date, la.assigned_at, la.completed_at, la.skip_reason
		FROM chores c
		LEFT JOIN LATERAL (
			SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason
			FROM chore_assignments
			WHERE chore_id = c.id AND status = 'pending'
			ORDER BY assigned_at DESC, id DESC
			LIMIT 1
		) pa ON true
		LEFT JOIN LATERAL (
			SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason
			FROM chore_assignments
			WHERE chore_id = c.id AND status <> 'pending'
			ORDER BY completed_at DESC NULLS LAST, assigned_at DESC, id DESC
			LIMIT 1
		) la ON true
		WHERE c.group_id = $1
		ORDER BY pa.due_date ASC NULLS LAST, c.name ASC, c.id ASC
		LIMIT $2 OFFSET $3
	`
	limit = clampLimit(limit)
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list current chores: %w", err)
	}
	defer rows.Close()

	var current []models.CurrentChore
	for rows.Next() {
		var item models.CurrentChore
		var pending nullableAssignment
		var last nullableAssignment
		if err := rows.Scan(
			&item.Chore.ID, &item.Chore.GroupID, &item.Chore.Name, &item.Chore.Description,
			&item.Chore.RotationType, &item.Chore.Frequency, &item.Chore.PeriodInterval,
			&item.Chore.PeriodConfig, &item.Chore.StartDate, &item.Chore.TrackDateOnly,
			&item.Chore.Rollover, &item.Chore.AssignmentType, &item.Chore.AssignmentConfig,
			&item.Chore.IsActive,
			&item.Chore.CreatedAt, &item.Chore.UpdatedAt,
			&pending.ID, &pending.ChoreID, &pending.UserID, &pending.Status, &pending.DueDate, &pending.AssignedAt, &pending.CompletedAt, &pending.SkipReason,
			&last.ID, &last.ChoreID, &last.UserID, &last.Status, &last.DueDate, &last.AssignedAt, &last.CompletedAt, &last.SkipReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan current chore: %w", err)
		}
		item.PendingAssignment = pending.assignment()
		item.LastAssignment = last.assignment()
		current = append(current, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("current chore rows error: %w", err)
	}
	return current, nil
}

// GetChoreStats returns tracked execution count, last execution, and average spacing.
func (r *ChoreRepository) GetChoreStats(ctx context.Context, choreID uuid.UUID) (*models.ChoreStats, error) {
	query := `
		WITH completions AS (
			SELECT cc.completed_at, cc.completed_by
			FROM chore_completions cc
			INNER JOIN chore_assignments ca ON ca.id = cc.assignment_id
			WHERE ca.chore_id = $1
		),
		ordered AS (
			SELECT
				completed_at,
				completed_by,
				LAG(completed_at) OVER (ORDER BY completed_at ASC, completed_by ASC) AS previous_completed_at
			FROM completions
		),
		rollup AS (
			SELECT
				COUNT(*)::INTEGER AS tracked_count,
				MAX(completed_at) AS last_tracked_at,
				AVG(EXTRACT(EPOCH FROM (completed_at - previous_completed_at)) / 3600.0)
					FILTER (WHERE previous_completed_at IS NOT NULL) AS average_frequency_hours
			FROM ordered
		)
		SELECT
			rollup.tracked_count,
			rollup.last_tracked_at,
			(
				SELECT completed_by
				FROM completions
				ORDER BY completed_at DESC, completed_by ASC
				LIMIT 1
			) AS last_done_by_user_id,
			rollup.average_frequency_hours
		FROM rollup
	`
	var stats models.ChoreStats
	err := r.pool.QueryRow(ctx, query, choreID).Scan(
		&stats.TrackedCount,
		&stats.LastTrackedAt,
		&stats.LastDoneByUserID,
		&stats.AverageFrequencyHours,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get chore stats: %w", err)
	}
	return &stats, nil
}

type nullableAssignment struct {
	ID          *uuid.UUID
	ChoreID     *uuid.UUID
	UserID      *uuid.UUID
	Status      *string
	DueDate     *time.Time
	AssignedAt  *time.Time
	CompletedAt *time.Time
	SkipReason  *string
}

func (a nullableAssignment) assignment() *models.ChoreAssignment {
	if a.ID == nil || a.ChoreID == nil || a.UserID == nil || a.Status == nil || a.AssignedAt == nil {
		return nil
	}
	return &models.ChoreAssignment{
		ID:          *a.ID,
		ChoreID:     *a.ChoreID,
		UserID:      *a.UserID,
		Status:      *a.Status,
		DueDate:     a.DueDate,
		AssignedAt:  *a.AssignedAt,
		CompletedAt: a.CompletedAt,
		SkipReason:  a.SkipReason,
	}
}

// UpdateChore updates a chore.
func (r *ChoreRepository) UpdateChore(ctx context.Context, chore *models.Chore) error {
	query := `
		UPDATE chores
		SET name = $1, description = $2, rotation_type = $3, frequency = $4,
			period_interval = $5, period_config = $6, start_date = $7,
			track_date_only = $8, rollover = $9, assignment_type = $10,
			assignment_config = $11, is_active = $12, supplies = $13, updated_at = NOW()
		WHERE id = $14
		RETURNING updated_at
	`
	err := r.pool.QueryRow(ctx, query,
		chore.Name, chore.Description, chore.RotationType,
		chore.Frequency, chore.PeriodInterval, chore.PeriodConfig, chore.StartDate,
		chore.TrackDateOnly, chore.Rollover, chore.AssignmentType,
		chore.AssignmentConfig, chore.IsActive, chore.Supplies, chore.ID,
	).Scan(&chore.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("chore not found: %w", err)
		}
		return fmt.Errorf("failed to update chore: %w", err)
	}
	return nil
}

// DeleteChore deletes a chore by ID.
func (r *ChoreRepository) DeleteChore(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM chores WHERE id = $1`
	tag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete chore: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("chore not found")
	}
	return nil
}

// CreateRotationState inserts a new rotation state for a chore.
func (r *ChoreRepository) CreateRotationState(ctx context.Context, state *models.ChoreRotationState) error {
	state.ID = uuid.New()
	query := `
		INSERT INTO chore_rotation_states (id, chore_id, member_order, current_index)
		VALUES ($1, $2, $3, $4)
	`
	_, err := r.pool.Exec(ctx, query, state.ID, state.ChoreID, state.MemberOrder, state.CurrentIndex)
	if err != nil {
		return fmt.Errorf("failed to create rotation state: %w", err)
	}
	return nil
}

// GetRotationState retrieves the rotation state for a chore.
func (r *ChoreRepository) GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error) {
	query := `
		SELECT id, chore_id, member_order, current_index
		FROM chore_rotation_states
		WHERE chore_id = $1
	`
	var s models.ChoreRotationState
	err := r.pool.QueryRow(ctx, query, choreID).Scan(&s.ID, &s.ChoreID, &s.MemberOrder, &s.CurrentIndex)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("rotation state not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get rotation state: %w", err)
	}
	return &s, nil
}

// UpdateRotationState updates a rotation state.
func (r *ChoreRepository) UpdateRotationState(ctx context.Context, state *models.ChoreRotationState) error {
	query := `
		UPDATE chore_rotation_states
		SET member_order = $1, current_index = $2
		WHERE id = $3
	`
	tag, err := r.pool.Exec(ctx, query, state.MemberOrder, state.CurrentIndex, state.ID)
	if err != nil {
		return fmt.Errorf("failed to update rotation state: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("rotation state not found")
	}
	return nil
}

// BulkUpdateRotationStates updates member_order and current_index for multiple rotation states in a single batch.
func (r *ChoreRepository) BulkUpdateRotationStates(ctx context.Context, states []models.ChoreRotationState) error {
	if len(states) == 0 {
		return nil
	}
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)
	for _, s := range states {
		query := `UPDATE chore_rotation_states SET member_order = $1, current_index = $2 WHERE id = $3`
		if _, err := tx.Exec(ctx, query, s.MemberOrder, s.CurrentIndex, s.ID); err != nil {
			return fmt.Errorf("update rotation state %s: %w", s.ID, err)
		}
	}
	return tx.Commit(ctx)
}

// CreateAssignment inserts a new chore assignment.
func (r *ChoreRepository) CreateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error {
	assignment.ID = uuid.New()
	query := `
		INSERT INTO chore_assignments (id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err := r.pool.Exec(ctx, query,
		assignment.ID, assignment.ChoreID, assignment.UserID,
		assignment.Status, assignment.DueDate, assignment.AssignedAt,
		assignment.CompletedAt, assignment.SkipReason,
	)
	if err != nil {
		return fmt.Errorf("failed to create assignment: %w", err)
	}
	return nil
}

// ListAssignments retrieves assignments for a chore with pagination.
func (r *ChoreRepository) ListAssignments(ctx context.Context, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error) {
	query := `
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason
		FROM chore_assignments
		WHERE chore_id = $1
		ORDER BY assigned_at DESC
		LIMIT $2 OFFSET $3
	`
	limit = clampLimit(limit)
	rows, err := r.pool.Query(ctx, query, choreID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list assignments: %w", err)
	}
	defer rows.Close()

	var assignments []models.ChoreAssignment
	for rows.Next() {
		var a models.ChoreAssignment
		if err := rows.Scan(
			&a.ID, &a.ChoreID, &a.UserID, &a.Status,
			&a.DueDate, &a.AssignedAt, &a.CompletedAt, &a.SkipReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan assignment: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("assignment rows error: %w", err)
	}
	return assignments, nil
}

// UpdateAssignment updates a chore assignment.
func (r *ChoreRepository) UpdateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error {
	query := `
		UPDATE chore_assignments
		SET user_id = $1, status = $2, due_date = $3, completed_at = $4, skip_reason = $5
		WHERE id = $6
	`
	tag, err := r.pool.Exec(ctx, query,
		assignment.UserID, assignment.Status, assignment.DueDate,
		assignment.CompletedAt, assignment.SkipReason, assignment.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update assignment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("assignment not found")
	}
	return nil
}

func (r *ChoreRepository) CompleteAssignment(ctx context.Context, id uuid.UUID, status string, completedAt time.Time, skipReason *string) (bool, error) {
	query := `
		UPDATE chore_assignments
		SET status = $1, completed_at = $2, skip_reason = $3, updated_at = NOW()
		WHERE id = $4 AND status = 'pending'
	`
	tag, err := r.pool.Exec(ctx, query, status, completedAt, skipReason, id)
	if err != nil {
		return false, fmt.Errorf("failed to complete assignment: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// DeleteAssignment deletes an assignment by ID.
func (r *ChoreRepository) DeleteAssignment(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM chore_assignments WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete assignment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("assignment not found")
	}
	return nil
}

// CreateCompletion inserts a new chore completion record.
func (r *ChoreRepository) CreateCompletion(ctx context.Context, completion *models.ChoreCompletion) error {
	completion.ID = uuid.New()
	query := `
		INSERT INTO chore_completions (id, assignment_id, completed_by, completed_at, notes)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.pool.Exec(ctx, query,
		completion.ID, completion.AssignmentID, completion.CompletedBy,
		completion.CompletedAt, completion.Notes,
	)
	if err != nil {
		return fmt.Errorf("failed to create completion: %w", err)
	}
	return nil
}

// GetPendingAssignmentByChore retrieves the most recent pending assignment for a chore.
func (r *ChoreRepository) GetPendingAssignmentByChore(ctx context.Context, choreID uuid.UUID) (*models.ChoreAssignment, error) {
	query := `
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason
		FROM chore_assignments
		WHERE chore_id = $1 AND status = 'pending'
		ORDER BY assigned_at DESC
		LIMIT 1
	`
	var a models.ChoreAssignment
	err := r.pool.QueryRow(ctx, query, choreID).Scan(
		&a.ID, &a.ChoreID, &a.UserID, &a.Status,
		&a.DueDate, &a.AssignedAt, &a.CompletedAt, &a.SkipReason,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("pending assignment not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get pending assignment: %w", err)
	}
	return &a, nil
}

// ListDueAssignments returns pending assignments due within the given window.
func (r *ChoreRepository) ListDueAssignments(ctx context.Context, from, to time.Time) ([]models.ChoreAssignment, error) {
	query := `
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at, skip_reason
		FROM chore_assignments
		WHERE status = 'pending' AND due_date >= $1 AND due_date <= $2
		ORDER BY due_date ASC
	`
	rows, err := r.pool.Query(ctx, query, from, to)
	if err != nil {
		return nil, fmt.Errorf("failed to list due assignments: %w", err)
	}
	defer rows.Close()

	var assignments []models.ChoreAssignment
	for rows.Next() {
		var a models.ChoreAssignment
		if err := rows.Scan(
			&a.ID, &a.ChoreID, &a.UserID, &a.Status,
			&a.DueDate, &a.AssignedAt, &a.CompletedAt, &a.SkipReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan due assignment: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("due assignment rows error: %w", err)
	}
	return assignments, nil
}

// ListDueAssignmentsByGroup returns pending assignments for a group due within the window.
func (r *ChoreRepository) ListDueAssignmentsByGroup(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.ChoreAssignment, error) {
	query := `
		SELECT a.id, a.chore_id, a.user_id, a.status, a.due_date, a.assigned_at, a.completed_at, a.skip_reason
		FROM chore_assignments a
		JOIN chores c ON c.id = a.chore_id
		WHERE c.group_id = $1 AND a.status = 'pending' AND a.due_date >= $2 AND a.due_date <= $3
		ORDER BY a.due_date ASC
	`
	rows, err := r.pool.Query(ctx, query, groupID, from, to)
	if err != nil {
		return nil, fmt.Errorf("failed to list due assignments by group: %w", err)
	}
	defer rows.Close()

	var assignments []models.ChoreAssignment
	for rows.Next() {
		var a models.ChoreAssignment
		if err := rows.Scan(
			&a.ID, &a.ChoreID, &a.UserID, &a.Status,
			&a.DueDate, &a.AssignedAt, &a.CompletedAt, &a.SkipReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan due assignment: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("due assignment rows error: %w", err)
	}
	return assignments, nil
}

// CreateSubtask inserts a new chore subtask.
func (r *ChoreRepository) CreateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error {
	subtask.ID = uuid.New()
	query := `
		INSERT INTO chore_subtasks (id, chore_id, title, completed, position, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query,
		subtask.ID, subtask.ChoreID, subtask.Title, subtask.Completed, subtask.Position,
	).Scan(&subtask.CreatedAt, &subtask.UpdatedAt)
}

// GetSubtaskByID retrieves a subtask by ID.
func (r *ChoreRepository) GetSubtaskByID(ctx context.Context, id uuid.UUID) (*models.ChoreSubtask, error) {
	query := `
		SELECT id, chore_id, title, completed, position, created_at, updated_at
		FROM chore_subtasks
		WHERE id = $1
	`
	var s models.ChoreSubtask
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&s.ID, &s.ChoreID, &s.Title, &s.Completed, &s.Position,
		&s.CreatedAt, &s.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("subtask not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get subtask: %w", err)
	}
	return &s, nil
}

// ListSubtasksByChore retrieves subtasks for a chore ordered by position.
func (r *ChoreRepository) ListSubtasksByChore(ctx context.Context, choreID uuid.UUID) ([]models.ChoreSubtask, error) {
	query := `
		SELECT id, chore_id, title, completed, position, created_at, updated_at
		FROM chore_subtasks
		WHERE chore_id = $1
		ORDER BY position ASC, created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, choreID)
	if err != nil {
		return nil, fmt.Errorf("failed to list subtasks: %w", err)
	}
	defer rows.Close()

	var subtasks []models.ChoreSubtask
	for rows.Next() {
		var s models.ChoreSubtask
		if err := rows.Scan(
			&s.ID, &s.ChoreID, &s.Title, &s.Completed, &s.Position,
			&s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan subtask: %w", err)
		}
		subtasks = append(subtasks, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("subtask rows error: %w", err)
	}
	return subtasks, nil
}

// UpdateSubtask updates a subtask.
func (r *ChoreRepository) UpdateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error {
	query := `
		UPDATE chore_subtasks
		SET title = $1, completed = $2, position = $3, updated_at = NOW()
		WHERE id = $4
		RETURNING updated_at
	`
	err := r.pool.QueryRow(ctx, query,
		subtask.Title, subtask.Completed, subtask.Position, subtask.ID,
	).Scan(&subtask.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("subtask not found: %w", err)
		}
		return fmt.Errorf("failed to update subtask: %w", err)
	}
	return nil
}

// DeleteSubtask deletes a subtask by ID.
func (r *ChoreRepository) DeleteSubtask(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM chore_subtasks WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete subtask: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("subtask not found")
	}
	return nil
}

// DeleteSubtasksByChore deletes all subtasks for a chore.
func (r *ChoreRepository) DeleteSubtasksByChore(ctx context.Context, choreID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM chore_subtasks WHERE chore_id = $1`, choreID)
	if err != nil {
		return fmt.Errorf("failed to delete subtasks by chore: %w", err)
	}
	return nil
}
