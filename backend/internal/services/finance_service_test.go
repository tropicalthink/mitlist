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
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
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
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
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

func TestCreateExpense_ForeignCurrencyConvertsToBase(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("foreign currency converts amount to base at fx rate", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)

		var captured *models.Expense
		var capturedSplits []models.Split
		financeRepo.On("CreateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).
			Run(func(args mock.Arguments) {
				captured = args.Get(1).(*models.Expense)
				capturedSplits = args.Get(2).([]models.Split)
			}).Return(nil)

		expense := &models.Expense{GroupID: groupID, PayerID: userID, Amount: 5000, Currency: "EUR", FxRate: 1.10}
		err := svc.CreateExpense(ctx, userID, expense, []uuid.UUID{userID})
		require.NoError(t, err)
		require.NotNil(t, captured)
		assert.Equal(t, int64(5500), captured.BaseAmount)
		assert.InDelta(t, 1.10, captured.FxRate, 1e-9)

		var sum int64
		for _, s := range capturedSplits {
			sum += s.Amount
		}
		assert.Equal(t, int64(5500), sum, "split shares must sum to base amount")
	})

	t.Run("foreign currency with non-positive fx rate is rejected", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)

		expense := &models.Expense{GroupID: groupID, PayerID: userID, Amount: 5000, Currency: "EUR", FxRate: 0}
		err := svc.CreateExpense(ctx, userID, expense, []uuid.UUID{userID})
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("same-currency expense forces fx rate 1 and base equals amount", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)

		var captured *models.Expense
		financeRepo.On("CreateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).
			Run(func(args mock.Arguments) {
				captured = args.Get(1).(*models.Expense)
			}).Return(nil)

		// A bogus rate is passed in but must be ignored for same-currency expenses.
		expense := &models.Expense{GroupID: groupID, PayerID: userID, Amount: 5000, Currency: "USD", FxRate: 2.5}
		err := svc.CreateExpense(ctx, userID, expense, []uuid.UUID{userID})
		require.NoError(t, err)
		require.NotNil(t, captured)
		assert.Equal(t, int64(5000), captured.BaseAmount)
		assert.InDelta(t, 1.0, captured.FxRate, 1e-9)
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

	financeRepo := new(mocks.MockFinanceRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewFinanceService(financeRepo, groupRepo)

	groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
	// Derived from the original fixture by hand:
	//   payerID:   ExpensePaid=10001, SplitOwed=3334, SettledOut=0,    SettledIn=1000
	//              → Paid=10001, Owed=4334, Total=5667
	//   secondID:  ExpensePaid=0,     SplitOwed=3334, SettledOut=1000, SettledIn=0
	//              → Paid=1000,  Owed=3334, Total=-2334
	//   thirdID:   ExpensePaid=0,     SplitOwed=3333, SettledOut=0,    SettledIn=0
	//              → Paid=0,     Owed=3333, Total=-3333
	financeRepo.On("GetGroupBalanceAggregates", ctx, groupID).Return([]models.BalanceAggregate{
		{UserID: payerID, ExpensePaid: 10001, SplitOwed: 3334, SettledOut: 0, SettledIn: 1000},
		{UserID: secondID, ExpensePaid: 0, SplitOwed: 3334, SettledOut: 1000, SettledIn: 0},
		{UserID: thirdID, ExpensePaid: 0, SplitOwed: 3333, SettledOut: 0, SettledIn: 0},
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

// ---------------------------------------------------------------------------
// Step 1: buildSplits edge cases
// ---------------------------------------------------------------------------

func TestBuildSplitsEqualMode(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")

	t.Run("100/3 sums to 100 with one extra cent", func(t *testing.T) {
		splits, err := buildSplits(100, payerID, "equal", []ExpenseSplitInput{
			{UserID: payerID},
			{UserID: secondID},
			{UserID: thirdID},
		})
		require.NoError(t, err)
		require.Len(t, splits, 3)
		var total int64
		for _, s := range splits {
			total += s.Amount
		}
		assert.Equal(t, int64(100), total, "amounts must sum to total")
		// Sorted by UUID string; payerID < secondID < thirdID, so first gets extra cent.
		amounts := []int64{splits[0].Amount, splits[1].Amount, splits[2].Amount}
		assert.Equal(t, []int64{34, 33, 33}, amounts)
	})

	t.Run("100/7 sums to 100", func(t *testing.T) {
		ids := make([]ExpenseSplitInput, 7)
		for i := range ids {
			ids[i] = ExpenseSplitInput{UserID: uuid.New()}
		}
		splits, err := buildSplits(100, ids[0].UserID, "equal", ids)
		require.NoError(t, err)
		require.Len(t, splits, 7)
		var total int64
		for _, s := range splits {
			total += s.Amount
		}
		assert.Equal(t, int64(100), total)
	})

	t.Run("1/2 — one participant gets 0 cent (finding: zero split produced)", func(t *testing.T) {
		splits, err := buildSplits(1, payerID, "equal", []ExpenseSplitInput{
			{UserID: payerID},
			{UserID: secondID},
		})
		require.NoError(t, err)
		require.Len(t, splits, 2)
		var total int64
		for _, s := range splits {
			total += s.Amount
		}
		assert.Equal(t, int64(1), total, "amounts must sum to 1")
		// One split will be 0. Record this as a known behavior (not necessarily a bug,
		// but callers should filter zero-amount splits before display).
		amounts := []int64{splits[0].Amount, splits[1].Amount}
		assert.Contains(t, amounts, int64(0), "a zero-amount split is produced for 1/2")
		assert.Contains(t, amounts, int64(1))
	})

	t.Run("single participant gets 100%", func(t *testing.T) {
		splits, err := buildSplits(500, payerID, "equal", []ExpenseSplitInput{
			{UserID: payerID},
		})
		require.NoError(t, err)
		require.Len(t, splits, 1)
		assert.Equal(t, int64(500), splits[0].Amount)
		assert.True(t, splits[0].IsSettled, "payer is always settled")
	})

	t.Run("payer-in-inputs gets IsSettled true", func(t *testing.T) {
		splits, err := buildSplits(90, payerID, "equal", []ExpenseSplitInput{
			{UserID: payerID},
			{UserID: secondID},
			{UserID: thirdID},
		})
		require.NoError(t, err)
		payerFound := false
		for _, s := range splits {
			if s.UserID == payerID {
				assert.True(t, s.IsSettled)
				payerFound = true
			} else {
				assert.False(t, s.IsSettled)
			}
		}
		assert.True(t, payerFound)
	})
}

func TestBuildSplitsExactMode(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")

	t.Run("amounts not summing to total returns error", func(t *testing.T) {
		_, err := buildSplits(1000, payerID, "amount", []ExpenseSplitInput{
			{UserID: payerID, Amount: 400},
			{UserID: secondID, Amount: 400},
		})
		require.Error(t, err)
	})

	t.Run("amount <= 0 returns error", func(t *testing.T) {
		_, err := buildSplits(1000, payerID, "exact", []ExpenseSplitInput{
			{UserID: payerID, Amount: 0},
			{UserID: secondID, Amount: 1000},
		})
		require.Error(t, err)
	})
}

func TestBuildSplitsPercentageMode(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")

	t.Run("percentages not summing to 10000 basis points returns error", func(t *testing.T) {
		_, err := buildSplits(1000, payerID, "percentage", []ExpenseSplitInput{
			{UserID: payerID, Percentage: 5000},
			{UserID: secondID, Percentage: 4998}, // 9998, not 10000
		})
		require.Error(t, err)
	})

	t.Run("valid 50/50 percentage split", func(t *testing.T) {
		splits, err := buildSplits(1000, payerID, "percentage", []ExpenseSplitInput{
			{UserID: payerID, Percentage: 5000},
			{UserID: secondID, Percentage: 5000},
		})
		require.NoError(t, err)
		require.Len(t, splits, 2)
		var total int64
		for _, s := range splits {
			total += s.Amount
		}
		assert.Equal(t, int64(1000), total)
	})
}

func TestBuildSplitsSharesMode(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")

	t.Run("3 users shares 1/1/2 on 100 sums to 100", func(t *testing.T) {
		splits, err := buildSplits(100, payerID, "shares", []ExpenseSplitInput{
			{UserID: payerID, Shares: 2},
			{UserID: secondID, Shares: 1},
			{UserID: thirdID, Shares: 1},
		})
		require.NoError(t, err)
		require.Len(t, splits, 3)
		var total int64
		for _, s := range splits {
			total += s.Amount
		}
		assert.Equal(t, int64(100), total)
	})
}

// ---------------------------------------------------------------------------
// Step 2: calculateBalances and suggestReimbursements characterization
// ---------------------------------------------------------------------------

func TestCalculateBalances(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	expenseID := uuid.New()

	t.Run("two users one 100 expense split equally", func(t *testing.T) {
		expenses := []models.Expense{
			{ID: expenseID, PayerID: payerID, Amount: 100, BaseAmount: 100},
		}
		splits := []models.Split{
			{ExpenseID: expenseID, UserID: payerID, Amount: 50, IsSettled: true},
			{ExpenseID: expenseID, UserID: secondID, Amount: 50},
		}
		balances := calculateBalances(expenses, splits, nil)

		require.Len(t, balances, 2)
		// Sorted by UUID string; payerID < secondID
		payer := balances[0]
		second := balances[1]
		assert.Equal(t, payerID, payer.UserID)
		assert.Equal(t, int64(100), payer.Paid)
		assert.Equal(t, int64(50), payer.Owed)
		assert.Equal(t, int64(50), payer.Total)

		assert.Equal(t, secondID, second.UserID)
		assert.Equal(t, int64(0), second.Paid)
		assert.Equal(t, int64(50), second.Owed)
		assert.Equal(t, int64(-50), second.Total)

		// Balances must sum to zero across group.
		var sum int64
		for _, b := range balances {
			sum += b.Total
		}
		assert.Equal(t, int64(0), sum, "group totals must net to zero")
	})

	t.Run("settlement of 50 adjusts balances correctly", func(t *testing.T) {
		expenses := []models.Expense{
			{ID: expenseID, PayerID: payerID, Amount: 100, BaseAmount: 100},
		}
		splits := []models.Split{
			{ExpenseID: expenseID, UserID: payerID, Amount: 50, IsSettled: true},
			{ExpenseID: expenseID, UserID: secondID, Amount: 50},
		}
		settlements := []models.Settlement{
			{FromUserID: secondID, ToUserID: payerID, Amount: 50},
		}
		balances := calculateBalances(expenses, splits, settlements)

		require.Len(t, balances, 2)
		payer := balances[0]
		second := balances[1]
		// After settlement: payer paid 100, owed 50+50=100 → total 0
		assert.Equal(t, int64(0), payer.Total, "payer should be zeroed out after settlement")
		// second paid 50 (settlement), owed 50 → total 0
		assert.Equal(t, int64(0), second.Total, "debtor should be zeroed out after settlement")
	})

	t.Run("settled splits still create Owed debt", func(t *testing.T) {
		// IsSettled on a split does NOT affect balance calculation — it's a display flag.
		// This test pins current behavior.
		expenses := []models.Expense{
			{ID: expenseID, PayerID: payerID, Amount: 100, BaseAmount: 100},
		}
		splits := []models.Split{
			{ExpenseID: expenseID, UserID: secondID, Amount: 100, IsSettled: true},
		}
		balances := calculateBalances(expenses, splits, nil)
		require.Len(t, balances, 2)
		var second *models.BalanceEntry
		for i := range balances {
			if balances[i].UserID == secondID {
				second = &balances[i]
			}
		}
		require.NotNil(t, second)
		// IsSettled flag on the split does not affect calculateBalances — Owed is still counted.
		assert.Equal(t, int64(100), second.Owed, "IsSettled on split does not zero Owed in calculateBalances")
	})

	t.Run("three users circular balances sum to zero", func(t *testing.T) {
		thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")
		exp2ID := uuid.New()
		expenses := []models.Expense{
			{ID: expenseID, PayerID: payerID, Amount: 90, BaseAmount: 90},
			{ID: exp2ID, PayerID: secondID, Amount: 60, BaseAmount: 60},
		}
		splits := []models.Split{
			{ExpenseID: expenseID, UserID: payerID, Amount: 30, IsSettled: true},
			{ExpenseID: expenseID, UserID: secondID, Amount: 30},
			{ExpenseID: expenseID, UserID: thirdID, Amount: 30},
			{ExpenseID: exp2ID, UserID: secondID, Amount: 20, IsSettled: true},
			{ExpenseID: exp2ID, UserID: payerID, Amount: 20},
			{ExpenseID: exp2ID, UserID: thirdID, Amount: 20},
		}
		balances := calculateBalances(expenses, splits, nil)
		var sum int64
		for _, b := range balances {
			sum += b.Total
		}
		assert.Equal(t, int64(0), sum, "group totals must net to zero for multi-expense scenario")
	})
}

func TestSuggestReimbursements(t *testing.T) {
	payerID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	secondID := uuid.MustParse("00000000-0000-0000-0000-000000000002")

	t.Run("simple 2-user: other pays payer 50", func(t *testing.T) {
		balances := []models.BalanceEntry{
			{UserID: payerID, Total: 50},
			{UserID: secondID, Total: -50},
		}
		reimbursements := suggestReimbursements(balances)
		require.Len(t, reimbursements, 1)
		assert.Equal(t, secondID, reimbursements[0].FromUserID)
		assert.Equal(t, payerID, reimbursements[0].ToUserID)
		assert.Equal(t, int64(50), reimbursements[0].Amount)
	})

	t.Run("all-zero balances produce no reimbursements", func(t *testing.T) {
		balances := []models.BalanceEntry{
			{UserID: payerID, Total: 0},
			{UserID: secondID, Total: 0},
		}
		reimbursements := suggestReimbursements(balances)
		assert.Empty(t, reimbursements)
	})

	t.Run("three users: reimbursements minimize transfers", func(t *testing.T) {
		thirdID := uuid.MustParse("00000000-0000-0000-0000-000000000003")
		balances := []models.BalanceEntry{
			{UserID: payerID, Total: 80},
			{UserID: secondID, Total: -30},
			{UserID: thirdID, Total: -50},
		}
		reimbursements := suggestReimbursements(balances)
		// Both debtors must pay the creditor; all amounts positive.
		var totalPaid int64
		for _, r := range reimbursements {
			assert.Positive(t, r.Amount)
			assert.Equal(t, payerID, r.ToUserID)
			totalPaid += r.Amount
		}
		assert.Equal(t, int64(80), totalPaid, "total reimbursed must equal creditor's surplus")
	})
}

// TestBalancesEquivalence proves that balancesFromAggregates produces the same
// []models.BalanceEntry as calculateBalances for a mixed fixture with 3 users,
// several expenses with splits, and 2 settlements.
//
// Fixture description:
//   - Expense E1: payer=userA, amount=9000
//     splits: userA→3000 (IsSettled=true, ignored for balance), userB→3000, userC→3000
//   - Expense E2: payer=userB, amount=5000
//     splits: userB→2500 (IsSettled=true), userC→2500
//   - Settlement S1: from=userB, to=userA, amount=2000
//   - Settlement S2: from=userC, to=userA, amount=1500
//
// calculateBalances manual derivation:
//   userA: Paid=9000+0+0=9000,  Owed=3000+0+0=3000, Total=6000
//     (S1: +to→Owed+=2000; S2: +to→Owed+=1500  → Owed=3000+2000+1500=6500)
//     Paid=(9000 from expense)+(0 settlements from)=9000  Total=9000-6500=2500
//   userB: Paid=5000+2000=7000, Owed=3000+2500=5500, Total=1500
//     (settlement S1: from_user→Paid+=2000)
//   userC: Paid=0+1500=1500,    Owed=3000+2500=5500, Total=-4000
//     (settlement S2: from_user→Paid+=1500)
//
// Aggregate derivation (what DB would return):
//   userA: ExpensePaid=9000, SplitOwed=3000, SettledOut=0,    SettledIn=3500
//          → Paid=9000,  Owed=6500, Total=2500
//   userB: ExpensePaid=5000, SplitOwed=5500, SettledOut=2000, SettledIn=0
//          → Paid=7000,  Owed=5500, Total=1500
//   userC: ExpensePaid=0,    SplitOwed=5500, SettledOut=1500, SettledIn=0
//          → Paid=1500,  Owed=5500, Total=-4000
func TestBalancesEquivalence(t *testing.T) {
	userA := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	userB := uuid.MustParse("00000000-0000-0000-0000-000000000002")
	userC := uuid.MustParse("00000000-0000-0000-0000-000000000003")

	expE1 := uuid.New()
	expE2 := uuid.New()

	// Feed fixture through calculateBalances (path A)
	expenses := []models.Expense{
		{ID: expE1, PayerID: userA, Amount: 9000, BaseAmount: 9000},
		{ID: expE2, PayerID: userB, Amount: 5000, BaseAmount: 5000},
	}
	splits := []models.Split{
		{ExpenseID: expE1, UserID: userA, Amount: 3000, IsSettled: true},
		{ExpenseID: expE1, UserID: userB, Amount: 3000},
		{ExpenseID: expE1, UserID: userC, Amount: 3000},
		{ExpenseID: expE2, UserID: userB, Amount: 2500, IsSettled: true},
		{ExpenseID: expE2, UserID: userC, Amount: 2500},
	}
	settlements := []models.Settlement{
		{FromUserID: userB, ToUserID: userA, Amount: 2000},
		{FromUserID: userC, ToUserID: userA, Amount: 1500},
	}
	wantBalances := calculateBalances(expenses, splits, settlements)

	// Feed hand-derived aggregates through balancesFromAggregates (path B)
	// Derivation documented in function-level comment above.
	aggregates := []models.BalanceAggregate{
		{UserID: userA, ExpensePaid: 9000, SplitOwed: 3000, SettledOut: 0, SettledIn: 3500},
		{UserID: userB, ExpensePaid: 5000, SplitOwed: 5500, SettledOut: 2000, SettledIn: 0},
		{UserID: userC, ExpensePaid: 0, SplitOwed: 5500, SettledOut: 1500, SettledIn: 0},
	}
	gotBalances := balancesFromAggregates(aggregates)

	// Both paths must produce identical BalanceEntry slices.
	require.Equal(t, len(wantBalances), len(gotBalances), "balance count mismatch")
	for i := range wantBalances {
		assert.Equal(t, wantBalances[i].UserID, gotBalances[i].UserID, "user_id[%d]", i)
		assert.Equal(t, wantBalances[i].Paid, gotBalances[i].Paid, "Paid[%d] user=%s", i, wantBalances[i].UserID)
		assert.Equal(t, wantBalances[i].Owed, gotBalances[i].Owed, "Owed[%d] user=%s", i, wantBalances[i].UserID)
		assert.Equal(t, wantBalances[i].Total, gotBalances[i].Total, "Total[%d] user=%s", i, wantBalances[i].UserID)
	}
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

func TestFinanceService_UpdateExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	otherUserID := uuid.New()
	expenseID := uuid.New()
	groupID := uuid.New()

	existingExpense := &models.Expense{ID: expenseID, GroupID: groupID, PayerID: userID, Amount: 100, BaseAmount: 100, FxRate: 1, Currency: "USD"}

	t.Run("member updating own-payer expense amount rescales splits", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
		financeRepo.On("ListSplitsByExpense", ctx, expenseID).Return([]models.Split{
			{ID: uuid.New(), ExpenseID: expenseID, UserID: userID, Amount: 100},
		}, nil)
		financeRepo.On("UpdateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).Return(nil)

		expense := &models.Expense{ID: expenseID, PayerID: userID, Amount: 200, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, expense)
		require.NoError(t, err)
	})

	t.Run("member reassigning payer to different user is denied", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		expense := &models.Expense{ID: expenseID, PayerID: otherUserID, Amount: 100, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, expense)
		require.Error(t, err)
	})

	t.Run("admin reassigning payer succeeds", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		// requireMember call for userID (admin)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		// requireMember call for new payer (otherUserID)
		groupRepo.On("GetMembership", ctx, groupID, otherUserID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
		financeRepo.On("UpdateExpense", ctx, mock.AnythingOfType("*models.Expense")).Return(nil)

		expense := &models.Expense{ID: expenseID, PayerID: otherUserID, Amount: 100, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, expense)
		require.NoError(t, err)
	})

	t.Run("amount zero returns ErrValidation", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		expense := &models.Expense{ID: expenseID, PayerID: userID, Amount: 0, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, expense)
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("negative amount returns ErrValidation", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		expense := &models.Expense{ID: expenseID, PayerID: userID, Amount: -50, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, expense)
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})
}

func TestFinanceService_UpdateSplit(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	otherUserID := uuid.New()
	splitID := uuid.New()
	expenseID := uuid.New()
	groupID := uuid.New()

	existingSplit := &models.Split{ID: splitID, ExpenseID: expenseID, UserID: otherUserID, Amount: 50}
	existingExpense := &models.Expense{ID: expenseID, GroupID: groupID, PayerID: userID}

	t.Run("member updating amount to positive value succeeds", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetSplitByID", ctx, splitID).Return(existingSplit, nil)
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("UpdateSplit", ctx, mock.AnythingOfType("*models.Split")).Return(nil)

		split := &models.Split{ID: splitID, UserID: otherUserID, Amount: 75}
		err := svc.UpdateSplit(ctx, userID, split)
		require.NoError(t, err)
	})

	t.Run("amount zero returns validation error", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetSplitByID", ctx, splitID).Return(existingSplit, nil)
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		split := &models.Split{ID: splitID, UserID: otherUserID, Amount: 0}
		err := svc.UpdateSplit(ctx, userID, split)
		require.Error(t, err)
		var valErr *api.ValidationError
		assert.ErrorAs(t, err, &valErr)
	})

	t.Run("negative amount returns validation error", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetSplitByID", ctx, splitID).Return(existingSplit, nil)
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		split := &models.Split{ID: splitID, UserID: otherUserID, Amount: -5}
		err := svc.UpdateSplit(ctx, userID, split)
		require.Error(t, err)
		var valErr *api.ValidationError
		assert.ErrorAs(t, err, &valErr)
	})

	t.Run("member reassigning split user is denied", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		newUserID := uuid.New()
		financeRepo.On("GetSplitByID", ctx, splitID).Return(existingSplit, nil)
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		split := &models.Split{ID: splitID, UserID: newUserID, Amount: 50}
		err := svc.UpdateSplit(ctx, userID, split)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
	})

	t.Run("admin reassigning split user succeeds", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		newUserID := uuid.New()
		financeRepo.On("GetSplitByID", ctx, splitID).Return(existingSplit, nil)
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existingExpense, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		financeRepo.On("UpdateSplit", ctx, mock.AnythingOfType("*models.Split")).Return(nil)

		split := &models.Split{ID: splitID, UserID: newUserID, Amount: 50}
		err := svc.UpdateSplit(ctx, userID, split)
		require.NoError(t, err)
	})
}

