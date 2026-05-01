package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestAssistant_CreateSession(t *testing.T) {
	clearTables(t)
	router, _ := newAssistantRouter(t)
	user := createTestUser(t, "assist@example.com", "password123")
	token := generateTestToken(user.ID)

	body := map[string]any{"title": "Help"}
	rec := execRequest(t, router, "POST", "/assistant/sessions", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Help", resp["title"])
}

func TestAssistant_ListSessions(t *testing.T) {
	clearTables(t)
	router, _ := newAssistantRouter(t)
	user := createTestUser(t, "lsassist@example.com", "password123")
	token := generateTestToken(user.ID)

	assistantRepo := newTestAssistantRepo()
	_, err := assistantRepo.CreateSession(context.Background(), &models.ChatSession{
		ID:        uuid.New(),
		UserID:    user.ID,
		Title:     "Session 1",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/assistant/sessions?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestAssistant_DeleteSession(t *testing.T) {
	clearTables(t)
	router, _ := newAssistantRouter(t)
	user := createTestUser(t, "delassist@example.com", "password123")
	token := generateTestToken(user.ID)

	assistantRepo := newTestAssistantRepo()
	session := &models.ChatSession{
		ID:        uuid.New(),
		UserID:    user.ID,
		Title:     "ToDelete",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	_, err := assistantRepo.CreateSession(context.Background(), session)
	require.NoError(t, err)

	rec := execRequest(t, router, "DELETE", "/assistant/sessions/"+session.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestAssistant_SendMessage(t *testing.T) {
	clearTables(t)
	router, _ := newAssistantRouter(t)
	user := createTestUser(t, "msg@example.com", "password123")
	token := generateTestToken(user.ID)

	assistantRepo := newTestAssistantRepo()
	session := &models.ChatSession{
		ID:        uuid.New(),
		UserID:    user.ID,
		Title:     "Chat",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	_, err := assistantRepo.CreateSession(context.Background(), session)
	require.NoError(t, err)

	body := map[string]any{"content": "Hello"}
	rec := execRequest(t, router, "POST", "/assistant/sessions/"+session.ID.String()+"/messages", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Hello", resp["content"])
}

func TestAssistant_ListMessages(t *testing.T) {
	clearTables(t)
	router, _ := newAssistantRouter(t)
	user := createTestUser(t, "lsmsg@example.com", "password123")
	token := generateTestToken(user.ID)

	assistantRepo := newTestAssistantRepo()
	session := &models.ChatSession{
		ID:        uuid.New(),
		UserID:    user.ID,
		Title:     "Chat",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	_, err := assistantRepo.CreateSession(context.Background(), session)
	require.NoError(t, err)
	_, err = assistantRepo.CreateMessage(context.Background(), &models.ChatMessage{
		ID:        uuid.New(),
		SessionID: session.ID,
		Role:      "user",
		Content:   "Hi",
		CreatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/assistant/sessions/"+session.ID.String()+"/messages?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
