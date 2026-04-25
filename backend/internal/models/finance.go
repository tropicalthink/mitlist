package models

import (
	"time"

	"github.com/google/uuid"
)

// Expense represents a group expense.
type Expense struct {
	ID          uuid.UUID `json:"id"`
	GroupID     uuid.UUID `json:"group_id"`
	PayerID     uuid.UUID `json:"payer_id"`
	Amount      int64     `json:"amount"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	Currency    string    `json:"currency"`
	Date        time.Time `json:"date"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Split represents an expense split among users.
type Split struct {
	ID        uuid.UUID `json:"id"`
	ExpenseID uuid.UUID `json:"expense_id"`
	UserID    uuid.UUID `json:"user_id"`
	Amount    int64     `json:"amount"`
	IsSettled bool      `json:"is_settled"`
	CreatedAt time.Time `json:"created_at"`
}

// Settlement represents a payment between two users.
type Settlement struct {
	ID         uuid.UUID `json:"id"`
	GroupID    uuid.UUID `json:"group_id"`
	FromUserID uuid.UUID `json:"from_user_id"`
	ToUserID   uuid.UUID `json:"to_user_id"`
	Amount     int64     `json:"amount"`
	CreatedAt  time.Time `json:"created_at"`
}

// RecurringExpense represents a repeating expense.
type RecurringExpense struct {
	ID          uuid.UUID `json:"id"`
	GroupID     uuid.UUID `json:"group_id"`
	PayerID     uuid.UUID `json:"payer_id"`
	Amount      int64     `json:"amount"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	Currency    string    `json:"currency"`
	Frequency   string    `json:"frequency"`
	NextDue     time.Time `json:"next_due"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
}

// ExpenseCategory groups expenses by category.
type ExpenseCategory struct {
	ID      uuid.UUID `json:"id"`
	GroupID uuid.UUID `json:"group_id"`
	Name    string    `json:"name"`
	Color   string    `json:"color"`
}

// SettlementMethod is a way to settle debts.
type SettlementMethod struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
}

// PaymentMethod is a way to pay for expenses.
type PaymentMethod struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
}
