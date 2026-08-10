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

func TestNotification_ListNotifications(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "notif@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Hello",
		Body:      "World",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/notifications?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestNotification_CountUnreadNotifications(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "unreadnotif@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Unread",
		Body:      "One",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/notifications/unread-count", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var resp map[string]int
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, 1, resp["count"])
}

func TestNotification_GetNotification(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "getnotif@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	n := &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Hello",
		Body:      "World",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), n))

	rec := execRequest(t, router, "GET", "/notifications/"+n.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Hello", resp["title"])
}

func TestNotification_MarkAsRead(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "readnotif@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	n := &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Hello",
		Body:      "World",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), n))

	rec := execRequest(t, router, "PATCH", "/notifications/"+n.ID.String()+"/read", nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestNotification_MarkAllAsRead(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "readall@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Hello",
		Body:      "World",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "PATCH", "/notifications/read-all", nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestNotification_DeleteNotification(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "delnotif@example.com", "password123!")
	token := generateTestToken(user.ID)

	notificationRepo := newTestNotificationRepo()
	n := &models.Notification{
		ID:        uuid.New(),
		UserID:    user.ID,
		Type:      "test",
		Title:     "Hello",
		Body:      "World",
		IsRead:    false,
		CreatedAt: time.Now().UTC(),
	}
	require.NoError(t, notificationRepo.CreateNotification(context.Background(), n))

	rec := execRequest(t, router, "DELETE", "/notifications/"+n.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestNotification_GetPreferences(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "pref@example.com", "password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/notifications/preferences", nil, token)
	requireStatus(t, rec, http.StatusOK)
}

func TestNotification_UpdatePreferences(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "uppref@example.com", "password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Pref Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id":     group.ID.String(),
		"chore_due":    true,
		"push_enabled": true,
	}
	rec := execRequest(t, router, "PATCH", "/notifications/preferences", body, token)
	requireStatus(t, rec, http.StatusNoContent)
}
