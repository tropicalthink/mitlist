package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/mitlist-app/mitlist/internal/models"
)

// MockFinanceRepo is a mock implementation of repositories.FinanceRepoIface.
type MockFinanceRepo struct {
	mock.Mock
}

func (m *MockFinanceRepo) CreateExpense(ctx context.Context, e *models.Expense) error {
	args := m.Called(ctx, e)
	return args.Error(0)
}

func (m *MockFinanceRepo) GetExpenseByID(ctx context.Context, id uuid.UUID) (*models.Expense, error) {
	args := m.Called(ctx, id)
	if e := args.Get(0); e != nil {
		return e.(*models.Expense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListExpensesByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Expense, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if e := args.Get(0); e != nil {
		return e.([]models.Expense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListAllExpensesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Expense, error) {
	args := m.Called(ctx, groupID)
	if e := args.Get(0); e != nil {
		return e.([]models.Expense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) UpdateExpense(ctx context.Context, e *models.Expense) error {
	args := m.Called(ctx, e)
	return args.Error(0)
}

func (m *MockFinanceRepo) DeleteExpense(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockFinanceRepo) CreateSplit(ctx context.Context, s *models.Split) error {
	args := m.Called(ctx, s)
	return args.Error(0)
}

func (m *MockFinanceRepo) ListSplitsByExpense(ctx context.Context, expenseID uuid.UUID) ([]models.Split, error) {
	args := m.Called(ctx, expenseID)
	if s := args.Get(0); s != nil {
		return s.([]models.Split), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListSplitsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Split, error) {
	args := m.Called(ctx, groupID)
	if s := args.Get(0); s != nil {
		return s.([]models.Split), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) UpdateSplit(ctx context.Context, s *models.Split) error {
	args := m.Called(ctx, s)
	return args.Error(0)
}

func (m *MockFinanceRepo) DeleteSplit(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockFinanceRepo) CreateSettlement(ctx context.Context, s *models.Settlement) error {
	args := m.Called(ctx, s)
	return args.Error(0)
}

func (m *MockFinanceRepo) ListSettlementsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Settlement, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if s := args.Get(0); s != nil {
		return s.([]models.Settlement), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListAllSettlementsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Settlement, error) {
	args := m.Called(ctx, groupID)
	if s := args.Get(0); s != nil {
		return s.([]models.Settlement), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) DeleteSettlement(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockFinanceRepo) CreateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error {
	args := m.Called(ctx, re)
	return args.Error(0)
}

func (m *MockFinanceRepo) GetRecurringExpenseByID(ctx context.Context, id uuid.UUID) (*models.RecurringExpense, error) {
	args := m.Called(ctx, id)
	if re := args.Get(0); re != nil {
		return re.(*models.RecurringExpense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListRecurringExpenses(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.RecurringExpense, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if re := args.Get(0); re != nil {
		return re.([]models.RecurringExpense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) ListRecurringExpensesByDateRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.RecurringExpense, error) {
	args := m.Called(ctx, groupID, from, to)
	if re := args.Get(0); re != nil {
		return re.([]models.RecurringExpense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) UpdateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error {
	args := m.Called(ctx, re)
	return args.Error(0)
}

func (m *MockFinanceRepo) DeleteRecurringExpense(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockFinanceRepo) GetSplitByID(ctx context.Context, id uuid.UUID) (*models.Split, error) {
	args := m.Called(ctx, id)
	if s := args.Get(0); s != nil {
		return s.(*models.Split), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) GetSettlementByID(ctx context.Context, id uuid.UUID) (*models.Settlement, error) {
	args := m.Called(ctx, id)
	if s := args.Get(0); s != nil {
		return s.(*models.Settlement), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockFinanceRepo) CreateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error {
	args := m.Called(ctx, e, splits)
	return args.Error(0)
}
