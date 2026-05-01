package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// FinanceRepo handles raw SQL operations for financial domain entities.
type FinanceRepo struct {
	pool DBTX
}

// NewFinanceRepo creates a new FinanceRepo.
func NewFinanceRepo(pool DBTX) *FinanceRepo {
	return &FinanceRepo{pool: pool}
}

// ------------------------------------------------------------------
// Expenses
// ------------------------------------------------------------------

// CreateExpense inserts a new expense.
func (r *FinanceRepo) CreateExpense(ctx context.Context, e *models.Expense) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	now := time.Now().UTC()
	e.CreatedAt = now
	e.UpdatedAt = now

	_, err := r.pool.Exec(ctx, `
		INSERT INTO expenses (id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, e.ID, e.GroupID, e.PayerID, e.Amount, e.Description, e.Category, e.Currency, e.Notes, e.Date, e.CreatedAt, e.UpdatedAt)
	return err
}

// GetExpenseByID retrieves an expense by its ID.
func (r *FinanceRepo) GetExpenseByID(ctx context.Context, id uuid.UUID) (*models.Expense, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at
		FROM expenses
		WHERE id = $1
	`, id)

	var e models.Expense
	err := row.Scan(&e.ID, &e.GroupID, &e.PayerID, &e.Amount, &e.Description, &e.Category, &e.Currency, &e.Notes, &e.Date, &e.CreatedAt, &e.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("expense not found")
		}
		return nil, err
	}
	return &e, nil
}

// ListExpensesByGroup returns paginated expenses for a group.
func (r *FinanceRepo) ListExpensesByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Expense, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at
		FROM expenses
		WHERE group_id = $1
		ORDER BY date DESC, created_at DESC
		LIMIT $2 OFFSET $3
	`, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Expense])
}

// ListAllExpensesByGroup returns every expense for group-level financial projections.
func (r *FinanceRepo) ListAllExpensesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Expense, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at
		FROM expenses
		WHERE group_id = $1
		ORDER BY date DESC, created_at DESC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Expense])
}

// UpdateExpense updates an existing expense.
func (r *FinanceRepo) UpdateExpense(ctx context.Context, e *models.Expense) error {
	e.UpdatedAt = time.Now().UTC()

	cmd, err := r.pool.Exec(ctx, `
		UPDATE expenses
		SET payer_id = $1, amount = $2, description = $3, category = $4, currency = $5, notes = $6, date = $7, updated_at = $8
		WHERE id = $9
	`, e.PayerID, e.Amount, e.Description, e.Category, e.Currency, e.Notes, e.Date, e.UpdatedAt, e.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("expense not found")
	}
	return nil
}

// DeleteExpense removes an expense and its dependent splits.
func (r *FinanceRepo) DeleteExpense(ctx context.Context, id uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM splits WHERE expense_id = $1`, id)
	if err != nil {
		return err
	}

	cmd, err := tx.Exec(ctx, `DELETE FROM expenses WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("expense not found")
	}

	return tx.Commit(ctx)
}

// ------------------------------------------------------------------
// Splits
// ------------------------------------------------------------------

// CreateSplit inserts a new split.
func (r *FinanceRepo) CreateSplit(ctx context.Context, s *models.Split) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	s.CreatedAt = time.Now().UTC()

	_, err := r.pool.Exec(ctx, `
		INSERT INTO splits (id, expense_id, user_id, amount, is_settled, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, s.ID, s.ExpenseID, s.UserID, s.Amount, s.IsSettled, s.CreatedAt)
	return err
}

// ListSplitsByExpense returns all splits for an expense.
func (r *FinanceRepo) ListSplitsByExpense(ctx context.Context, expenseID uuid.UUID) ([]models.Split, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, expense_id, user_id, amount, is_settled, created_at
		FROM splits
		WHERE expense_id = $1
		ORDER BY created_at ASC
	`, expenseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Split])
}

// ListSplitsByGroup returns all splits for expenses in a group.
func (r *FinanceRepo) ListSplitsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Split, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT s.id, s.expense_id, s.user_id, s.amount, s.is_settled, s.created_at
		FROM splits s
		JOIN expenses e ON e.id = s.expense_id
		WHERE e.group_id = $1
		ORDER BY s.created_at ASC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Split])
}

// UpdateSplit updates an existing split.
func (r *FinanceRepo) UpdateSplit(ctx context.Context, s *models.Split) error {
	cmd, err := r.pool.Exec(ctx, `
		UPDATE splits
		SET user_id = $1, amount = $2, is_settled = $3
		WHERE id = $4
	`, s.UserID, s.Amount, s.IsSettled, s.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("split not found")
	}
	return nil
}

// DeleteSplit removes a split by ID.
func (r *FinanceRepo) DeleteSplit(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM splits WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("split not found")
	}
	return nil
}

// ------------------------------------------------------------------
// Settlements
// ------------------------------------------------------------------

// CreateSettlement inserts a new settlement using SELECT FOR UPDATE to prevent races.
func (r *FinanceRepo) CreateSettlement(ctx context.Context, s *models.Settlement) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	s.CreatedAt = time.Now().UTC()

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Lock existing settlements in this group to prevent race conditions.
	_, err = tx.Exec(ctx, `
		SELECT id FROM settlements WHERE group_id = $1 FOR UPDATE
	`, s.GroupID)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO settlements (id, group_id, from_user_id, to_user_id, amount, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, s.ID, s.GroupID, s.FromUserID, s.ToUserID, s.Amount, s.CreatedAt)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// ListSettlementsByGroup returns paginated settlements for a group.
func (r *FinanceRepo) ListSettlementsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Settlement, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, from_user_id, to_user_id, amount, created_at
		FROM settlements
		WHERE group_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Settlement])
}

// ListAllSettlementsByGroup returns every settlement for group-level financial projections.
func (r *FinanceRepo) ListAllSettlementsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Settlement, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, from_user_id, to_user_id, amount, created_at
		FROM settlements
		WHERE group_id = $1
		ORDER BY created_at DESC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Settlement])
}

// DeleteSettlement removes a settlement by ID.
func (r *FinanceRepo) DeleteSettlement(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM settlements WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("settlement not found")
	}
	return nil
}

// ------------------------------------------------------------------
// Recurring Expenses
// ------------------------------------------------------------------

// CreateRecurringExpense inserts a new recurring expense.
func (r *FinanceRepo) CreateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error {
	if re.ID == uuid.Nil {
		re.ID = uuid.New()
	}
	re.CreatedAt = time.Now().UTC()

	_, err := r.pool.Exec(ctx, `
		INSERT INTO recurring_expenses (id, group_id, payer_id, amount, description, category, frequency, next_due, is_active, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, re.ID, re.GroupID, re.PayerID, re.Amount, re.Description, re.Category, re.Frequency, re.NextDue, re.IsActive, re.CreatedAt)
	return err
}

