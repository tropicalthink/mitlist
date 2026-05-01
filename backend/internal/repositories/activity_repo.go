package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ActivityRepository aggregates recent events from multiple tables.
type ActivityRepository struct {
	pool *pgxpool.Pool
}

// NewActivityRepository creates a new ActivityRepository.
func NewActivityRepository(pool *pgxpool.Pool) *ActivityRepository {
	return &ActivityRepository{pool: pool}
}

// ListRecentActivity returns the most recent household events across lists, expenses, chores, meal plans, and recipes.
func (r *ActivityRepository) ListRecentActivity(ctx context.Context, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error) {
	if limit <= 0 {
		limit = 10
	}
	query := `
		SELECT id, type, title, created_at, user_id, group_id FROM (
			SELECT id::text, 'list_item_added' as type, name as title, created_at, added_by as user_id, list_id as group_id
			FROM list_items
			WHERE list_id IN (SELECT id FROM lists WHERE group_id = $1)
			UNION ALL
			SELECT id::text, 'expense_created', description, created_at, payer_id, group_id
			FROM expenses
			WHERE group_id = $1
			UNION ALL
			SELECT c.id::text, 'chore_completed', ch.name, c.completed_at as created_at, c.completed_by as user_id, ch.group_id
			FROM chore_completions c
			JOIN chore_assignments a ON a.id = c.assignment_id
			JOIN chores ch ON ch.id = a.chore_id
			WHERE ch.group_id = $1
			UNION ALL
			SELECT id::text, 'meal_plan_created', 'Meal planned', created_at, cook_user_id, group_id
			FROM meal_plans
			WHERE group_id = $1
			UNION ALL
			SELECT id::text, 'recipe_added', title, created_at, user_id, group_id
			FROM recipes
			WHERE group_id = $1
		) events
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, groupID, limit)
	if err != nil {
		return nil, fmt.Errorf("list recent activity: %w", err)
	}
	defer rows.Close()

	var events []models.ActivityEvent
	for rows.Next() {
		var e models.ActivityEvent
		var userID *uuid.UUID
		if err := rows.Scan(&e.ID, &e.Type, &e.Title, &e.CreatedAt, &userID, &e.GroupID); err != nil {
			return nil, fmt.Errorf("scan activity event: %w", err)
		}
		e.UserID = userID
		events = append(events, e)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("activity rows error: %w", err)
	}
	return events, nil
}

// CountWeeklyActivity returns counts of household activity over the past 7 days.
func (r *ActivityRepository) CountWeeklyActivity(ctx context.Context, groupID uuid.UUID) (map[string]int, error) {
	cutoff := time.Now().UTC().AddDate(0, 0, -7)
	query := `
		SELECT
			(SELECT COUNT(*) FROM list_items li JOIN lists l ON l.id = li.list_id WHERE l.group_id = $1 AND li.created_at >= $2) AS lists,
			(SELECT COUNT(*) FROM expenses WHERE group_id = $1 AND created_at >= $2) AS expenses,
			(SELECT COUNT(*) FROM chore_completions cc JOIN chore_assignments ca ON ca.id = cc.assignment_id JOIN chores ch ON ch.id = ca.chore_id WHERE ch.group_id = $1 AND cc.completed_at >= $2) AS chores,
			(SELECT COUNT(*) FROM meal_plans WHERE group_id = $1 AND created_at >= $2) AS meal_plans,
			(SELECT COUNT(*) FROM recipes WHERE group_id = $1 AND created_at >= $2) AS recipes
	`
	var lists, expenses, chores, mealPlans, recipes int
	if err := r.pool.QueryRow(ctx, query, groupID, cutoff).Scan(&lists, &expenses, &chores, &mealPlans, &recipes); err != nil {
		return nil, fmt.Errorf("count weekly activity: %w", err)
	}
	return map[string]int{
		"lists":      lists,
		"expenses":   expenses,
		"chores":     chores,
		"meal_plans": mealPlans,
		"recipes":    recipes,
	}, nil
}
