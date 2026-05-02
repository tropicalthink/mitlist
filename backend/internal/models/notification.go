package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

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
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}


