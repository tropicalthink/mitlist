package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
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
		INSERT INTO chores (id, group_id, name, description, rotation_type, frequency, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query,
		chore.ID, chore.GroupID, chore.Name, chore.Description,
		chore.RotationType, chore.Frequency, chore.IsActive,
	).Scan(&chore.CreatedAt, &chore.UpdatedAt)
}

// GetChoreByID retrieves a chore by ID.
func (r *ChoreRepository) GetChoreByID(ctx context.Context, id uuid.UUID) (*models.Chore, error) {
	query := `
		SELECT id, group_id, name, description, rotation_type, frequency, is_active, created_at, updated_at
		FROM chores
		WHERE id = $1
	`
	var c models.Chore
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&c.ID, &c.GroupID, &c.Name, &c.Description,
		&c.RotationType, &c.Frequency, &c.IsActive,
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
		SELECT id, group_id, name, description, rotation_type, frequency, is_active, created_at, updated_at
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
			&c.RotationType, &c.Frequency, &c.IsActive,
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

// UpdateChore updates a chore.
func (r *ChoreRepository) UpdateChore(ctx context.Context, chore *models.Chore) error {
	query := `
		UPDATE chores
		SET name = $1, description = $2, rotation_type = $3, frequency = $4, is_active = $5, updated_at = NOW()
		WHERE id = $6
		RETURNING updated_at
	`
	err := r.pool.QueryRow(ctx, query,
		chore.Name, chore.Description, chore.RotationType,
		chore.Frequency, chore.IsActive, chore.ID,
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

// CreateAssignment inserts a new chore assignment.
func (r *ChoreRepository) CreateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error {
	assignment.ID = uuid.New()
	query := `
		INSERT INTO chore_assignments (id, chore_id, user_id, status, due_date, assigned_at, completed_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.pool.Exec(ctx, query,
		assignment.ID, assignment.ChoreID, assignment.UserID,
		assignment.Status, assignment.DueDate, assignment.AssignedAt,
		assignment.CompletedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to create assignment: %w", err)
	}
	return nil
}

// ListAssignments retrieves assignments for a chore with pagination.
func (r *ChoreRepository) ListAssignments(ctx context.Context, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error) {
	query := `
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at
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
			&a.DueDate, &a.AssignedAt, &a.CompletedAt,
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
		SET user_id = $1, status = $2, due_date = $3, completed_at = $4
		WHERE id = $5
	`
	tag, err := r.pool.Exec(ctx, query,
		assignment.UserID, assignment.Status, assignment.DueDate,
		assignment.CompletedAt, assignment.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update assignment: %w", err)
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
		SELECT id, chore_id, user_id, status, due_date, assigned_at, completed_at
		FROM chore_assignments
		WHERE chore_id = $1 AND status = 'pending'
		ORDER BY assigned_at DESC
		LIMIT 1
	`
	var a models.ChoreAssignment
	err := r.pool.QueryRow(ctx, query, choreID).Scan(
		&a.ID, &a.ChoreID, &a.UserID, &a.Status,
		&a.DueDate, &a.AssignedAt, &a.CompletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("pending assignment not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get pending assignment: %w", err)
	}
	return &a, nil
}
