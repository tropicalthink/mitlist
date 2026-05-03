package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"

	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
)

func newCalendarRouter(t *testing.T) (chi.Router, *CalendarHandler) {
	choreRepo := newTestChoreRepo()
	financeRepo := newTestFinanceRepo()
	recipeRepo := newTestRecipeRepo()
	mealPlanRepo := services.NewMealPlanService(recipeRepo, newTestListRepo(), newTestGroupRepo())
	pinwallRepo := repositories.NewPinwallRepository(testDB)
	svc := services.NewCalendarService(mealPlanRepo, recipeRepo, choreRepo, financeRepo, newTestGroupRepo(), pinwallRepo)
	h := NewCalendarHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	return r, h
}

func TestCalendarHandler_GetCalendar_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	_, h := newCalendarRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/calendar", nil)
	h.GetCalendar(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestCalendarHandler_GetCalendar_InvalidGroupID(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	user := createTestUser(t, "cal-invalid@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newCalendarRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "GET", "/api/v1/calendar?group_id=not-a-uuid&from=2024-01-01&to=2024-01-31", nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.GetCalendar(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestCalendarHandler_GetCalendar_MissingDates(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	user := createTestUser(t, "cal-dates@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newCalendarRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "GET", "/api/v1/calendar?group_id="+uuid.New().String(), nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.GetCalendar(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestCalendarHandler_ExportICal_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	_, h := newCalendarRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/calendar/ical", nil)
	h.ExportICal(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}
