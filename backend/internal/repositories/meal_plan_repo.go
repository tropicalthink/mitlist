package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// MealPlanRepo handles raw SQL operations for meal plans.
type MealPlanRepo struct {
	pool DBTX
}

// NewMealPlanRepo creates a new MealPlanRepo.
func NewMealPlanRepo(pool DBTX) *MealPlanRepo {
	return &MealPlanRepo{pool: pool}
}

// CreateMealPlan inserts a new meal plan.
func (r *MealPlanRepo) CreateMealPlan(ctx context.Context, mp *models.MealPlan) error {
	if mp.ID == uuid.Nil {
		mp.ID = uuid.New()
	}
	now := time.Now().UTC()
	mp.CreatedAt = now
	mp.UpdatedAt = now

	_, err := r.pool.Exec(ctx, `
		INSERT INTO meal_plans (id, group_id, date, slot, recipe_id, servings, cook_user_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, mp.ID, mp.GroupID, mp.Date, mp.Slot, mp.RecipeID, mp.Servings, mp.CookUserID, mp.CreatedAt, mp.UpdatedAt)
	return err
}

// GetMealPlanByID retrieves a meal plan by its ID.
func (r *MealPlanRepo) GetMealPlanByID(ctx context.Context, id uuid.UUID) (*models.MealPlan, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, group_id, date, slot, recipe_id, servings, cook_user_id, created_at, updated_at
		FROM meal_plans
		WHERE id = $1
	`, id)

	var mp models.MealPlan
	var cookUserID *uuid.UUID
	err := row.Scan(&mp.ID, &mp.GroupID, &mp.Date, &mp.Slot, &mp.RecipeID, &mp.Servings, &cookUserID, &mp.CreatedAt, &mp.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("meal plan not found")
		}
		return nil, err
	}
	mp.CookUserID = cookUserID
	return &mp, nil
}

// ListMealPlansByGroup returns meal plans for a group within a date range.
func (r *MealPlanRepo) ListMealPlansByGroup(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, date, slot, recipe_id, servings, cook_user_id, created_at, updated_at
		FROM meal_plans
		WHERE group_id = $1 AND date >= $2 AND date <= $3
		ORDER BY date ASC, slot ASC
	`, groupID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var plans []models.MealPlan
	for rows.Next() {
		var mp models.MealPlan
		var cookUserID *uuid.UUID
		if err := rows.Scan(&mp.ID, &mp.GroupID, &mp.Date, &mp.Slot, &mp.RecipeID, &mp.Servings, &cookUserID, &mp.CreatedAt, &mp.UpdatedAt); err != nil {
			return nil, err
		}
		mp.CookUserID = cookUserID
		plans = append(plans, mp)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return plans, nil
}

// UpdateMealPlan updates an existing meal plan.
func (r *MealPlanRepo) UpdateMealPlan(ctx context.Context, mp *models.MealPlan) error {
	mp.UpdatedAt = time.Now().UTC()
	cmd, err := r.pool.Exec(ctx, `
		UPDATE meal_plans
		SET date = $1, slot = $2, recipe_id = $3, servings = $4, cook_user_id = $5, updated_at = $6
		WHERE id = $7
	`, mp.Date, mp.Slot, mp.RecipeID, mp.Servings, mp.CookUserID, mp.UpdatedAt, mp.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("meal plan not found")
	}
	return nil
}

// DeleteMealPlan removes a meal plan by ID.
func (r *MealPlanRepo) DeleteMealPlan(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM meal_plans WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("meal plan not found")
	}
	return nil
}
