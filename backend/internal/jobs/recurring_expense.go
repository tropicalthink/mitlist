package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/robfig/cron/v3"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// RecurringExpenseJob processes due recurring expenses by creating expense
// copies with auto-settled payer splits and advancing the next due date.
// Run hourly.
type RecurringExpenseJob struct {
	repo       recurringExpenseRepo
	push       Pusher
	dispatcher NotificationDispatcher // preferred; push used as fallback
	log        *logger.Logger
}

// NewRecurringExpenseJob creates a new RecurringExpenseJob.
func NewRecurringExpenseJob(db repositories.DBTX, push Pusher, log *logger.Logger) *RecurringExpenseJob {
	return &RecurringExpenseJob{repo: &recurringExpenseRepoImpl{db: db}, push: push, log: log}
}

// NewRecurringExpenseJobWithDispatcher creates a RecurringExpenseJob that persists feed rows via the dispatcher.
func NewRecurringExpenseJobWithDispatcher(db repositories.DBTX, dispatcher NotificationDispatcher, log *logger.Logger) *RecurringExpenseJob {
	return &RecurringExpenseJob{repo: &recurringExpenseRepoImpl{db: db}, dispatcher: dispatcher, log: log}
}

func newRecurringExpenseJob(repo recurringExpenseRepo, push Pusher, log *logger.Logger) *RecurringExpenseJob {
	return &RecurringExpenseJob{repo: repo, push: push, log: log}
}

type recurringPushPayload struct {
	Title string                     `json:"title"`
	Body  string                     `json:"body"`
	Data  models.NotificationPayload `json:"data"`
}

// Run executes the recurring expense processing job.
func (j *RecurringExpenseJob) Run() {
	ctx := context.Background()
	j.log.Info().Msg("recurring expense job started")

	expenses, err := j.repo.ListDueRecurringExpenses(ctx)
	if err != nil {
		j.log.Error().Err(err).Msg("failed to list due recurring expenses")
		return
	}

	for _, re := range expenses {
		if err := j.processRecurringExpense(ctx, re); err != nil {
			j.log.Error().Err(err).Str("expense_id", re.ID.String()).Msg("failed to process recurring expense")
		}
	}
}

