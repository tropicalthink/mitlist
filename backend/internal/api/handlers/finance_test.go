package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/models"
)

func TestFinance_CreateExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "fin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Fin Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{
		"group_id":     group.ID.String(),
		"payer_id":     user.ID.String(),
		"amount":       10000,
		"description":  "Dinner",
		"category":     "Food",
		"currency":     "USD",
		"date":         time.Now().Format(time.RFC3339),
		"split_user_ids": []string{user.ID.String()},
	}
	rec := execRequest(t, router, "POST", "/api/v1/expenses", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Dinner", resp["description"])
}

func TestFinance_ListExpenses(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "lsfin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	financeRepo := newTestFinanceRepo()
	require.NoError(t, financeRepo.CreateExpense(context.Background(), &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      5000,
		Description: "Lunch",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/expenses?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestFinance_GetExpense_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "nffin@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/expenses/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestFinance_DeleteExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "delfin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      5000,
		Description: "X",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	rec := execRequest(t, router, "DELETE", "/api/v1/expenses/"+expense.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestFinance_CreateSplit(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "split@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Dinner",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	body := map[string]any{"user_id": user.ID.String(), "amount": 5000}
	rec := execRequest(t, router, "POST", "/api/v1/expenses/"+expense.ID.String()+"/splits", body, token)
	requireStatus(t, rec, http.StatusCreated)
}

func TestFinance_CreateSettlement(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "settle@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Dinner",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	body := map[string]any{
		"from_user_id": user.ID.String(),
		"to_user_id":   user.ID.String(),
		"amount":       5000,
	}
	rec := execRequest(t, router, "POST", "/api/v1/expenses/"+expense.ID.String()+"/settle", body, token)
	requireStatus(t, rec, http.StatusCreated)
}

func TestFinance_CreateRecurringExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "rec@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{
		"group_id":     group.ID.String(),
		"payer_id":     user.ID.String(),
		"amount":       10000,
		"description":  "Rent",
		"category":     "Housing",
		"frequency":    "monthly",
		"next_due":     time.Now().Add(24 * time.Hour).Format(time.RFC3339),
		"is_active":    true,
	}
	rec := execRequest(t, router, "POST", "/api/v1/recurring-expenses", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Rent", resp["description"])
}

func TestFinance_ListRecurringExpenses(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "lsrec@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	financeRepo := newTestFinanceRepo()
	require.NoError(t, financeRepo.CreateRecurringExpense(context.Background(), &models.RecurringExpense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Rent",
		Category:    "Housing",
		Frequency:   "monthly",
		NextDue:     time.Now().Add(24 * time.Hour),
		IsActive:    true,
		CreatedAt:   time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/recurring-expenses?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
