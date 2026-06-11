package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestFinanceRepo_CreateExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)

	e := &models.Expense{
		GroupID:     fixedUUID(),
		PayerID:     fixedUUID(),
		Amount:      1000,
		Description: "Dinner",
		Category:    "food",
		Currency:    "USD",
		Date:        fixedTime(),
	}

	mock.ExpectExec("INSERT INTO expenses").
		WithArgs(pgxmock.AnyArg(), e.GroupID, e.PayerID, e.Amount, e.Description, e.Category, e.Currency, e.Notes, e.Date, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateExpense(context.Background(), e)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, e.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetExpenseByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "payer_id", "amount", "description", "category", "currency", "notes", "date", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), 1000, "Dinner", "food", "USD", "", fixedTime(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM expenses WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	expense, err := repo.GetExpenseByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, expense.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetExpenseByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM expenses WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	expense, err := repo.GetExpenseByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, expense)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_ListExpensesByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	gid := fixedUUID()

	cols := []string{"id", "group_id", "payer_id", "amount", "description", "category", "currency", "notes", "date", "created_at", "updated_at"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), gid, fixedUUID(), 1000, "Dinner", "food", "USD", "", fixedTime(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM expenses WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	expenses, err := repo.ListExpensesByGroup(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, expenses, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE expenses SET").
		WithArgs(fixedUUID(), int64(2000), "Lunch", "food", "USD", "", fixedTime(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	e := &models.Expense{ID: id, PayerID: fixedUUID(), Amount: 2000, Description: "Lunch", Category: "food", Currency: "USD", Date: fixedTime()}
	err := repo.UpdateExpense(context.Background(), e)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateExpense_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE expenses SET").
		WithArgs(fixedUUID(), int64(2000), "Lunch", "food", "USD", "", fixedTime(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	e := &models.Expense{ID: id, PayerID: fixedUUID(), Amount: 2000, Description: "Lunch", Category: "food", Currency: "USD", Date: fixedTime()}
	err := repo.UpdateExpense(context.Background(), e)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM splits WHERE expense_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectExec("DELETE FROM expenses WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectCommit()

	err := repo.DeleteExpense(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteExpense_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM splits WHERE expense_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("DELETE FROM expenses WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectRollback()

	err := repo.DeleteExpense(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_CreateSplit(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)

	s := &models.Split{
		ExpenseID: fixedUUID(),
		UserID:    fixedUUID(),
		Amount:    500,
		IsSettled: false,
	}

	mock.ExpectExec("INSERT INTO splits").
		WithArgs(pgxmock.AnyArg(), s.ExpenseID, s.UserID, s.Amount, s.IsSettled, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateSplit(context.Background(), s)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, s.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_ListSplitsByExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	eid := fixedUUID()

	cols := []string{"id", "expense_id", "user_id", "amount", "is_settled", "created_at"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), eid, fixedUUID(), 500, false, fixedTime())

	mock.ExpectQuery("SELECT .* FROM splits WHERE expense_id = .*").
		WithArgs(eid).
		WillReturnRows(rows)

	splits, err := repo.ListSplitsByExpense(context.Background(), eid)
	require.NoError(t, err)
	assert.Len(t, splits, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateSplit(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE splits SET").
		WithArgs(fixedUUID(), int64(300), true, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	s := &models.Split{ID: id, UserID: fixedUUID(), Amount: 300, IsSettled: true}
	err := repo.UpdateSplit(context.Background(), s)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateSplit_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE splits SET").
		WithArgs(fixedUUID(), int64(300), true, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	s := &models.Split{ID: id, UserID: fixedUUID(), Amount: 300, IsSettled: true}
	err := repo.UpdateSplit(context.Background(), s)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteSplit(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM splits WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteSplit(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteSplit_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM splits WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteSplit(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_CreateSettlement(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)

	s := &models.Settlement{
		GroupID:    fixedUUID(),
		FromUserID: fixedUUID(),
		ToUserID:   fixedUUID(),
		Amount:     500,
	}

	mock.ExpectBegin()
	mock.ExpectExec("SELECT id FROM settlements WHERE group_id = .* FOR UPDATE").
		WithArgs(s.GroupID).
		WillReturnResult(pgxmock.NewResult("SELECT", 0))
	mock.ExpectExec("INSERT INTO settlements").
		WithArgs(pgxmock.AnyArg(), s.GroupID, s.FromUserID, s.ToUserID, s.Amount, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	err := repo.CreateSettlement(context.Background(), s)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, s.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_ListSettlementsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	gid := fixedUUID()

	cols := []string{"id", "group_id", "from_user_id", "to_user_id", "amount", "created_at"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), gid, fixedUUID(), fixedUUID(), 500, fixedTime())

	mock.ExpectQuery("SELECT .* FROM settlements WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	settlements, err := repo.ListSettlementsByGroup(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, settlements, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteSettlement(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM settlements WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteSettlement(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteSettlement_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM settlements WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteSettlement(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_CreateRecurringExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)

	re := &models.RecurringExpense{
		GroupID:     fixedUUID(),
		PayerID:     fixedUUID(),
		Amount:      1000,
		Description: "Rent",
		Category:    "housing",
		Frequency:   "monthly",
		NextDue:     fixedTime(),
		IsActive:    true,
	}

	mock.ExpectExec("INSERT INTO recurring_expenses").
		WithArgs(pgxmock.AnyArg(), re.GroupID, re.PayerID, re.Amount, re.Description, re.Category, re.Currency, re.Frequency, re.NextDue, re.IsActive, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateRecurringExpense(context.Background(), re)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, re.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetRecurringExpenseByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "payer_id", "amount", "description", "category", "currency", "frequency", "next_due", "is_active", "created_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), 1000, "Rent", "housing", "USD", "monthly", fixedTime(), true, fixedTime())

	mock.ExpectQuery("SELECT .* FROM recurring_expenses WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	re, err := repo.GetRecurringExpenseByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, re.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetRecurringExpenseByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM recurring_expenses WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	re, err := repo.GetRecurringExpenseByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, re)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_ListRecurringExpenses(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	gid := fixedUUID()

	cols := []string{"id", "group_id", "payer_id", "amount", "description", "category", "frequency", "next_due", "is_active", "created_at", "currency"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), gid, fixedUUID(), 1000, "Rent", "housing", "monthly", fixedTime(), true, fixedTime(), "USD")

	mock.ExpectQuery("SELECT .* FROM recurring_expenses WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	expenses, err := repo.ListRecurringExpenses(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, expenses, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateRecurringExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recurring_expenses SET").
		WithArgs(fixedUUID(), int64(2000), "New Rent", "housing", "USD", "monthly", fixedTime(), true, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	re := &models.RecurringExpense{ID: id, PayerID: fixedUUID(), Amount: 2000, Description: "New Rent", Category: "housing", Currency: "USD", Frequency: "monthly", NextDue: fixedTime(), IsActive: true}
	err := repo.UpdateRecurringExpense(context.Background(), re)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_UpdateRecurringExpense_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recurring_expenses SET").
		WithArgs(fixedUUID(), int64(2000), "New Rent", "housing", "USD", "monthly", fixedTime(), true, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	re := &models.RecurringExpense{ID: id, PayerID: fixedUUID(), Amount: 2000, Description: "New Rent", Category: "housing", Currency: "USD", Frequency: "monthly", NextDue: fixedTime(), IsActive: true}
	err := repo.UpdateRecurringExpense(context.Background(), re)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteRecurringExpense(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recurring_expenses WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteRecurringExpense(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_DeleteRecurringExpense_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recurring_expenses WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteRecurringExpense(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetSplitByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "expense_id", "user_id", "amount", "is_settled", "created_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), 500, false, fixedTime())

	mock.ExpectQuery("SELECT .* FROM splits WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	s, err := repo.GetSplitByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, s.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetSplitByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM splits WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	s, err := repo.GetSplitByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, s)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetSettlementByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "from_user_id", "to_user_id", "amount", "created_at"}).
		AddRow(id, fixedUUID(), fixedUUID(), fixedUUID(), 500, fixedTime())

	mock.ExpectQuery("SELECT .* FROM settlements WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	s, err := repo.GetSettlementByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, s.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetSettlementByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM settlements WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	s, err := repo.GetSettlementByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, s)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_GetGroupBalanceAggregates(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)
	gid := fixedUUID()

	userA := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	userB := uuid.MustParse("00000000-0000-0000-0000-000000000002")

	cols := []string{"user_id", "expense_paid", "split_owed", "settled_out", "settled_in"}
	rows := pgxmock.NewRows(cols).
		AddRow(userA, int64(10000), int64(5000), int64(0), int64(0)).
		AddRow(userB, int64(0), int64(5000), int64(0), int64(0))

	mock.ExpectQuery("WITH all_users AS").
		WithArgs(gid).
		WillReturnRows(rows)

	aggregates, err := repo.GetGroupBalanceAggregates(context.Background(), gid)
	require.NoError(t, err)
	require.Len(t, aggregates, 2)
	assert.Equal(t, userA, aggregates[0].UserID)
	assert.Equal(t, int64(10000), aggregates[0].ExpensePaid)
	assert.Equal(t, int64(5000), aggregates[0].SplitOwed)
	assert.Equal(t, userB, aggregates[1].UserID)
	assert.Equal(t, int64(0), aggregates[1].ExpensePaid)
	assert.Equal(t, int64(5000), aggregates[1].SplitOwed)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestFinanceRepo_CreateExpenseWithSplits(t *testing.T) {
	mock := newMockDB(t)
	repo := NewFinanceRepo(mock)

	e := &models.Expense{
		GroupID:     fixedUUID(),
		PayerID:     fixedUUID(),
		Amount:      1000,
		Description: "Dinner",
		Category:    "food",
		Currency:    "USD",
		Date:        fixedTime(),
	}
	splits := []models.Split{
		{UserID: fixedUUID(), Amount: 500, IsSettled: false},
		{UserID: fixedUUID(), Amount: 500, IsSettled: false},
	}

	mock.ExpectBegin()
	mock.ExpectExec("INSERT INTO expenses").
		WithArgs(pgxmock.AnyArg(), e.GroupID, e.PayerID, e.Amount, e.Description, e.Category, e.Currency, e.Notes, e.Date, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("INSERT INTO splits").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), splits[0].UserID, splits[0].Amount, splits[0].IsSettled, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("INSERT INTO splits").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), splits[1].UserID, splits[1].Amount, splits[1].IsSettled, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	err := repo.CreateExpenseWithSplits(context.Background(), e, splits)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, e.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}
