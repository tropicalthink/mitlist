package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
)

// newWidgetRouter mounts the real auth and idempotency middleware, so the
// test covers what a widget meets in production: credential lookup, the
// widget route allowlist, and replay protection.
func newWidgetRouter(t *testing.T) chi.Router {
	t.Helper()
	groupRepo, listRepo := newTestGroupRepo(), newTestListRepo()
	userSvc := services.NewUserService(newTestUserRepo(), newTestAuthRepo(), testJWT, newTestPasswordService(), newTestMailService())
	credentialSvc := services.NewIntegrationCredentialService(repositories.NewIntegrationCredentialRepository(testDB), groupRepo)
	listSvc := services.NewListService(listRepo, groupRepo)
	widgetSvc := services.NewWidgetService(
		services.NewGroupService(groupRepo, newTestUserRepo()),
		listSvc,
		services.NewChoreService(newTestChoreRepo(), groupRepo, listRepo),
	)

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Route("/auth", func(r chi.Router) {
			r.Use(middleware.Auth(testJWT, userSvc))
			NewIntegrationCredentialHandler(credentialSvc).RegisterRoutes(r)
		})
		r.Group(func(r chi.Router) {
			r.Use(middleware.AuthWithCredentials(testJWT, userSvc, credentialSvc))
			r.Use(middleware.Idempotency(testDB))
			NewWidgetHandler(widgetSvc, repositories.NewWidgetDeviceRepository(testDB)).RegisterRoutes(r)
			NewListHandler(listSvc, nil).RegisterRoutes(r)
		})
	})
	return r
}

