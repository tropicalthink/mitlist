package models

import (
	"time"

	"github.com/google/uuid"
)

// CalendarEventType identifies the source of a calendar event.
type CalendarEventType string

const (
	EventTypeMealPlan          CalendarEventType = "meal_plan"
	EventTypeChore             CalendarEventType = "chore"
	EventTypeRecurringExpense  CalendarEventType = "recurring_expense"
	EventTypeExpense           CalendarEventType = "expense"
	EventTypePinwallReminder   CalendarEventType = "pinwall_reminder"
)

// CalendarEvent is a unified event for the household calendar.
type CalendarEvent struct {
	ID          string            `json:"id"`
	Type        CalendarEventType `json:"type"`
	Title       string            `json:"title"`
	Date        time.Time         `json:"date"`
	GroupID     uuid.UUID         `json:"group_id"`
	// Type-specific fields (omitempty)
	MealPlan       *CalendarMealPlan       `json:"meal_plan,omitempty"`
	Chore          *CalendarChore          `json:"chore,omitempty"`
	RecurringExpense *CalendarRecurringExpense `json:"recurring_expense,omitempty"`
	Expense          *CalendarExpense          `json:"expense,omitempty"`
	PinwallReminder  *CalendarPinwallReminder   `json:"pinwall_reminder,omitempty"`
}

// CalendarMealPlan holds meal-plan-specific calendar data.
type CalendarMealPlan struct {
	MealPlanID uuid.UUID `json:"meal_plan_id"`
	Slot       string    `json:"slot"`
	RecipeID   uuid.UUID `json:"recipe_id"`
	Servings   int       `json:"servings"`
	CookUserID *uuid.UUID `json:"cook_user_id,omitempty"`
}

// CalendarChore holds chore-specific calendar data.
type CalendarChore struct {
	ChoreID     uuid.UUID `json:"chore_id"`
	AssignmentID uuid.UUID `json:"assignment_id"`
	UserID      uuid.UUID `json:"user_id"`
	Status      string    `json:"status"`
}

// CalendarRecurringExpense holds recurring-expense-specific calendar data.
type CalendarRecurringExpense struct {
	RecurringExpenseID uuid.UUID `json:"recurring_expense_id"`
	PayerID            uuid.UUID `json:"payer_id"`
	Amount             int64     `json:"amount"`
	Currency           string    `json:"currency"`
	Frequency          string    `json:"frequency"`
}

// CalendarPinwallReminder holds pinwall-reminder-specific calendar data.
type CalendarPinwallReminder struct {
	PostID   uuid.UUID `json:"post_id"`
	UserID   uuid.UUID `json:"user_id"`
	Content  string    `json:"content"`
	Sent     bool      `json:"sent"`
}

// CalendarExpense holds expense-specific calendar data.
type CalendarExpense struct {
	ExpenseID   uuid.UUID `json:"expense_id"`
	PayerID     uuid.UUID `json:"payer_id"`
	Amount      int64     `json:"amount"`
	Currency    string    `json:"currency"`
	Category    string    `json:"category"`
}
