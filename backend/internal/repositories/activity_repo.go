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
		SELECT events.id, events.type, events.title, events.created_at, events.user_id, events.group_id,
		       events.entity_type, events.entity_id, events.context,
		       NULLIF(TRIM(CONCAT(u.first_name, ' ', u.last_name)), '') AS user_name
		FROM (
			SELECT li.id::text, 'list_item_added' as type, li.name as title, li.created_at, li.added_by as user_id, l.group_id, 'list' as entity_type, l.id::text as entity_id, l.name as context
			FROM list_items li
			JOIN lists l ON l.id = li.list_id
			WHERE l.group_id = $1
			UNION ALL
			SELECT id::text, 'expense_created', description, created_at, payer_id, group_id, 'expense', id::text, NULL::text
			FROM expenses
			WHERE group_id = $1
			UNION ALL
			SELECT c.id::text, 'chore_completed', ch.name, c.completed_at as created_at, c.completed_by as user_id, ch.group_id, 'chore', ch.id::text, NULL::text
			FROM chore_completions c
			JOIN chore_assignments a ON a.id = c.assignment_id
			JOIN chores ch ON ch.id = a.chore_id
			WHERE ch.group_id = $1
			UNION ALL
			SELECT mp.id::text, 'meal_plan_created', r.title, mp.created_at, mp.cook_user_id, mp.group_id, 'meal_plan', mp.id::text, mp.slot
			FROM meal_plans mp
			JOIN recipes r ON r.id = mp.recipe_id
			WHERE mp.group_id = $1
			UNION ALL
			SELECT rcp.id::text, 'recipe_added', rcp.title, rcp.created_at, rcp.user_id, gm.group_id, 'recipe', rcp.id::text, NULL::text
			FROM recipes rcp
			JOIN group_memberships gm ON gm.user_id = rcp.user_id
			WHERE gm.group_id = $1
		) events
		LEFT JOIN users u ON u.id = events.user_id
		ORDER BY events.created_at DESC
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
		var context, userName *string
		if err := rows.Scan(&e.ID, &e.Type, &e.Title, &e.CreatedAt, &userID, &e.GroupID, &e.EntityType, &e.EntityId, &context, &userName); err != nil {
			return nil, fmt.Errorf("scan activity event: %w", err)
		}
		e.UserID = userID
		e.Context = context
		e.UserName = userName
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
			(SELECT COUNT(*) FROM recipes rcp JOIN group_memberships gm ON gm.user_id = rcp.user_id WHERE gm.group_id = $1 AND rcp.created_at >= $2) AS recipes
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