func widgetRequest(t *testing.T, router http.Handler, method, path, body, token string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestWidgetCredentialEndToEnd(t *testing.T) {
	clearTables(t)
	ctx := context.Background()
	router := newWidgetRouter(t)
	user := createTestUser(t, "widget@example.com", "Password123!")
	session := generateTestToken(user.ID)

	now := time.Now().UTC()
	group := &models.Group{ID: uuid.New(), Name: "Flat 3B", CreatedBy: user.ID, CreatedAt: now, UpdatedAt: now}
	require.NoError(t, newTestGroupRepo().CreateGroup(ctx, group))
	addTestMembership(t, group.ID, user.ID, "admin")
	list := &models.List{ID: uuid.New(), GroupID: group.ID, Name: "Groceries", Type: "shopping", CreatedAt: now, UpdatedAt: now}
	require.NoError(t, newTestListRepo().CreateList(ctx, list))
	milk := &models.ListItem{ID: uuid.New(), ListID: list.ID, Name: "Oat milk", Quantity: 1, AddedBy: &user.ID, CreatedAt: now, UpdatedAt: now}
	require.NoError(t, newTestListRepo().CreateItem(ctx, milk))

	// The app issues a credential for this install.
	rec := execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-0001"}, session)
	requireStatus(t, rec, http.StatusCreated)
	var issued struct {
		Token     string      `json:"token"`
		Kind      string      `json:"kind"`
		GroupIDs  []uuid.UUID `json:"group_ids"`
		ExpiresAt *time.Time  `json:"expires_at"`
	}
	parseJSONResponse(t, rec, &issued)
	require.Equal(t, services.CredentialKindWidget, issued.Kind)
	require.Equal(t, []uuid.UUID{group.ID}, issued.GroupIDs)
	require.NotNil(t, issued.ExpiresAt)
	widget := issued.Token

	// A widget credential cannot manage credentials, even its own.
	rec = execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-0001"}, widget)
	requireStatus(t, rec, http.StatusUnauthorized)

	// Widget credentials are not listed with the person's integrations.
	rec = execRequest(t, router, http.MethodGet, "/api/v1/auth/integration-credentials", nil, session)
	requireStatus(t, rec, http.StatusOK)
	require.JSONEq(t, `[]`, rec.Body.String())

	// The widget reads its snapshot.
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", widget, nil)
	requireStatus(t, rec, http.StatusOK)
	var snapshot services.WidgetSnapshot
	parseJSONResponse(t, rec, &snapshot)
	require.Len(t, snapshot.Households, 1)
	require.Equal(t, "Flat 3B", snapshot.Households[0].Name)
	require.Len(t, snapshot.Households[0].Lists, 1)
	require.Equal(t, 1, snapshot.Households[0].Lists[0].OpenCount)
	require.Equal(t, "Oat milk", snapshot.Households[0].Lists[0].Items[0].Name)
	require.Equal(t, list.ID, *snapshot.Defaults.ListID)

	// The widget ticks the item off.
	tick := `{"checked":true}`
	itemPath := "/api/v1/lists/" + list.ID.String() + "/items/" + milk.ID.String()
	opID := uuid.NewString()
	headers := map[string]string{"X-Mitlist-Group-ID": group.ID.String(), "Idempotency-Key": opID}
	rec = widgetRequest(t, router, http.MethodPatch, itemPath, tick, widget, headers)
	requireStatus(t, rec, http.StatusOK)
	stored, err := newTestListRepo().GetItemByID(ctx, milk.ID)
	require.NoError(t, err)
	require.True(t, stored.Checked)

	// The app later delivers the same queued op with its own session: the
	// server replays the first result instead of applying it twice.
	rec = widgetRequest(t, router, http.MethodPatch, itemPath, tick, session, map[string]string{"Idempotency-Key": opID})
	requireStatus(t, rec, http.StatusOK)
	require.Equal(t, "true", rec.Header().Get("Idempotency-Replayed"))

	// The same key with different bytes is a client bug, not a second op.
	rec = widgetRequest(t, router, http.MethodPatch, itemPath, `{"checked": true}`, widget, headers)
	requireStatus(t, rec, http.StatusConflict)

	// Anything outside the widget actions is refused.
	rec = widgetRequest(t, router, http.MethodDelete, itemPath, "", widget, map[string]string{"X-Mitlist-Group-ID": group.ID.String()})
	requireStatus(t, rec, http.StatusForbidden)

	// Re-issuing replaces the device's credential.
	rec = execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-0001"}, session)
	requireStatus(t, rec, http.StatusCreated)
	parseJSONResponse(t, rec, &issued)
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", widget, nil)
	requireStatus(t, rec, http.StatusUnauthorized)
	widget = issued.Token
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", widget, nil)
	requireStatus(t, rec, http.StatusOK)

	// Signing out everywhere (password change or reset, account deletion)
	// moves the auth cutoff, which voids widget credentials too.
	_, err = testDB.Exec(ctx, `UPDATE users SET auth_valid_after = NOW() WHERE id = $1`, user.ID)
	require.NoError(t, err)
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", widget, nil)
	requireStatus(t, rec, http.StatusUnauthorized)

	// A credential issued after the cutoff works, and sign-out revokes it.
	// Access tokens carry whole-second issue times, so sign in again only
	// once the cutoff's second has passed.
	time.Sleep(1100 * time.Millisecond)
	session = generateTestToken(user.ID)
	rec = execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-0001"}, session)
	requireStatus(t, rec, http.StatusCreated)
	parseJSONResponse(t, rec, &issued)
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", issued.Token, nil)
	requireStatus(t, rec, http.StatusOK)
	rec = execRequest(t, router, http.MethodDelete, "/api/v1/auth/widget-credential?device_id=install-0001", nil, session)
	requireStatus(t, rec, http.StatusNoContent)
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", issued.Token, nil)
	requireStatus(t, rec, http.StatusUnauthorized)
	rec = execRequest(t, router, http.MethodDelete, "/api/v1/auth/widget-credential?device_id=install-0001", nil, session)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestWidgetCredentialExpires(t *testing.T) {
	clearTables(t)
	ctx := context.Background()
	router := newWidgetRouter(t)
	user := createTestUser(t, "widget-expiry@example.com", "Password123!")
	session := generateTestToken(user.ID)

	rec := execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-0002"}, session)
	requireStatus(t, rec, http.StatusCreated)
	var issued struct {
		Token string `json:"token"`
	}
	parseJSONResponse(t, rec, &issued)

	// A credential issued before the person joined any household reads an
	// empty snapshot.
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", issued.Token, nil)
	requireStatus(t, rec, http.StatusOK)
	var snapshot services.WidgetSnapshot
	parseJSONResponse(t, rec, &snapshot)
	require.Empty(t, snapshot.Households)

	_, err := testDB.Exec(ctx, `UPDATE integration_credentials SET expires_at = NOW() - INTERVAL '1 minute' WHERE user_id = $1`, user.ID)
	require.NoError(t, err)
	rec = widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", issued.Token, nil)
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestWidgetPushTokenAndRefreshTargets(t *testing.T) {
	clearTables(t)
	ctx := context.Background()
	router := newWidgetRouter(t)
	devices := repositories.NewWidgetDeviceRepository(testDB)
	user := createTestUser(t, "widget-push@example.com", "Password123!")
	other := createTestUser(t, "no-widgets@example.com", "Password123!")
	session := generateTestToken(user.ID)

	now := time.Now().UTC()
	group := &models.Group{ID: uuid.New(), Name: "Flat 3B", CreatedBy: user.ID, CreatedAt: now, UpdatedAt: now}
	require.NoError(t, newTestGroupRepo().CreateGroup(ctx, group))
	addTestMembership(t, group.ID, user.ID, "admin")
	list := &models.List{ID: uuid.New(), GroupID: group.ID, Name: "Groceries", Type: "shopping", CreatedAt: now, UpdatedAt: now}
	require.NoError(t, newTestListRepo().CreateList(ctx, list))

	issue := func() string {
		rec := execRequest(t, router, http.MethodPost, "/api/v1/auth/widget-credential", map[string]any{"device_id": "install-push-1"}, session)
		requireStatus(t, rec, http.StatusCreated)
		var issued struct {
			Token string `json:"token"`
		}
		parseJSONResponse(t, rec, &issued)
		return issued.Token
	}
	widget := issue()

	users, err := devices.ListUsersWithWidgets(ctx, []uuid.UUID{user.ID, other.ID})
	require.NoError(t, err)
	require.Equal(t, []uuid.UUID{user.ID}, users)

	// Only the widget credential itself registers a push token.
	pushToken := strings.Repeat("ab", 32)
	body := `{"token":"` + strings.ToUpper(pushToken) + `"}`
	requireStatus(t, widgetRequest(t, router, http.MethodPut, "/api/v1/widget/push-token", body, session, nil), http.StatusForbidden)
	requireStatus(t, widgetRequest(t, router, http.MethodPut, "/api/v1/widget/push-token", `{"token":"not hex"}`, widget, nil), http.StatusBadRequest)
	requireStatus(t, widgetRequest(t, router, http.MethodPut, "/api/v1/widget/push-token", body, widget, nil), http.StatusNoContent)
	tokens, err := devices.ListPushTokens(ctx, []uuid.UUID{user.ID})
	require.NoError(t, err)
	require.Equal(t, []string{pushToken}, tokens)

	// The widget adds an item with the exact body the queue stores.
	rec := widgetRequest(t, router, http.MethodPost, "/api/v1/lists/"+list.ID.String()+"/items", `{"name":"Butter"}`, widget,
		map[string]string{"X-Mitlist-Group-ID": group.ID.String(), "Idempotency-Key": uuid.NewString()})
	requireStatus(t, rec, http.StatusCreated)
	require.Contains(t, rec.Body.String(), `"name":"Butter"`)

	// Renewing the credential keeps the install's push token.
	widget = issue()
	tokens, err = devices.ListPushTokens(ctx, []uuid.UUID{user.ID})
	require.NoError(t, err)
	require.Equal(t, []string{pushToken}, tokens)
	requireStatus(t, widgetRequest(t, router, http.MethodGet, "/api/v1/widget/snapshot", "", widget, nil), http.StatusOK)

	// APNs reported the token dead.
	require.NoError(t, devices.ClearPushToken(ctx, pushToken))
	tokens, err = devices.ListPushTokens(ctx, []uuid.UUID{user.ID})
	require.NoError(t, err)
	require.Empty(t, tokens)

	// After sign-out the device no longer gets refresh pushes.
	rec = execRequest(t, router, http.MethodDelete, "/api/v1/auth/widget-credential?device_id=install-push-1", nil, session)
	requireStatus(t, rec, http.StatusNoContent)
	users, err = devices.ListUsersWithWidgets(ctx, []uuid.UUID{user.ID})
	require.NoError(t, err)
	require.Empty(t, users)
	requireStatus(t, widgetRequest(t, router, http.MethodPut, "/api/v1/widget/push-token", body, widget, nil), http.StatusUnauthorized)
}
