package handlers

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCoreJourney_HouseholdWorkflow(t *testing.T) {
	clearTables(t)

	authRouter, _, mail := newAuthRouterWithMail(t)
	groupRouter, _ := newGroupRouter(t)
	listRouter, _ := newListRouter(t)
	choreRouter, _ := newChoreRouter(t)
	financeRouter, _ := newFinanceRouter(t)
	recipeRouter, _ := newRecipeRouter(t)
	shareRouter, _ := newShareRouter(t)

	registerBody := map[string]any{
		"email":      "journey@example.com",
		"password":   "password123!",
		"first_name": "Journey",
		"last_name":  "Tester",
	}
	// Registration is acknowledged without credentials — the journey only gets a
	// session once the emailed code is verified.
	rec := execRequest(t, authRouter, "POST", "/api/v1/auth/register", registerBody, "")
	requireStatus(t, rec, http.StatusAccepted)

	rec = execRequest(t, authRouter, "POST", "/api/v1/auth/verify-email", map[string]any{
		"token": mail.verificationCodeFor(t, "journey@example.com"),
	}, "")
	requireStatus(t, rec, http.StatusOK)

	var authResp map[string]any
	parseJSONResponse(t, rec, &authResp)
	token := authResp["access_token"].(string)
	require.NotEmpty(t, token)

	groupBody := map[string]any{
		"name":     "Journey Household",
		"currency": "USD",
	}
	rec = execRequest(t, groupRouter, "POST", "/api/v1/groups", groupBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var groupResp map[string]any
	parseJSONResponse(t, rec, &groupResp)
	groupID := groupResp["id"].(string)
	assert.Equal(t, "Journey Household", groupResp["name"])

	listBody := map[string]any{
		"group_id": groupID,
		"name":     "Weekend Groceries",
		"type":     "shopping",
	}
	rec = execRequest(t, listRouter, "POST", "/api/v1/lists", listBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var listResp map[string]any
	parseJSONResponse(t, rec, &listResp)
	listID := listResp["id"].(string)
	assert.Equal(t, "Weekend Groceries", listResp["name"])

	itemBody := map[string]any{
		"name":     "Milk",
		"quantity": 2,
		"unit":     "L",
	}
	rec = execRequest(t, listRouter, "POST", "/api/v1/lists/"+listID+"/items", itemBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var itemResp map[string]any
	parseJSONResponse(t, rec, &itemResp)
	itemID := itemResp["id"].(string)
	assert.Equal(t, "Milk", itemResp["name"])

	rec = execRequest(t, listRouter, "GET", "/api/v1/lists/"+listID+"/items", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var listItems []map[string]any
	parseJSONResponse(t, rec, &listItems)
	require.Len(t, listItems, 1)
	assert.Equal(t, itemID, listItems[0]["id"])

	choreBody := map[string]any{
		"group_id":      groupID,
		"name":          "Take out trash",
		"rotation_type": "none",
		"frequency":     "weekly",
		"is_active":     true,
	}
	rec = execRequest(t, choreRouter, "POST", "/api/v1/chores", choreBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var choreResp map[string]any
	parseJSONResponse(t, rec, &choreResp)
	choreID := choreResp["id"].(string)
	assert.Equal(t, "Take out trash", choreResp["name"])

	rec = execRequest(t, choreRouter, "GET", "/api/v1/chores?group_id="+groupID, nil, token)
	requireStatus(t, rec, http.StatusOK)
	var chores []map[string]any
	parseJSONResponse(t, rec, &chores)
	require.Len(t, chores, 1)
	assert.Equal(t, choreID, chores[0]["id"])

	expenseBody := map[string]any{
		"group_id":       groupID,
		"payer_id":       authResp["user"].(map[string]any)["id"],
		"amount":         1234,
		"description":    "Groceries run",
		"category":       "Food",
		"currency":       "USD",
		"split_user_ids": []string{authResp["user"].(map[string]any)["id"].(string)},
	}
	rec = execRequest(t, financeRouter, "POST", "/api/v1/expenses", expenseBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var expenseResp map[string]any
	parseJSONResponse(t, rec, &expenseResp)
	assert.Equal(t, "Groceries run", expenseResp["description"])

	rec = execRequest(t, financeRouter, "GET", "/api/v1/expenses?group_id="+groupID, nil, token)
	requireStatus(t, rec, http.StatusOK)
	var expenses []map[string]any
	parseJSONResponse(t, rec, &expenses)
	require.Len(t, expenses, 1)

	recipeBody := map[string]any{
		"title":       "Weeknight Pasta",
		"description": "Boil pasta and add sauce.",
		"prep_time":   10,
		"cook_time":   15,
		"servings":    4,
		"is_public":   false,
	}
	rec = execRequest(t, recipeRouter, "POST", "/api/v1/recipes", recipeBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var recipeResp map[string]any
	parseJSONResponse(t, rec, &recipeResp)
	assert.Equal(t, "Weeknight Pasta", recipeResp["title"])

	rec = execRequest(t, recipeRouter, "GET", "/api/v1/recipes?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var recipes []map[string]any
	parseJSONResponse(t, rec, &recipes)
	require.Len(t, recipes, 1)

	shareListBody := map[string]any{
		"group_id": groupID,
		"text":     "Bread, Eggs, Butter",
	}
	rec = execRequest(t, shareRouter, "POST", "/share-target/lists", shareListBody, token)
	requireStatus(t, rec, http.StatusCreated)

	var shareListResp map[string]any
	parseJSONResponse(t, rec, &shareListResp)
	require.NotNil(t, shareListResp["list"])

	rec = execRequest(t, listRouter, "GET", "/api/v1/lists?group_id="+groupID, nil, token)
	requireStatus(t, rec, http.StatusOK)
	var lists []map[string]any
	parseJSONResponse(t, rec, &lists)
	assert.GreaterOrEqual(t, len(lists), 2)

	shareRecipeBody := map[string]any{
		"text": "Tomato soup with basil",
	}
	rec = execRequest(t, shareRouter, "POST", "/share-target/recipes", shareRecipeBody, token)
	requireStatus(t, rec, http.StatusCreated)

	rec = execRequest(t, recipeRouter, "GET", "/api/v1/recipes?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)
	parseJSONResponse(t, rec, &recipes)
	assert.GreaterOrEqual(t, len(recipes), 2)
}