func TestFinanceService_UpdateRecurringExpense(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	otherUserID := uuid.New()
	reID := uuid.New()
	groupID := uuid.New()

	existingRE := &models.RecurringExpense{ID: reID, GroupID: groupID, PayerID: userID, Amount: 100}

	t.Run("member updating amount succeeds", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(existingRE, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("UpdateRecurringExpense", ctx, mock.AnythingOfType("*models.RecurringExpense")).Return(nil)

		re := &models.RecurringExpense{ID: reID, PayerID: userID, Amount: 200}
		err := svc.UpdateRecurringExpense(ctx, userID, re)
		require.NoError(t, err)
	})

	t.Run("amount zero returns ErrValidation", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(existingRE, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		re := &models.RecurringExpense{ID: reID, PayerID: userID, Amount: 0}
		err := svc.UpdateRecurringExpense(ctx, userID, re)
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("negative amount returns ErrValidation", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(existingRE, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		re := &models.RecurringExpense{ID: reID, PayerID: userID, Amount: -10}
		err := svc.UpdateRecurringExpense(ctx, userID, re)
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("member reassigning payer is denied", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(existingRE, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		re := &models.RecurringExpense{ID: reID, PayerID: otherUserID, Amount: 100}
		err := svc.UpdateRecurringExpense(ctx, userID, re)
		require.Error(t, err)
	})

	t.Run("admin reassigning payer succeeds", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		financeRepo.On("GetRecurringExpenseByID", ctx, reID).Return(existingRE, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		financeRepo.On("UpdateRecurringExpense", ctx, mock.AnythingOfType("*models.RecurringExpense")).Return(nil)

		re := &models.RecurringExpense{ID: reID, PayerID: otherUserID, Amount: 100}
		err := svc.UpdateRecurringExpense(ctx, userID, re)
		require.NoError(t, err)
	})
}

func TestFinanceService_CreateRecurringExpense_SplitValidation(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	member1 := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	member2 := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	outsider := uuid.New()

	t.Run("empty split mode defaults fine", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateRecurringExpense", ctx, mock.AnythingOfType("*models.RecurringExpense")).Return(nil)

		re := &models.RecurringExpense{GroupID: groupID, PayerID: userID, Amount: 100}
		err := svc.CreateRecurringExpense(ctx, userID, re)
		require.NoError(t, err)
	})

	t.Run("valid equal split config passes", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, member1).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, member2).Return(&models.GroupMembership{Role: "member"}, nil)
		financeRepo.On("CreateRecurringExpense", ctx, mock.AnythingOfType("*models.RecurringExpense")).Return(nil)

		re := &models.RecurringExpense{
			GroupID:   groupID,
			PayerID:   userID,
			Amount:    100,
			SplitMode: "equal",
			SplitInputs: []models.RecurringSplitInput{
				{UserID: member1},
				{UserID: member2},
			},
		}
		err := svc.CreateRecurringExpense(ctx, userID, re)
		require.NoError(t, err)
	})

	t.Run("exact amounts not summing to total returns error", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, member1).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, member2).Return(&models.GroupMembership{Role: "member"}, nil)

		re := &models.RecurringExpense{
			GroupID:   groupID,
			PayerID:   userID,
			Amount:    100,
			SplitMode: "amount",
			SplitInputs: []models.RecurringSplitInput{
				{UserID: member1, Amount: 40},
				{UserID: member2, Amount: 40}, // only 80, not 100
			},
		}
		err := svc.CreateRecurringExpense(ctx, userID, re)
		require.Error(t, err)
		var valErr *api.ValidationError
		require.ErrorAs(t, err, &valErr)
		assert.Contains(t, valErr.Message, "equal expense amount")
	})

	t.Run("non-member in inputs returns error", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, outsider).Return(nil, pgx.ErrNoRows)

		re := &models.RecurringExpense{
			GroupID:   groupID,
			PayerID:   userID,
			Amount:    100,
			SplitMode: "equal",
			SplitInputs: []models.RecurringSplitInput{
				{UserID: outsider},
			},
		}
		err := svc.CreateRecurringExpense(ctx, userID, re)
		require.Error(t, err)
		var valErr *api.ValidationError
		require.ErrorAs(t, err, &valErr)
		assert.Contains(t, valErr.Message, "member of this group")
	})
}

