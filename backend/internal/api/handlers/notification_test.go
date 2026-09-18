package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	repositoryMocks "github.com/mitlist-app/mitlist/internal/repositories/mocks"
	"github.com/mitlist-app/mitlist/internal/services"
)

func TestNotification_ListNotifications(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "notif@example.com", "Password123!")
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
	user := createTestUser(t, "unreadnotif@example.com", "Password123!")
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
	user := createTestUser(t, "getnotif@example.com", "Password123!")
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
	user := createTestUser(t, "readnotif@example.com", "Password123!")
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
	user := createTestUser(t, "readall@example.com", "Password123!")
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
	user := createTestUser(t, "delnotif@example.com", "Password123!")
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
	user := createTestUser(t, "pref@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/notifications/preferences", nil, token)
	requireStatus(t, rec, http.StatusOK)
}

func TestNotification_UpdatePreferences(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "uppref@example.com", "Password123!")
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

	pref, err := newTestNotificationRepo().GetPreference(context.Background(), user.ID, group.ID)
	require.NoError(t, err)
	assert.True(t, pref.ChoreDue)
	assert.True(t, pref.ChoreDueDayOf, "omitted fields must retain their default")
	assert.True(t, pref.ListItemAdded, "omitted fields must retain their default")
	assert.True(t, pref.ExpenseCreated, "omitted fields must retain their default")
	assert.True(t, pref.PushEnabled)
	assert.False(t, pref.EmailEnabled)
}

func TestNotification_UpdatePreferencesAcceptsEchoedRecord(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "echopref@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Echo Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	// The app used to PATCH the whole record it got from GET, server-owned
	// fields included. Those must not trip the strict decoder.
	body := map[string]any{
		"id":            uuid.Nil.String(),
		"user_id":       user.ID.String(),
		"group_id":      group.ID.String(),
		"chore_due":     false,
		"push_enabled":  true,
		"email_enabled": false,
		"created_at":    "2026-01-01T00:00:00Z",
		"updated_at":    "2026-01-01T00:00:00Z",
	}
	rec := execRequest(t, router, "PATCH", "/notifications/preferences", body, token)
	requireStatus(t, rec, http.StatusNoContent)

	pref, err := newTestNotificationRepo().GetPreference(context.Background(), user.ID, group.ID)
	require.NoError(t, err)
	assert.False(t, pref.ChoreDue)
	assert.Equal(t, user.ID, pref.UserID)
	assert.NotEqual(t, uuid.Nil, pref.ID, "the echoed nil id must not become the row id")
}

