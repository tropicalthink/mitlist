package services

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
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
		groupRepo.On("GetMembership", ctx, groupID, payerID).Return(&models.GroupMembership{Role: "member"}, nil)
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
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
	})
}

func TestBuildSplitsAdvancedModes(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")

	t.Run("exact amounts must match total", func(t *testing.T) {
		splits, err := buildSplits(1000, payerID, "amount", []ExpenseSplitInput{
			{UserID: payerID, Amount: 250},
			{UserID: secondID, Amount: 750},
		})
		require.NoError(t, err)
		require.Len(t, splits, 2)
		assert.Equal(t, int64(250), splits[0].Amount)
		assert.True(t, splits[0].IsSettled)
		assert.Equal(t, int64(750), splits[1].Amount)
	})

	t.Run("shares distribute deterministic remainder", func(t *testing.T) {
		splits, err := buildSplits(100, payerID, "shares", []ExpenseSplitInput{
			{UserID: thirdID, Shares: 1},
			{UserID: payerID, Shares: 1},
			{UserID: secondID, Shares: 1},
		})
		require.NoError(t, err)
		require.Len(t, splits, 3)
		assert.Equal(t, []int64{33, 33, 34}, []int64{splits[0].Amount, splits[1].Amount, splits[2].Amount})
		assert.Equal(t, payerID, splits[0].UserID)
		assert.True(t, splits[0].IsSettled)
	})

	t.Run("percentage must total one hundred percent", func(t *testing.T) {
		_, err := buildSplits(1000, payerID, "percentage", []ExpenseSplitInput{
			{UserID: payerID, Percentage: 5000},
			{UserID: secondID, Percentage: 4999},
		})
		require.Error(t, err)
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

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(nil, fmt.Errorf("expense not found: %w", pgx.ErrNoRows))

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
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
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
		fromUserID := uuid.New()
		toUserID := uuid.New()

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, fromUserID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, toUserID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateSettlement", ctx, mock.AnythingOfType("*models.Settlement")).Return(nil)

		settlement := &models.Settlement{GroupID: groupID, FromUserID: fromUserID, ToUserID: toUserID, Amount: 100}
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

func TestFinanceService_GetFinanceSummary(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")
	expenseID := uuid.New()

	financeRepo := new(mocks.MockFinanceRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewFinanceService(financeRepo, groupRepo)

	groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
	financeRepo.On("ListAllExpensesByGroup", ctx, groupID).Return([]models.Expense{
		{ID: expenseID, GroupID: groupID, PayerID: payerID, Amount: 10001},
	}, nil)
	financeRepo.On("ListSplitsByGroup", ctx, groupID).Return([]models.Split{
		{ExpenseID: expenseID, UserID: payerID, Amount: 3334, IsSettled: true},
		{ExpenseID: expenseID, UserID: secondID, Amount: 3334},
		{ExpenseID: expenseID, UserID: thirdID, Amount: 3333},
	}, nil)
	financeRepo.On("ListAllSettlementsByGroup", ctx, groupID).Return([]models.Settlement{
		{GroupID: groupID, FromUserID: secondID, ToUserID: payerID, Amount: 1000},
	}, nil)
	groupRepo.On("ListMemberProfilesByGroup", ctx, groupID).Return([]models.GroupMemberProfile{
		{UserID: payerID, DisplayName: "Ada Lovelace", Role: "member"},
		{UserID: secondID, DisplayName: "Grace Hopper", Role: "member"},
		{UserID: thirdID, DisplayName: "Katherine Johnson", Role: "member"},
	}, nil)

	summary, err := svc.GetFinanceSummary(ctx, userID, groupID)
	require.NoError(t, err)

	assert.Equal(t, []models.BalanceEntry{
		{UserID: payerID, DisplayName: "Ada Lovelace", Paid: 10001, Owed: 4334, Total: 5667},
		{UserID: secondID, DisplayName: "Grace Hopper", Paid: 1000, Owed: 3334, Total: -2334},
		{UserID: thirdID, DisplayName: "Katherine Johnson", Paid: 0, Owed: 3333, Total: -3333},
	}, summary.Balances)
	assert.Equal(t, []models.ReimbursementSuggestion{
		{FromUserID: thirdID, FromDisplayName: "Katherine Johnson", ToUserID: payerID, ToDisplayName: "Ada Lovelace", Amount: 3333},
		{FromUserID: secondID, FromDisplayName: "Grace Hopper", ToUserID: payerID, ToDisplayName: "Ada Lovelace", Amount: 2334},
	}, summary.Reimbursements)
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
