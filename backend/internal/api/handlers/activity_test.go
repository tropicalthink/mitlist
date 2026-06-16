package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

func newActivityRouter(t *testing.T) (chi.Router, *ActivityHandler) {
	activityRepo := newTestActivityRepo()
	groupRepo := newTestGroupRepo()
	svc := services.NewActivityService(activityRepo, groupRepo)
	h := NewActivityHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	return r, h
}

func TestActivityHandler_List_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	_, h := newActivityRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/activity", nil)
	h.ListActivity(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestActivityHandler_List_MissingGroupID(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	user := createTestUser(t, "activity-list@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newActivityRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "GET", "/api/v1/activity", nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.ListActivity(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestActivityHandler_List_InvalidGroupID(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	user := createTestUser(t, "activity-invalid@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newActivityRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "GET", "/api/v1/activity?group_id=not-a-uuid", nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.ListActivity(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestActivityHandler_List_ReturnsEmpty(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	clearTables(t)

	user := createTestUser(t, "activity-empty@test.com", "password123")
	token := generateTestToken(user.ID)

	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Test Household",
		CreatedBy: user.ID,
	}
	groupRepo := newTestGroupRepo()
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	_, h := newActivityRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "GET", "/api/v1/activity?group_id="+group.ID.String()+"&limit=10", nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.ListActivity(rec, req)

	requireStatus(t, rec, http.StatusOK)
	var result map[string]any
	parseJSONResponse(t, rec, &result)
	_, ok := result["events"]
	assert.True(t, ok, "response should contain an events key")
}
