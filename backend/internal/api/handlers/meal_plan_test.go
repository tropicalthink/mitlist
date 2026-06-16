package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
)

func newMealPlanRouter(t *testing.T) (chi.Router, *MealPlanHandler) {
	recipeRepo := newTestRecipeRepo()
	listRepo := newTestListRepo()
	groupRepo := newTestGroupRepo()
	mealPlanRepo := repositories.NewMealPlanRepo(testDB)
	svc := services.NewMealPlanService(mealPlanRepo, groupRepo, recipeRepo, listRepo)
	h := NewMealPlanHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	r.Post("/api/v1/meal-plans/generate-shopping-list", h.GenerateShoppingList)
	return r, h
}

func TestMealPlanHandler_CreateMealPlan_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	_, h := newMealPlanRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/meal-plans", nil)
	req.Header.Set("Content-Type", "application/json")
	h.CreateMealPlan(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestMealPlanHandler_ListMealPlans_RequiresGroupID(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	user := createTestUser(t, "mp-list@test.com", "password123")

	_, h := newMealPlanRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/meal-plans", nil)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.ListMealPlans(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestMealPlanHandler_ListMealPlans_ReturnsEmpty(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	user := createTestUser(t, "mp-empty@test.com", "password123")
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Test Household",
		CreatedBy: user.ID,
	}
	groupRepo := newTestGroupRepo()
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	_, h := newMealPlanRouter(t)

	from := time.Now().Format("2006-01-02")
	to := time.Now().AddDate(0, 0, 7).Format("2006-01-02")

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/meal-plans?group_id="+group.ID.String()+"&from="+from+"&to="+to, nil)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.ListMealPlans(rec, req)

	requireStatus(t, rec, http.StatusOK)
	var plans []map[string]any
	parseJSONResponse(t, rec, &plans)
	assert.Empty(t, plans)
}

func TestMealPlanHandler_UpdateMealPlan_InvalidDate(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	user := createTestUser(t, "mp-update@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newMealPlanRouter(t)

	id := uuid.New()
	body := map[string]any{"date": "not-a-date"}

	rec := httptest.NewRecorder()
	req := buildRequest(t, "PATCH", "/api/v1/meal-plans/"+id.String(), body, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.UpdateMealPlan(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestMealPlanHandler_DeleteMealPlan_NotFound(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	user := createTestUser(t, "mp-delete@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newMealPlanRouter(t)

	id := uuid.New()
	rec := httptest.NewRecorder()
	req := buildRequest(t, "DELETE", "/api/v1/meal-plans/"+id.String(), nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.DeleteMealPlan(rec, req)

	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func setTestUserContext(ctx context.Context, user *models.User) context.Context {
	return ctx
}
