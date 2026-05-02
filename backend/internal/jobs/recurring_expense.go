package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/robfig/cron/v3"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// RecurringExpenseJob processes due recurring expenses by creating expense
// copies with auto-settled payer splits and advancing the next due date.
// Run hourly.
type RecurringExpenseJob struct {
	repo recurringExpenseRepo
	push Pusher
	log  *logger.Logger
}

// NewRecurringExpenseJob creates a new RecurringExpenseJob.
func NewRecurringExpenseJob(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *RecurringExpenseJob {
	return &RecurringExpenseJob{repo: &recurringExpenseRepoImpl{pool: pool}, push: push, log: log}
}

func newRecurringExpenseJob(repo recurringExpenseRepo, push Pusher, log *logger.Logger) *RecurringExpenseJob {
	return &RecurringExpenseJob{repo: repo, push: push, log: log}
}

type recurringPushPayload struct {
	Title string                 `json:"title"`
	Body  string                 `json:"body"`
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

	expense := models.Expense{
		ID:          uuid.New(),
		GroupID:     re.GroupID,
		PayerID:     re.PayerID,
		Amount:      re.Amount,
		Description: re.Description,
		Category:    re.Category,
		Currency:    re.Currency,
		Date:        now,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	split := models.Split{
		ID:        uuid.New(),
		ExpenseID: expense.ID,
		UserID:    re.PayerID,
		Amount:    re.Amount,
		IsSettled: true,
		CreatedAt: now,
	}

	nextDue, err := j.nextDueFromCron(re.Frequency, now)
	if err != nil {
		j.log.Warn().Err(err).Str("frequency", re.Frequency).Msg("invalid cron expression, using monthly fallback")
		nextDue = re.NextDue.AddDate(0, 1, 0)
	}

	if err := j.repo.ProcessRecurringExpense(ctx, &expense, &split, re.ID, re.NextDue, nextDue); err != nil {
		return fmt.Errorf("process recurring expense: %w", err)
	}

	recurringPushPayload := recurringPushPayload{
		Title: "New Recurring Expense",
		Body:  re.Description + " has been added",
		Data: models.NotificationPayload{
			Screen:     models.ScreenRecurringExpenses,
			EntityType: models.EntityTypeRecurringExpense,
			ID:         re.ID.String(),
			GroupID:    re.GroupID.String(),
		},
	}
	data, _ := json.Marshal(recurringPushPayload)
	if err := j.push.BroadcastToGroup(re.GroupID, string(data)); err != nil {
		j.log.Warn().Err(err).Str("group_id", re.GroupID.String()).Msg("failed to send recurring expense push")
	}

	j.log.Info().
		Str("recurring_expense_id", re.ID.String()).
		Str("expense_id", expense.ID.String()).
		Time("next_due", nextDue).
		Msg("recurring expense processed")
	return nil
}

func (j *RecurringExpenseJob) nextDueFromCron(freq string, from time.Time) (time.Time, error) {
	sched, err := cron.ParseStandard(freq)
	if err != nil {
		return time.Time{}, err
	}
	return sched.Next(from), nil
}

type recurringExpenseRepoImpl struct {
	pool *pgxpool.Pool
}

func (r *recurringExpenseRepoImpl) ListDueRecurringExpenses(ctx context.Context) ([]models.RecurringExpense, error) {
	query := `
		SELECT id, group_id, payer_id, amount, description, category, currency, frequency, next_due, is_active, created_at
		FROM recurring_expenses
		WHERE is_active = true AND next_due <= NOW()
	`
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query due recurring expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.RecurringExpense
	for rows.Next() {
		var re models.RecurringExpense
		if err := rows.Scan(
			&re.ID, &re.GroupID, &re.PayerID, &re.Amount,
			&re.Description, &re.Category, &re.Currency,
			&re.Frequency, &re.NextDue, &re.IsActive, &re.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan recurring expense: %w", err)
		}
		expenses = append(expenses, re)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return expenses, nil
}

func (r *recurringExpenseRepoImpl) ProcessRecurringExpense(ctx context.Context, expense *models.Expense, split *models.Split, reID uuid.UUID, oldNextDue time.Time, nextDue time.Time) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO expenses (id, group_id, payer_id, amount, description, category, currency, date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, expense.ID, expense.GroupID, expense.PayerID, expense.Amount, expense.Description, expense.Category, expense.Currency, expense.Date, expense.CreatedAt, expense.UpdatedAt)
	if err != nil {
		return fmt.Errorf("create expense: %w", err)
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO splits (id, expense_id, user_id, amount, is_settled, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, split.ID, split.ExpenseID, split.UserID, split.Amount, split.IsSettled, split.CreatedAt)
	if err != nil {
		return fmt.Errorf("create split: %w", err)
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
