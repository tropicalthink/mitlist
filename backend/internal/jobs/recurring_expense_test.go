package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// mockRecurringExpenseRepo is a mock for recurringExpenseRepo.
type mockRecurringExpenseRepo struct {
	mock.Mock
}

func (m *mockRecurringExpenseRepo) ListDueRecurringExpenses(ctx context.Context) ([]models.RecurringExpense, error) {
	args := m.Called(ctx)
	if v := args.Get(0); v != nil {
		return v.([]models.RecurringExpense), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *mockRecurringExpenseRepo) ProcessRecurringExpense(ctx context.Context, expense *models.Expense, splits []models.Split, reID uuid.UUID, oldNextDue time.Time, nextDue time.Time) error {
	args := m.Called(ctx, expense, splits, reID, oldNextDue, nextDue)
	return args.Error(0)
}

func TestRecurringExpenseJob_PayerOnlyMode(t *testing.T) {
	log := logger.New("test")
	repo := new(mockRecurringExpenseRepo)
	push := new(mockPusher)

	payerID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	groupID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	reID := uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc")
	nextDue := time.Now().UTC().Add(-time.Hour) // overdue

	re := models.RecurringExpense{
		ID:          reID,
		GroupID:     groupID,
		PayerID:     payerID,
		Amount:      1000,
		Description: "Rent",
		Currency:    "USD",
		Frequency:   "monthly",
		NextDue:     nextDue,
		IsActive:    true,
		SplitMode:   "payer_only",
		SplitInputs: nil,
	}

	repo.On("ListDueRecurringExpenses", mock.Anything).Return([]models.RecurringExpense{re}, nil)
	repo.On("ProcessRecurringExpense",
		mock.Anything,
		mock.AnythingOfType("*models.Expense"),
		mock.MatchedBy(func(splits []models.Split) bool {
			return len(splits) == 1 &&
				splits[0].UserID == payerID &&
				splits[0].Amount == 1000 &&
				splits[0].IsSettled
		}),
		reID,
		nextDue,
		mock.Anything,
	).Return(nil)
	push.On("BroadcastToGroup", groupID, mock.AnythingOfType("string")).Return(nil)

	job := newRecurringExpenseJob(repo, push, log)
	job.Run()

	repo.AssertExpectations(t)
}

func TestRecurringExpenseJob_EqualSplitMode(t *testing.T) {
	log := logger.New("test")
	repo := new(mockRecurringExpenseRepo)
	push := new(mockPusher)

	payerID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	user2 := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	user3 := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	groupID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	reID := uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc")
	nextDue := time.Now().UTC().Add(-time.Hour)

	re := models.RecurringExpense{
		ID:          reID,
		GroupID:     groupID,
		PayerID:     payerID,
		Amount:      100,
		Description: "Internet",
		Currency:    "USD",
		Frequency:   "monthly",
		NextDue:     nextDue,
		IsActive:    true,
		SplitMode:   "equal",
		SplitInputs: []models.RecurringSplitInput{
			{UserID: payerID},
			{UserID: user2},
			{UserID: user3},
		},
	}

	repo.On("ListDueRecurringExpenses", mock.Anything).Return([]models.RecurringExpense{re}, nil)
	repo.On("ProcessRecurringExpense",
		mock.Anything,
		mock.AnythingOfType("*models.Expense"),
		mock.MatchedBy(func(splits []models.Split) bool {
			if len(splits) != 3 {
				return false
			}
			var total int64
			payerSettled := false
			for _, s := range splits {
				total += s.Amount
				if s.UserID == payerID && s.IsSettled {
					payerSettled = true
				}
			}
			return total == 100 && payerSettled
		}),
		reID,
		nextDue,
		mock.Anything,
	).Return(nil)
	push.On("BroadcastToGroup", groupID, mock.AnythingOfType("string")).Return(nil)

	job := newRecurringExpenseJob(repo, push, log)
	job.Run()

	repo.AssertExpectations(t)
}

func TestRecurringExpenseJob_InvalidSplitConfigFallsBackToPayerOnly(t *testing.T) {
	log := logger.New("test")
	repo := new(mockRecurringExpenseRepo)
	push := new(mockPusher)

	payerID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	groupID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	reID := uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc")
	nextDue := time.Now().UTC().Add(-time.Hour)

	// Invalid: exact amounts don't sum to total
	re := models.RecurringExpense{
		ID:          reID,
		GroupID:     groupID,
		PayerID:     payerID,
		Amount:      100,
		Description: "Broken",
		Currency:    "USD",
		Frequency:   "monthly",
		NextDue:     nextDue,
		IsActive:    true,
		SplitMode:   "amount",
		SplitInputs: []models.RecurringSplitInput{
			{UserID: payerID, Amount: 40}, // only 40, should be 100
		},
	}

	repo.On("ListDueRecurringExpenses", mock.Anything).Return([]models.RecurringExpense{re}, nil)
	// Should fall back to payer-only single split
	repo.On("ProcessRecurringExpense",
		mock.Anything,
		mock.AnythingOfType("*models.Expense"),
		mock.MatchedBy(func(splits []models.Split) bool {
			return len(splits) == 1 &&
				splits[0].UserID == payerID &&
				splits[0].Amount == 100 &&
				splits[0].IsSettled
		}),
		reID,
		nextDue,
		mock.Anything,
	).Return(nil)
	push.On("BroadcastToGroup", groupID, mock.AnythingOfType("string")).Return(nil)

	job := newRecurringExpenseJob(repo, push, log)
	job.Run()

	repo.AssertExpectations(t)
}

func TestRecurringExpenseJob_LegacyEmptySplitMode(t *testing.T) {
	log := logger.New("test")
	repo := new(mockRecurringExpenseRepo)
	push := new(mockPusher)

	payerID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	groupID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
	reID := uuid.MustParse("cccccccc-cccc-cccc-cccc-cccccccccccc")
	nextDue := time.Now().UTC().Add(-time.Hour)

	// Legacy row: no split_mode set
	re := models.RecurringExpense{
		ID:          reID,
		GroupID:     groupID,
		PayerID:     payerID,
		Amount:      500,
		Description: "Legacy",
		Currency:    "USD",
		Frequency:   "monthly",
		NextDue:     nextDue,
		IsActive:    true,
		SplitMode:   "", // legacy empty
		SplitInputs: nil,
	}

	repo.On("ListDueRecurringExpenses", mock.Anything).Return([]models.RecurringExpense{re}, nil)
	repo.On("ProcessRecurringExpense",
		mock.Anything,
		mock.AnythingOfType("*models.Expense"),
		mock.MatchedBy(func(splits []models.Split) bool {
			return len(splits) == 1 &&
				splits[0].UserID == payerID &&
				splits[0].Amount == 500 &&
				splits[0].IsSettled
		}),
		reID,
		nextDue,
		mock.Anything,
	).Return(nil)
	push.On("BroadcastToGroup", groupID, mock.AnythingOfType("string")).Return(nil)

	job := newRecurringExpenseJob(repo, push, log)
	job.Run()

	repo.AssertExpectations(t)
}

func TestRecurringExpenseJob_EqualSplit_SumsCorrectly(t *testing.T) {
	// Direct unit test: 3 users, amount 100 → splits sum to 100, payer settled.
	log := logger.New("test")
	payerID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	user2 := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	user3 := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	expenseID := uuid.New()
	now := time.Now().UTC()

	re := models.RecurringExpense{
		ID:        uuid.New(),
		PayerID:   payerID,
		Amount:    100,
		SplitMode: "equal",
		SplitInputs: []models.RecurringSplitInput{
			{UserID: payerID},
			{UserID: user2},
			{UserID: user3},
		},
	}

	job := newRecurringExpenseJob(nil, nil, log)
	splits := job.buildSplitsForRecurring(re, expenseID, now)

	require.Len(t, splits, 3)

	var total int64
	payerSettled := false
	for _, s := range splits {
		assert.Equal(t, expenseID, s.ExpenseID)
		assert.False(t, s.ID == uuid.Nil, "split ID should be set")
		total += s.Amount
		if s.UserID == payerID {
			payerSettled = s.IsSettled
		}
	}
	assert.Equal(t, int64(100), total, "splits must sum to expense amount")
	assert.True(t, payerSettled, "payer split must be settled")
}