func TestNotification_UpdatePreferencesRequiresGroup(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "missingprefgroup@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "PATCH", "/notifications/preferences", map[string]any{
		"push_enabled": false,
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestNotification_FlushDigestsEmptyBodyReleasesEverything(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "flushall@example.com", "Password123!")
	token := generateTestToken(user.ID)

	// The app sends this when it goes to the background; nothing queued is fine.
	rec := execRequest(t, router, "POST", "/notifications/flush", nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestNotification_FlushDigestTypeNeedsGroup(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "flushtype@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "POST", "/notifications/flush", map[string]any{
		"type": "meal_plan_changed",
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)

	rec = execRequest(t, router, "POST", "/notifications/flush", map[string]any{
		"group_id": uuid.New().String(),
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)

	rec = execRequest(t, router, "POST", "/notifications/flush", map[string]any{
		"group_id": uuid.New().String(),
		"type":     "chore_due",
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestNotification_IntegrationCredentialIsScopedToNotificationGroups(t *testing.T) {
	userID := uuid.New()
	allowedID := uuid.New()
	deniedID := uuid.New()
	allowedNotification := &models.Notification{
		ID: uuid.New(), UserID: userID, GroupID: allowedID, Type: "test",
		Title: "Allowed", Body: "Visible", IsRead: false, CreatedAt: time.Now().UTC(),
	}
	deniedNotification := &models.Notification{
		ID: uuid.New(), UserID: userID, GroupID: deniedID, Type: "test",
		Title: "Denied", Body: "Hidden", IsRead: false, CreatedAt: time.Now().UTC().Add(-time.Second),
	}
	allowedAllNotification := &models.Notification{
		ID: uuid.New(), UserID: userID, GroupID: allowedID, Type: "test",
		Title: "Allowed All", Body: "Visible", IsRead: false, CreatedAt: time.Now().UTC().Add(-2 * time.Second),
	}

	repo := new(repositoryMocks.MockNotificationRepo)
	repo.On("ListNotificationsByUserAndGroups", mock.Anything, userID, []uuid.UUID{allowedID}, 10, 0).
		Return([]models.Notification{*allowedNotification, *allowedAllNotification}, nil).Once()
	repo.On("CountUnreadNotificationsByGroups", mock.Anything, userID, []uuid.UUID{allowedID}).Return(2, nil).Once()
	repo.On("GetNotificationByID", mock.Anything, allowedNotification.ID).Return(allowedNotification, nil).Times(5)
	repo.On("GetNotificationByID", mock.Anything, deniedNotification.ID).Return(deniedNotification, nil).Times(3)
	repo.On("MarkAsRead", mock.Anything, allowedNotification.ID).Return(nil).Once()
	repo.On("MarkAllAsReadByGroups", mock.Anything, userID, []uuid.UUID{allowedID}).Return(nil).Once()
	repo.On("DeleteNotification", mock.Anything, allowedNotification.ID).Return(nil).Once()

	identity := &services.CredentialIdentity{
		UserID:   userID,
		GroupIDs: []uuid.UUID{allowedID},
		Scopes:   []string{"notifications:read", "notifications:write"},
	}
	handler := newNotificationIntegrationTestRouter(t, repo, identity)

	rec := execRequest(t, handler, "GET", "/notifications?limit=10", nil, "")
	requireStatus(t, rec, http.StatusOK)
	var listed []models.Notification
	parseJSONResponse(t, rec, &listed)
	require.Len(t, listed, 2)
	assert.ElementsMatch(t, []uuid.UUID{allowedNotification.ID, allowedAllNotification.ID}, []uuid.UUID{listed[0].ID, listed[1].ID})

	rec = execRequest(t, handler, "GET", "/notifications/unread-count", nil, "")
	requireStatus(t, rec, http.StatusOK)
	var count map[string]int
	parseJSONResponse(t, rec, &count)
	assert.Equal(t, 2, count["count"])

	rec = execRequest(t, handler, "GET", "/notifications/"+allowedNotification.ID.String(), nil, "")
	requireStatus(t, rec, http.StatusOK)
	rec = execRequest(t, handler, "GET", "/notifications/"+deniedNotification.ID.String(), nil, "")
	requireStatus(t, rec, http.StatusForbidden)

	rec = execRequest(t, handler, "PATCH", "/notifications/"+allowedNotification.ID.String()+"/read", nil, "")
	requireStatus(t, rec, http.StatusNoContent)

	rec = execRequest(t, handler, "PATCH", "/notifications/"+deniedNotification.ID.String()+"/read", nil, "")
	requireStatus(t, rec, http.StatusForbidden)

	rec = execRequest(t, handler, "PATCH", "/notifications/read-all", nil, "")
	requireStatus(t, rec, http.StatusNoContent)

	rec = execRequest(t, handler, "DELETE", "/notifications/"+allowedNotification.ID.String(), nil, "")
	requireStatus(t, rec, http.StatusNoContent)

	rec = execRequest(t, handler, "DELETE", "/notifications/"+deniedNotification.ID.String(), nil, "")
	requireStatus(t, rec, http.StatusForbidden)
	repo.AssertExpectations(t)
}

func TestNotification_IntegrationCredentialIsScopedToPreferenceGroups(t *testing.T) {
	clearTables(t)
	router, _ := newNotificationRouter(t)
	user := createTestUser(t, "integration-pref@example.com", "Password123!")
	token := generateTestToken(user.ID)
	allowed := createNotificationTestGroup(t, user.ID, "Allowed Preferences")
	denied := createNotificationTestGroup(t, user.ID, "Denied Preferences")

	repo := newTestNotificationRepo()
	allowedPref := models.DefaultNotificationPreference(user.ID, allowed.ID)
	allowedPref.PushEnabled = false
	deniedPref := models.DefaultNotificationPreference(user.ID, denied.ID)
	deniedPref.PushEnabled = false
	require.NoError(t, repo.UpsertPreference(context.Background(), allowedPref))
	require.NoError(t, repo.UpsertPreference(context.Background(), deniedPref))

	identity := &services.CredentialIdentity{
		UserID:   user.ID,
		GroupIDs: []uuid.UUID{allowed.ID},
		Scopes:   []string{"notifications:read", "notifications:write"},
	}
	handler := notificationIntegrationHandler(router, identity)

	rec := execRequest(t, handler, "GET", "/notifications/preferences", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var prefs []models.NotificationPreference
	parseJSONResponse(t, rec, &prefs)
	require.Len(t, prefs, 1)
	assert.Equal(t, allowed.ID, prefs[0].GroupID)

	rec = execRequest(t, handler, "GET", "/notifications/preferences?group_id="+allowed.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)
	rec = execRequest(t, handler, "GET", "/notifications/preferences?group_id="+denied.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusForbidden)

	rec = execRequest(t, handler, "PATCH", "/notifications/preferences", map[string]any{
		"group_id":     allowed.ID.String(),
		"push_enabled": true,
	}, token)
	requireStatus(t, rec, http.StatusNoContent)
	updated, err := repo.GetPreference(context.Background(), user.ID, allowed.ID)
	require.NoError(t, err)
	assert.True(t, updated.PushEnabled)

	rec = execRequest(t, handler, "PATCH", "/notifications/preferences", map[string]any{
		"group_id":     denied.ID.String(),
		"push_enabled": true,
	}, token)
	requireStatus(t, rec, http.StatusForbidden)
	unchanged, err := repo.GetPreference(context.Background(), user.ID, denied.ID)
	require.NoError(t, err)
	assert.False(t, unchanged.PushEnabled)
}

func createNotificationTestGroup(t *testing.T, userID uuid.UUID, name string) *models.Group {
	t.Helper()
	group := &models.Group{
		ID: uuid.New(), Name: name, CreatedBy: userID,
		CreatedAt: time.Now().UTC(), UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, newTestGroupRepo().CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, userID, "admin")
	return group
}

func notificationIntegrationHandler(router http.Handler, identity *services.CredentialIdentity) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := middleware.WithIntegrationCredential(r.Context(), identity)
		router.ServeHTTP(w, r.WithContext(ctx))
	})
}

func newNotificationIntegrationTestRouter(t *testing.T, repo repositories.NotificationRepo, identity *services.CredentialIdentity) http.Handler {
	t.Helper()
	svc := services.NewNotificationService(repo, nil, nil, nil)
	handler := NewNotificationHandler(svc)
	router := chi.NewRouter()
	router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := middleware.WithUserID(r.Context(), identity.UserID.String())
			ctx = middleware.WithIntegrationCredential(ctx, identity)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	})
	handler.RegisterRoutes(router)
	return router
}