func TestFinanceService_UpdateExpense_RescalesSplits(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	otherID := uuid.New()

	t.Run("amount up rescales splits proportionally", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		expenseID := uuid.New()
		existing := &models.Expense{ID: expenseID, GroupID: groupID, PayerID: userID, Amount: 100, BaseAmount: 100, FxRate: 1, Currency: "USD"}
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existing, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
		financeRepo.On("ListSplitsByExpense", ctx, expenseID).Return([]models.Split{
			{ID: uuid.New(), ExpenseID: expenseID, UserID: userID, Amount: 50},
			{ID: uuid.New(), ExpenseID: expenseID, UserID: otherID, Amount: 50},
		}, nil)

		var captured []models.Split
		financeRepo.On("UpdateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).
			Run(func(args mock.Arguments) {
				captured = args.Get(2).([]models.Split)
			}).Return(nil)

		updated := &models.Expense{ID: expenseID, PayerID: userID, Amount: 200, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, updated)
		require.NoError(t, err)

		require.Len(t, captured, 2)
		var sum int64
		for _, s := range captured {
			sum += s.Amount
			assert.Equal(t, int64(100), s.Amount)
		}
		assert.Equal(t, int64(200), sum, "split sum must equal new base_amount")
		financeRepo.AssertCalled(t, "UpdateExpenseWithSplits", ctx, mock.Anything, mock.Anything)
	})

	t.Run("odd remainder lands on one split", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		expenseID := uuid.New()
		existing := &models.Expense{ID: expenseID, GroupID: groupID, PayerID: userID, Amount: 100, BaseAmount: 100, FxRate: 1, Currency: "USD"}
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existing, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
		financeRepo.On("ListSplitsByExpense", ctx, expenseID).Return([]models.Split{
			{ID: uuid.New(), ExpenseID: expenseID, UserID: userID, Amount: 50},
			{ID: uuid.New(), ExpenseID: expenseID, UserID: otherID, Amount: 50},
		}, nil)

		var captured []models.Split
		financeRepo.On("UpdateExpenseWithSplits", ctx, mock.AnythingOfType("*models.Expense"), mock.AnythingOfType("[]models.Split")).
			Run(func(args mock.Arguments) {
				captured = args.Get(2).([]models.Split)
			}).Return(nil)

		updated := &models.Expense{ID: expenseID, PayerID: userID, Amount: 101, Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, updated)
		require.NoError(t, err)

		require.Len(t, captured, 2)
		var sum int64
		for _, s := range captured {
			sum += s.Amount
		}
		assert.Equal(t, int64(101), sum, "split sum must equal new base_amount exactly")
	})

	t.Run("unchanged base_amount uses plain update", func(t *testing.T) {
		financeRepo := new(mocks.MockFinanceRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewFinanceService(financeRepo, groupRepo)

		expenseID := uuid.New()
		existing := &models.Expense{ID: expenseID, GroupID: groupID, PayerID: userID, Amount: 100, BaseAmount: 100, FxRate: 1, Currency: "USD"}
		financeRepo.On("GetExpenseByID", ctx, expenseID).Return(existing, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Currency: "USD"}, nil)
		financeRepo.On("UpdateExpense", ctx, mock.AnythingOfType("*models.Expense")).Return(nil)

		updated := &models.Expense{ID: expenseID, PayerID: userID, Amount: 100, Description: "new desc", Currency: "USD"}
		err := svc.UpdateExpense(ctx, userID, updated)
		require.NoError(t, err)
		financeRepo.AssertCalled(t, "UpdateExpense", ctx, mock.Anything)
		financeRepo.AssertNotCalled(t, "UpdateExpenseWithSplits", mock.Anything, mock.Anything, mock.Anything)
	})
}

func TestRescaleSplits(t *testing.T) {
	t.Run("oldTotal zero distributes newTotal evenly with exact sum", func(t *testing.T) {
		splits := []models.Split{
			{UserID: uuid.New(), Amount: 0},
			{UserID: uuid.New(), Amount: 0},
			{UserID: uuid.New(), Amount: 0},
		}
		out := rescaleSplits(splits, 0, 100)
		require.Len(t, out, 3)
		var sum int64
		for _, s := range out {
			sum += s.Amount
		}
		assert.Equal(t, int64(100), sum)
	})

	t.Run("empty splits returns empty", func(t *testing.T) {
		out := rescaleSplits(nil, 100, 200)
		assert.Empty(t, out)
	})
}
