package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func TestFinanceService_CreateExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	payerID := uuid.New()

	t.Run("success with equal splits as admin", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		financeRepo.On("CreateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).Return(nil)

		splitUserIDs := []uuid.UUID{userID, payerID}
		expense := &models.Expense{GroupID: groupID, PayerID: payerID, Amount: 100, Currency: "USD"}
		err := svc.CreateExpense(ctx, userID, expense, splitUserIDs)
		require.NoError(t, err)
	})

	t.Run("success with own payer as member", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).Return(nil)

		expense := &models.Expense{GroupID: groupID, PayerID: userID, Amount: 100, Currency: "USD"}
		err := svc.CreateExpense(ctx, userID, expense, nil)
		require.NoError(t, err)
	})

	t.Run("member cannot set different payer", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		expense := &models.Expense{GroupID: groupID, PayerID: payerID, Amount: 100, Currency: "USD"}
		err := svc.CreateExpense(ctx, userID, expense, nil)
		require.Error(t, err)
	})

	t.Run("invalid amount", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		err := svc.CreateExpense(ctx, userID, &models.Expense{GroupID: groupID, PayerID: userID, Amount: 0, Currency: "USD"}, nil)
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("permission denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		err := svc.CreateExpense(ctx, userID, &models.Expense{GroupID: groupID, PayerID: userID, Amount: 100, Currency: "USD"}, nil)
		require.Error(t, err)
		assert.Equal(t, api.ErrPermissionDenied, err)
	})
}

func TestFinanceService_GetExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	expenseID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(&models.Expense{ID: expenseID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		expense, err := svc.GetExpense(ctx, userID, expenseID)
		require.NoError(t, err)
		assert.Equal(t, expenseID, expense.ID)
	})

	t.Run("not found", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		svc := NewFinanceService(financeRepo, nil)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(nil, errors.New("expense not found"))

		_, err := svc.GetExpense(ctx, userID, expenseID)
		require.Error(t, err)
		assert.Equal(t, api.ErrNotFound, err)
	})
}

func TestFinanceService_DeleteExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	expenseID := uuid.New()
	groupID := uuid.New()

	t.Run("success admin", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(&models.Expense{ID: expenseID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		financeRepo.On("DeleteExpense", ctx, expenseID).Return(nil)

		err := svc.DeleteExpense(ctx, userID, expenseID)
		require.NoError(t, err)
	})

	t.Run("member cannot delete", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(&models.Expense{ID: expenseID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		err := svc.DeleteExpense(ctx, userID, expenseID)
		require.Error(t, err)
		assert.Equal(t, api.ErrPermissionDenied, err)
	})
}

func TestFinanceService_CreateSplit(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	expenseID := uuid.New()
	groupID := uuid.New()
	payerID := uuid.New()

	t.Run("success auto-settles payer", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(&models.Expense{ID: expenseID, GroupID: groupID, PayerID: payerID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateSplit", ctx, mock.AnythingOfType("*models.Split")).Return(nil)

		split := &models.Split{ExpenseID: expenseID, UserID: payerID, Amount: 50}
		err := svc.CreateSplit(ctx, userID, split)
		require.NoError(t, err)
		assert.True(t, split.IsSettled)
	})
}

func TestFinanceService_CreateSettlement(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateSettlement", ctx, mock.AnythingOfType("*models.Settlement")).Return(nil)

		settlement := &models.Settlement{GroupID: groupID, Amount: 100}
		err := svc.CreateSettlement(ctx, userID, settlement)
		require.NoError(t, err)
	})

	t.Run("invalid amount", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		err := svc.CreateSettlement(ctx, userID, &models.Settlement{GroupID: groupID, Amount: 0})
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})
}

func TestFinanceService_CreateRecurringExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateRecurringExpense", ctx, mock.AnythingOfType("*models.RecurringExpense")).Return(nil)

		re := &models.RecurringExpense{GroupID: groupID, Amount: 100}
		err := svc.CreateRecurringExpense(ctx, userID, re)
		require.NoError(t, err)
	})
}

func TestFinanceService_DeleteRecurringExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	reID := uuid.New()
	groupID := uuid.New()

	t.Run("success admin", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(&models.RecurringExpense{ID: reID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		financeRepo.On("DeleteRecurringExpense", ctx, reID).Return(nil)

		err := svc.DeleteRecurringExpense(ctx, userID, reID)
		require.NoError(t, err)
	})
}
