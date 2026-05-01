package models

import (
	"time"

	"github.com/google/uuid"
)

// ActivityType identifies the kind of household activity.
type ActivityType string

const (
	ActivityTypeListItemAdded   ActivityType = "list_item_added"
	ActivityTypeExpenseCreated  ActivityType = "expense_created"
	ActivityTypeChoreCompleted  ActivityType = "chore_completed"
	ActivityTypeMealPlanCreated ActivityType = "meal_plan_created"
	ActivityTypeRecipeAdded     ActivityType = "recipe_added"
)

// ActivityEvent is a recent household event for the pinwall strip.
type ActivityEvent struct {
	ID        string       `json:"id"`
	Type      ActivityType `json:"type"`
	Title     string       `json:"title"`
	CreatedAt time.Time    `json:"created_at"`
	UserID    *uuid.UUID   `json:"user_id,omitempty"`
	GroupID   uuid.UUID    `json:"group_id"`
}
