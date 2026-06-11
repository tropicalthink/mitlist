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
	Notes       string    `json:"notes"`
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

// BalanceEntry summarizes how much a user has paid, owes, and is net owed.
type BalanceEntry struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName string    `json:"display_name"`
	Paid        int64     `json:"paid"`
	Owed        int64     `json:"owed"`
	Total       int64     `json:"total"`
}

// ReimbursementSuggestion is the minimal payment needed to simplify balances.
type ReimbursementSuggestion struct {
	FromUserID      uuid.UUID `json:"from_user_id"`
	FromDisplayName string    `json:"from_display_name"`
	ToUserID        uuid.UUID `json:"to_user_id"`
	ToDisplayName   string    `json:"to_display_name"`
	Amount          int64     `json:"amount"`
}

// FinanceSummary is the canonical server-side projection for group balances.
type FinanceSummary struct {
	Balances       []BalanceEntry            `json:"balances"`
	Reimbursements []ReimbursementSuggestion `json:"reimbursements"`
}

// RecurringSplitInput describes one participant's share for a recurring expense.
type RecurringSplitInput struct {
	UserID     uuid.UUID `json:"user_id"`
	Amount     int64     `json:"amount"`
	Shares     int64     `json:"shares"`
	Percentage int64     `json:"percentage"`
}

// BalanceAggregate is the raw per-user aggregate returned by the database for
// the GetGroupBalanceAggregates query. It carries the four raw sums that the
// in-memory calculateBalances helper previously assembled from three full
// table scans. The mapping to BalanceEntry is:
//
//	Paid  = ExpensePaid  + SettledOut  (payer credits + settlement debits from)
//	Owed  = SplitOwed   + SettledIn   (split debits  + settlement credits to)
//	Total = Paid - Owed
type BalanceAggregate struct {
	UserID      uuid.UUID
	ExpensePaid int64 // SUM(expenses.amount) WHERE payer_id = user_id
	SplitOwed   int64 // SUM(splits.amount) — IsSettled is ignored
	SettledOut  int64 // SUM(settlements.amount) WHERE from_user_id = user_id
	SettledIn   int64 // SUM(settlements.amount) WHERE to_user_id = user_id
}

// RecurringExpense represents a repeating expense.
type RecurringExpense struct {
	ID          uuid.UUID             `json:"id"`
	GroupID     uuid.UUID             `json:"group_id"`
	PayerID     uuid.UUID             `json:"payer_id"`
	Amount      int64                 `json:"amount"`
	Description string                `json:"description"`
	Category    string                `json:"category"`
	Currency    string                `json:"currency"`
	Frequency   string                `json:"frequency"`
	NextDue     time.Time             `json:"next_due"`
	IsActive    bool                  `json:"is_active"`
	CreatedAt   time.Time             `json:"created_at"`
	SplitMode   string                `json:"split_mode"`
	SplitInputs []RecurringSplitInput `json:"split_inputs"`
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
