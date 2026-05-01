package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// TestE2E_ListToExpenseFlow verifies the happy path: create list → add items with prices → cost summary → generate expense.
func TestE2E_ListToExpenseFlow(t *testing.T) {
	clearTables(t)

	// Setup repos and services shared across handlers
	listRepo := newTestListRepo()
	groupRepo := newTestGroupRepo()
	financeRepo := newTestFinanceRepo()

	listSvc := services.NewListService(listRepo, groupRepo)
	financeSvc := services.NewFinanceService(financeRepo, groupRepo)

	listHandler := NewListHandler(listSvc, nil)
	financeHandler := NewFinanceHandler(financeSvc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)

	// List routes
	r.Post("/api/v1/lists", listHandler.CreateList)
	r.Get("/api/v1/lists", listHandler.ListLists)
	r.Get("/api/v1/lists/{id}", listHandler.GetList)
	r.Post("/api/v1/lists/{id}/items", listHandler.CreateItem)
	r.Get("/api/v1/lists/{id}/cost-summary", listHandler.GetCostSummary)
	r.Post("/api/v1/lists/{id}/generate-expense", listHandler.GenerateExpense)

	// Finance routes
	r.Post("/api/v1/expenses", financeHandler.CreateExpense)
	r.Get("/api/v1/expenses", financeHandler.ListExpenses)

	// Create user and group
	user := createTestUser(t, "e2e@example.com", "password123")
	token := generateTestToken(user.ID)

	group := &models.Group{
		ID:        uuid.New(),
		Name:      "E2E Household",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		GroupID: group.ID,
		UserID:  user.ID,
		Role:    "admin",
	}))

	// 1. Create a shopping list
	rec := execRequest(t, r, "POST", "/api/v1/lists", map[string]any{
		"group_id": group.ID.String(),
		"name":     "Groceries",
		"type":     "shopping",
	}, token)
	requireStatus(t, rec, http.StatusCreated)
	var listResp map[string]any
	parseJSONResponse(t, rec, &listResp)
	listID := listResp["id"].(string)

	// 2. Add items with prices
	items := []struct {
		name      string
		priceCents int
	}{
		{"Milk", 299},
		{"Bread", 199},
		{"Eggs", 349},
	}
	for _, item := range items {
		rec := execRequest(t, r, "POST", "/api/v1/lists/"+listID+"/items", map[string]any{
			"name":        item.name,
			"quantity":    1,
			"unit":        "pc",
			"price_cents": item.priceCents,
		}, token)
		requireStatus(t, rec, http.StatusCreated)
	}

	// 3. Get cost summary
	rec = execRequest(t, r, "GET", "/api/v1/lists/"+listID+"/cost-summary", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var summaryResp map[string]any
	parseJSONResponse(t, rec, &summaryResp)
	assert.Equal(t, float64(847), summaryResp["total_cents"])
	assert.Equal(t, float64(282), summaryResp["equal_share_cents"])

	// 4. Generate expense from list
	rec = execRequest(t, r, "POST", "/api/v1/lists/"+listID+"/generate-expense", map[string]any{
		"description": "Groceries shopping",
	}, token)
	requireStatus(t, rec, http.StatusCreated)
	var expenseResp map[string]any
	parseJSONResponse(t, rec, &expenseResp)
	assert.Equal(t, "Groceries shopping", expenseResp["description"])
	assert.Equal(t, float64(847), expenseResp["amount"])

	// 5. Verify expense appears in group expenses
	rec = execRequest(t, r, "GET", "/api/v1/expenses?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)
	var expensesResp map[string]any
	parseJSONResponse(t, rec, &expensesResp)
	expenses := expensesResp["expenses"].([]any)
	require.Len(t, expenses, 1)
	assert.Equal(t, "Groceries shopping", expenses[0].(map[string]any)["description"])
}
