package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

const (
	NotificationTypeChoreDue                = "chore_due"
	NotificationTypeChoreDueDayOf           = "chore_due_day_of"
	NotificationTypeListItemAdded           = "list_item_added"
	NotificationTypeListItemsAddedDigest    = "list_items_added_digest"
	NotificationTypeExpenseCreated          = "expense_created"
	NotificationTypeRecurringExpenseCreated = "recurring_expense_created"
	NotificationTypeSettlementRequested     = "settlement_requested"
	NotificationTypeSettlementConfirmed     = "settlement_confirmed"
	NotificationTypeSettlementDeclined      = "settlement_declined"
	NotificationTypeMealPlanChanged         = "meal_plan_changed"
	NotificationTypeWeeklyDigest            = "weekly_digest"
	NotificationTypePinwallReminder         = "pinwall_reminder"
)

// ActivityNotificationBatch is one interactive event queued for coalescing.
// Events by the same actor, of the same type, in the same scope, are merged
// into a single notification when the burst ends (see
// NotificationRepo.QueueActivityNotification). Title, Body, and Payload are the
// notification that would have been sent immediately; they are replayed as-is
// when the burst turns out to contain a single event.
type ActivityNotificationBatch struct {
	GroupID   uuid.UUID
	ActorID   uuid.UUID
	Type      string
	ScopeKey  string
	ActorName string
	ItemName  string
	Title     string
	Body      string
	Payload   json.RawMessage
}

type Notification struct {
	ID        uuid.UUID       `json:"id"`
	UserID    uuid.UUID       `json:"user_id"`
	GroupID   uuid.UUID       `json:"group_id,omitempty"`
	Type      string          `json:"type"`
	Title     string          `json:"title"`
	Body      string          `json:"body"`
	Data      json.RawMessage `json:"data"`
	IsRead    bool            `json:"is_read"`
	ReadAt    *time.Time      `json:"read_at,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
}

// NotificationPreference controls which push/in-app notifications a user receives for a group.
type NotificationPreference struct {
	ID              uuid.UUID `json:"id"`
	UserID          uuid.UUID `json:"user_id"`
	GroupID         uuid.UUID `json:"group_id"`
	ChoreDue        bool      `json:"chore_due"`
	ChoreDueDayOf   bool      `json:"chore_due_day_of"`
	ListItemAdded   bool      `json:"list_item_added"`
	ExpenseCreated  bool      `json:"expense_created"`
	MealPlanChanged bool      `json:"meal_plan_changed"`
	WeeklyDigest    bool      `json:"weekly_digest"`
	PinwallReminder bool      `json:"pinwall_reminder"`
	PushEnabled     bool      `json:"push_enabled"`
	EmailEnabled    bool      `json:"email_enabled"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// DefaultNotificationPreference returns the default preference for a user/group
// that has no saved row. All categories default ON; PushEnabled ON. EmailEnabled
// defaults OFF — email is opt-in (plan 024).
func DefaultNotificationPreference(userID, groupID uuid.UUID) *NotificationPreference {
	return &NotificationPreference{
		UserID: userID, GroupID: groupID,
		ChoreDue: true, ChoreDueDayOf: true, ListItemAdded: true,
		ExpenseCreated: true, MealPlanChanged: true, WeeklyDigest: true,
		PinwallReminder: true, PushEnabled: true,
		EmailEnabled: false, // opt-in; never default on
	}
}
