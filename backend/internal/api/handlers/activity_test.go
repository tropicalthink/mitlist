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

func TestActivity_ListActivityLogs(t *testing.T) {
	clearTables(t)
	router, _ := newActivityRouter(t)
	user := createTestUser(t, "act@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Act Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	activityRepo := newTestActivityRepo()
	require.NoError(t, activityRepo.LogActivity(context.Background(), &models.ActivityLog{
		ID:         uuid.New(),
		GroupID:    group.ID,
		UserID:     user.ID,
		Action:     "CREATE",
		EntityType: "list",
		EntityID:   uuid.New(),
		CreatedAt:  time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/activity-logs?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestActivity_GetActivityLog(t *testing.T) {
	clearTables(t)
	router, _ := newActivityRouter(t)
	user := createTestUser(t, "getact@example.com", "password123")
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

	activityRepo := newTestActivityRepo()
	logEntry := &models.ActivityLog{
		ID:         uuid.New(),
		GroupID:    group.ID,
		UserID:     user.ID,
		Action:     "CREATE",
		EntityType: "list",
		EntityID:   uuid.New(),
		CreatedAt:  time.Now().UTC(),
	}
	require.NoError(t, activityRepo.LogActivity(context.Background(), logEntry))

	rec := execRequest(t, router, "GET", "/activity-logs/"+logEntry.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "CREATE", resp["action"])
}

func TestActivity_DeleteActivityLog(t *testing.T) {
	clearTables(t)
	router, _ := newActivityRouter(t)
	user := createTestUser(t, "delact@example.com", "password123")
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

	activityRepo := newTestActivityRepo()
	logEntry := &models.ActivityLog{
		ID:         uuid.New(),
		GroupID:    group.ID,
		UserID:     user.ID,
		Action:     "CREATE",
		EntityType: "list",
		EntityID:   uuid.New(),
		CreatedAt:  time.Now().UTC(),
	}
	require.NoError(t, activityRepo.LogActivity(context.Background(), logEntry))

	rec := execRequest(t, router, "DELETE", "/activity-logs/"+logEntry.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}