func (j *RecurringExpenseJob) processRecurringExpense(ctx context.Context, re models.RecurringExpense) error {
	now := time.Now().UTC()

	expenseID := uuid.New()
	expense := models.Expense{
		ID:          expenseID,
		GroupID:     re.GroupID,
		PayerID:     re.PayerID,
		Amount:      re.Amount,
		BaseAmount:  re.Amount, // recurring expenses are base-currency; fx_rate=1
		FxRate:      1,
		Description: re.Description,
		Category:    re.Category,
		Currency:    re.Currency,
		Date:        now,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	// Build splits: use stored split config when available, otherwise single payer split.
	splits := j.buildSplitsForRecurring(re, expenseID, now)

	nextDue, err := j.nextDueFromCron(re.Frequency, now)
	if err != nil {
		j.log.Warn().Err(err).Str("frequency", re.Frequency).Msg("invalid cron expression, using monthly fallback")
		nextDue = re.NextDue.AddDate(0, 1, 0)
	}
	if nextDue.Before(now) {
		nextDue = now.AddDate(0, 1, 0)
	}

	if err := j.repo.ProcessRecurringExpense(ctx, &expense, splits, re.ID, re.NextDue, nextDue); err != nil {
		return fmt.Errorf("process recurring expense: %w", err)
	}

	notifPayload := models.NotificationPayload{
		Screen:     models.ScreenRecurringExpenses,
		EntityType: models.EntityTypeRecurringExpense,
		ID:         re.ID.String(),
		GroupID:    re.GroupID.String(),
	}

	if j.dispatcher != nil {
		if err := j.dispatcher.DispatchToGroup(ctx, re.GroupID, uuid.Nil, "expense_created",
			"New Recurring Expense", re.Description+" has been added", notifPayload); err != nil {
			j.log.Warn().Err(err).Str("group_id", re.GroupID.String()).Msg("failed to dispatch recurring expense notification")
		}
	} else if j.push != nil {
		recurringPushPayload := recurringPushPayload{
			Title: "New Recurring Expense",
			Body:  re.Description + " has been added",
			Data:  notifPayload,
		}
		data, _ := json.Marshal(recurringPushPayload)
		if err := j.push.BroadcastToGroup(re.GroupID, string(data)); err != nil {
			j.log.Warn().Err(err).Str("group_id", re.GroupID.String()).Msg("failed to send recurring expense push")
		}
	}

	j.log.Info().
		Str("recurring_expense_id", re.ID.String()).
		Str("expense_id", expense.ID.String()).
		Time("next_due", nextDue).
		Msg("recurring expense processed")
	return nil
}

// buildSplitsForRecurring returns splits for a recurring expense materialisation.
// For legacy / payer_only rows it returns a single settled payer split.
// For configured split modes it delegates to BuildExpenseSplits with a fallback on error.
func (j *RecurringExpenseJob) buildSplitsForRecurring(re models.RecurringExpense, expenseID uuid.UUID, now time.Time) []models.Split {
	payerOnlySplit := []models.Split{{
		ID:        uuid.New(),
		ExpenseID: expenseID,
		UserID:    re.PayerID,
		Amount:    re.Amount,
		IsSettled: true,
		CreatedAt: now,
	}}

	if re.SplitMode == "" || re.SplitMode == "payer_only" || len(re.SplitInputs) == 0 {
		return payerOnlySplit
	}

	inputs := make([]services.ExpenseSplitInput, len(re.SplitInputs))
	for i, si := range re.SplitInputs {
		inputs[i] = services.ExpenseSplitInput{
			UserID:     si.UserID,
			Amount:     si.Amount,
			Shares:     si.Shares,
			Percentage: si.Percentage,
		}
	}

	builtSplits, err := services.BuildExpenseSplits(re.Amount, re.PayerID, re.SplitMode, inputs)
	if err != nil {
		j.log.Error().Err(err).
			Str("recurring_expense_id", re.ID.String()).
			Str("split_mode", re.SplitMode).
			Msg("split build failed for recurring expense; falling back to payer-only split")
		return payerOnlySplit
	}

	for i := range builtSplits {
		builtSplits[i].ID = uuid.New()
		builtSplits[i].ExpenseID = expenseID
		builtSplits[i].CreatedAt = now
	}
	return builtSplits
}

func (j *RecurringExpenseJob) nextDueFromCron(freq string, from time.Time) (time.Time, error) {
	switch strings.ToLower(strings.TrimSpace(freq)) {
	case "daily":
		return from.AddDate(0, 0, 1), nil
	case "weekly":
		return from.AddDate(0, 0, 7), nil
	case "biweekly":
		return from.AddDate(0, 0, 14), nil
	case "monthly":
		return from.AddDate(0, 1, 0), nil
	case "quarterly":
		return from.AddDate(0, 3, 0), nil
	case "yearly":
		return from.AddDate(1, 0, 0), nil
	}
	sched, err := cron.ParseStandard(freq)
	if err != nil {
		return time.Time{}, err
	}
	return sched.Next(from), nil
}

type recurringExpenseRepoImpl struct {
	db repositories.DBTX
}

func (r *recurringExpenseRepoImpl) ListDueRecurringExpenses(ctx context.Context) ([]models.RecurringExpense, error) {
	query := `
		SELECT id, group_id, payer_id, amount, description, category, currency, frequency, next_due, is_active, created_at,
		       COALESCE(split_mode, 'payer_only'), COALESCE(split_inputs, '[]'::jsonb)::text
		FROM recurring_expenses
		WHERE is_active = true AND next_due <= NOW()
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query due recurring expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.RecurringExpense
	for rows.Next() {
		var re models.RecurringExpense
		var splitInputsJSON string
		if err := rows.Scan(
			&re.ID, &re.GroupID, &re.PayerID, &re.Amount,
			&re.Description, &re.Category, &re.Currency,
			&re.Frequency, &re.NextDue, &re.IsActive, &re.CreatedAt,
			&re.SplitMode, &splitInputsJSON,
		); err != nil {
			return nil, fmt.Errorf("scan recurring expense: %w", err)
		}
		if err := json.Unmarshal([]byte(splitInputsJSON), &re.SplitInputs); err != nil {
			re.SplitInputs = []models.RecurringSplitInput{}
		}
		expenses = append(expenses, re)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return expenses, nil
}

func (r *recurringExpenseRepoImpl) ProcessRecurringExpense(ctx context.Context, expense *models.Expense, splits []models.Split, reID uuid.UUID, oldNextDue time.Time, nextDue time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO expenses (id, group_id, payer_id, amount, base_amount, fx_rate, description, category, currency, notes, date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
	`, expense.ID, expense.GroupID, expense.PayerID, expense.Amount, expense.BaseAmount, expense.FxRate, expense.Description, expense.Category, expense.Currency, "", expense.Date, expense.CreatedAt, expense.UpdatedAt)
	if err != nil {
		return fmt.Errorf("create expense: %w", err)
	}

	for i := range splits {
		s := &splits[i]
		_, err = tx.Exec(ctx, `
			INSERT INTO splits (id, expense_id, user_id, amount, is_settled, created_at)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, s.ID, s.ExpenseID, s.UserID, s.Amount, s.IsSettled, s.CreatedAt)
		if err != nil {
			return fmt.Errorf("create split: %w", err)
		}
	}

	res, err := tx.Exec(ctx, `
		UPDATE recurring_expenses
		SET next_due = $1, updated_at = NOW()
		WHERE id = $2 AND is_active = true AND next_due = $3
	`, nextDue, reID, oldNextDue)
	if err != nil {
		return fmt.Errorf("update recurring expense: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("recurring expense already processed or inactive")
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}
	return nil
}
