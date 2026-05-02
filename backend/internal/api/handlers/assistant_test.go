package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"

	"github.com/mitlist-app/mitlist/internal/services"
)

func newAssistantRouter(t *testing.T) (chi.Router, *AssistantHandler) {
	aiClient := newTestAIClient()
	svc := services.NewScanService(aiClient)
	h := NewAssistantHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.Routes(r)
	return r, h
}

func TestAssistantHandler_Scan_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	_, h := newAssistantRouter(t)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/assistant/scan", nil)
	h.Scan(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAssistantHandler_Scan_MissingFile(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	user := createTestUser(t, "assistant-scan@test.com", "password123")
	token := generateTestToken(user.ID)

	_, h := newAssistantRouter(t)

	rec := httptest.NewRecorder()
	req := buildRequest(t, "POST", "/api/v1/assistant/scan", nil, token)
	req = req.WithContext(setTestUserContext(req.Context(), user))
	h.Scan(rec, req)

	// Should return error for missing file
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}
