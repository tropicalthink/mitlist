package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

// ActivityRepository provides data access for activity logs.
type ActivityRepository struct {
	db DBTX
}

// NewActivityRepository creates a new ActivityRepository.
func NewActivityRepository(db DBTX) *ActivityRepository {
	return &ActivityRepository{db: db}
}

// LogActivity inserts a new activity log and returns it with generated fields.
func (r *ActivityRepository) LogActivity(ctx context.Context, a *models.ActivityLog) error {
	query := `
		INSERT INTO activity_logs (id, group_id, user_id, action, entity_type, entity_id, metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, group_id, user_id, action, entity_type, entity_id, metadata, created_at
	`
	return r.db.QueryRow(ctx, query,
		a.ID, a.GroupID, a.UserID, a.Action, a.EntityType, a.EntityID, a.Metadata, a.CreatedAt,
	).Scan(&a.ID, &a.GroupID, &a.UserID, &a.Action, &a.EntityType, &a.EntityID, &a.Metadata, &a.CreatedAt)
}

// GetActivityLogByID retrieves an activity log by its ID.
func (r *ActivityRepository) GetActivityLogByID(ctx context.Context, id uuid.UUID) (*models.ActivityLog, error) {
	query := `
		SELECT id, group_id, user_id, action, entity_type, entity_id, metadata, created_at
		FROM activity_logs
		WHERE id = $1
	`
	var a models.ActivityLog
	err := r.db.QueryRow(ctx, query, id).Scan(
		&a.ID, &a.GroupID, &a.UserID, &a.Action, &a.EntityType, &a.EntityID, &a.Metadata, &a.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("activity log not found: %w", err)
		}
		return nil, err
	}
	return &a, nil
}

// ListActivityLogsByGroup lists activity logs for a group, newest first.
func (r *ActivityRepository) ListActivityLogsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ActivityLog, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	query := `
		SELECT id, group_id, user_id, action, entity_type, entity_id, metadata, created_at
		FROM activity_logs
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []models.ActivityLog
	for rows.Next() {
		var a models.ActivityLog
		if err := rows.Scan(
			&a.ID, &a.GroupID, &a.UserID, &a.Action, &a.EntityType, &a.EntityID, &a.Metadata, &a.CreatedAt,
		); err != nil {
			return nil, err
		}
		logs = append(logs, a)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return logs, nil
}

// DeleteActivityLog removes an activity log by ID.
func (r *ActivityRepository) DeleteActivityLog(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM activity_logs WHERE id = $1`
	cmd, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("activity log not found")
	}
	return nil
}
