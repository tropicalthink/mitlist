package models

// NotificationPayload is a typed deep-link schema stored in Notification.Data.
type NotificationPayload struct {
	Screen     string            `json:"screen"`      // e.g. choreDetail, expenseDetail, listDetail, recipeDetail, mealPlan, householdHub, recurringExpense
	EntityType string            `json:"entity_type"` // e.g. chore, expense, list, recipe, meal_plan, recurring_expense
	ID         string            `json:"id"`          // primary entity UUID
	GroupID    string            `json:"group_id,omitempty"`
	ActorName  string            `json:"actor_name,omitempty"`
	EntityName string            `json:"entity_name,omitempty"`
	ItemName   string            `json:"item_name,omitempty"`
	Copy       *NotificationCopy `json:"copy,omitempty"`
}

// NotificationCopy is a versioned, language-neutral instruction for clients.
// Title and body remain persisted as fallbacks for older clients and channels.
type NotificationCopy struct {
	Version  int               `json:"version"`
	Template string            `json:"template"`
	Params   map[string]string `json:"params,omitempty"`
}

const (
	NotificationTemplateChoreDueSoon            = "chore_due_soon"
	NotificationTemplateChoreDueToday           = "chore_due_today"
	NotificationTemplateListItemsAdded          = "list_items_added"
	NotificationTemplateExpenseCreated          = "expense_created"
	NotificationTemplateRecurringExpenseCreated = "recurring_expense_created"
	NotificationTemplateSettlementPaidYou       = "settlement_requested_paid_you"
	NotificationTemplateSettlementYouPaid       = "settlement_requested_you_paid"
	NotificationTemplateSettlementConfirmed     = "settlement_confirmed"
	NotificationTemplateSettlementDeclined      = "settlement_declined"
	NotificationTemplateMealPlanChanged         = "meal_plan_changed"
	NotificationTemplateWeeklyDigest            = "weekly_digest"
	NotificationTemplatePinwallReminder         = "pinwall_reminder"
)

func NewNotificationCopy(template string, params map[string]string) *NotificationCopy {
	return &NotificationCopy{Version: 1, Template: template, Params: params}
}

const (
	ScreenChoreDetail       = "choreDetail"
	ScreenExpenseDetail     = "expenseDetail"
	ScreenListDetail        = "listDetail"
	ScreenRecipeDetail      = "recipeDetail"
	ScreenMealPlan          = "mealPlan"
	ScreenHouseholdHub      = "householdHub"
	ScreenRecurringExpenses = "recurringExpenses"
	ScreenSettlements       = "settlements"
)

const (
	EntityTypeChore            = "chore"
	EntityTypeExpense          = "expense"
	EntityTypeList             = "list"
	EntityTypeRecipe           = "recipe"
	EntityTypeMealPlan         = "meal_plan"
	EntityTypeRecurringExpense = "recurring_expense"
	EntityTypePinwallPost      = "pinwall_post"
	EntityTypeSettlement       = "settlement"
)