// GetRecurringExpenseByID retrieves a recurring expense by its ID.
func (r *FinanceRepo) GetRecurringExpenseByID(ctx context.Context, id uuid.UUID) (*models.RecurringExpense, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, frequency, next_due, is_active, created_at
		FROM recurring_expenses
		WHERE id = $1
	`, id)

	var re models.RecurringExpense
	err := row.Scan(&re.ID, &re.GroupID, &re.PayerID, &re.Amount, &re.Description, &re.Category, &re.Frequency, &re.NextDue, &re.IsActive, &re.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("recurring expense not found")
		}
		return nil, err
	}
	return &re, nil
}

// ListRecurringExpenses returns paginated recurring expenses for a group.
func (r *FinanceRepo) ListRecurringExpenses(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.RecurringExpense, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, frequency, next_due, is_active, created_at, currency
		FROM recurring_expenses
		WHERE group_id = $1
		ORDER BY next_due ASC, created_at ASC
		LIMIT $2 OFFSET $3
	`, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.RecurringExpense])
}

// ListRecurringExpensesByDateRange returns active recurring expenses for a group with next_due in range.
func (r *FinanceRepo) ListRecurringExpensesByDateRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.RecurringExpense, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, payer_id, amount, description, category, frequency, next_due, is_active, created_at, currency
		FROM recurring_expenses
		WHERE group_id = $1 AND is_active = true AND next_due >= $2 AND next_due <= $3
		ORDER BY next_due ASC, created_at ASC
	`, groupID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.RecurringExpense])
}

// UpdateRecurringExpense updates an existing recurring expense.
func (r *FinanceRepo) UpdateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error {
	cmd, err := r.pool.Exec(ctx, `
		UPDATE recurring_expenses
		SET payer_id = $1, amount = $2, description = $3, category = $4, frequency = $5, next_due = $6, is_active = $7
		WHERE id = $8
	`, re.PayerID, re.Amount, re.Description, re.Category, re.Frequency, re.NextDue, re.IsActive, re.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("recurring expense not found")
	}
	return nil
}

// DeleteRecurringExpense removes a recurring expense by ID.
func (r *FinanceRepo) DeleteRecurringExpense(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM recurring_expenses WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("recurring expense not found")
	}
	return nil
}

// GetSplitByID retrieves a split by its ID.
func (r *FinanceRepo) GetSplitByID(ctx context.Context, id uuid.UUID) (*models.Split, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, expense_id, user_id, amount, is_settled, created_at
		FROM splits
		WHERE id = $1
	`, id)
	var s models.Split
	err := row.Scan(&s.ID, &s.ExpenseID, &s.UserID, &s.Amount, &s.IsSettled, &s.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("split not found")
		}
		return nil, err
	}
	return &s, nil
}

// GetSettlementByID retrieves a settlement by its ID.
func (r *FinanceRepo) GetSettlementByID(ctx context.Context, id uuid.UUID) (*models.Settlement, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, group_id, from_user_id, to_user_id, amount, created_at
		FROM settlements
		WHERE id = $1
	`, id)
	var s models.Settlement
	err := row.Scan(&s.ID, &s.GroupID, &s.FromUserID, &s.ToUserID, &s.Amount, &s.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("settlement not found")
		}
		return nil, err
	}
	return &s, nil
}

// CreateExpenseWithSplits inserts an expense and its splits atomically.
func (r *FinanceRepo) CreateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	now := time.Now().UTC()
	e.CreatedAt = now
	e.UpdatedAt = now

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO expenses (id, group_id, payer_id, amount, description, category, currency, notes, date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, e.ID, e.GroupID, e.PayerID, e.Amount, e.Description, e.Category, e.Currency, e.Notes, e.Date, e.CreatedAt, e.UpdatedAt)
	if err != nil {
		return err
	}

	for i := range splits {
		s := &splits[i]
		if s.ID == uuid.Nil {
			s.ID = uuid.New()
		}
		s.ExpenseID = e.ID
		s.CreatedAt = now
		_, err = tx.Exec(ctx, `
			INSERT INTO splits (id, expense_id, user_id, amount, is_settled, created_at)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, s.ID, s.ExpenseID, s.UserID, s.Amount, s.IsSettled, s.CreatedAt)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}
