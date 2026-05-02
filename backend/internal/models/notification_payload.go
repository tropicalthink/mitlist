package models

// NotificationPayload is a typed deep-link schema stored in Notification.Data.
type NotificationPayload struct {
	Screen     string `json:"screen"`       // e.g. choreDetail, expenseDetail, listDetail, recipeDetail, mealPlan, householdHub, recurringExpense
	EntityType string `json:"entity_type"`  // e.g. chore, expense, list, recipe, meal_plan, recurring_expense
	ID         string `json:"id"`           // primary entity UUID
	GroupID    string `json:"group_id,omitempty"`
}

const (
	ScreenChoreDetail          = "choreDetail"
	ScreenExpenseDetail        = "expenseDetail"
	ScreenListDetail           = "listDetail"
	ScreenRecipeDetail         = "recipeDetail"
	ScreenMealPlan             = "mealPlan"
	ScreenHouseholdHub         = "householdHub"
	ScreenRecurringExpenses    = "recurringExpenses"
)

const (
	EntityTypeChore            = "chore"
	EntityTypeExpense          = "expense"
	EntityTypeList             = "list"
	EntityTypeRecipe           = "recipe"
	EntityTypeMealPlan         = "meal_plan"
	EntityTypeRecurringExpense = "recurring_expense"
	EntityTypePinwallPost      = "pinwall_post"
)
