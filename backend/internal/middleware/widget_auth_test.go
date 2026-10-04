package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
	"github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
)

// stubCredentialRepo resolves every presented token to one credential.
type stubCredentialRepo struct {
	credential *models.IntegrationCredential
}

func (r *stubCredentialRepo) Create(context.Context, *models.IntegrationCredential, string) error {
	return nil
}
func (r *stubCredentialRepo) ListByUser(context.Context, uuid.UUID) ([]models.IntegrationCredential, error) {
	return nil, nil
}
func (r *stubCredentialRepo) GetActiveByHash(context.Context, string) (*models.IntegrationCredential, error) {
	if r.credential == nil {
		return nil, repositories.ErrIntegrationCredentialNotFound
	}
	return r.credential, nil
}
func (r *stubCredentialRepo) TouchLastUsed(context.Context, uuid.UUID, string, string) error {
	return nil
}
func (r *stubCredentialRepo) Revoke(context.Context, uuid.UUID, uuid.UUID) error { return nil }
func (r *stubCredentialRepo) GetByID(context.Context, uuid.UUID, uuid.UUID) (*models.IntegrationCredential, error) {
	return r.credential, nil
}
func (r *stubCredentialRepo) ReplaceWidgetCredential(context.Context, *models.IntegrationCredential, string) error {
	return nil
}
func (r *stubCredentialRepo) RevokeWidgetCredential(context.Context, uuid.UUID, string) error {
	return nil
}

func credentialAuthHandler(t *testing.T, credential *models.IntegrationCredential) http.Handler {
	t.Helper()
	userRepo := new(mocks.MockUserRepo)
	userRepo.On("GetByID", mock.Anything, credential.UserID).Return(
		&models.User{ID: credential.UserID, IsActive: true, IsVerified: true}, nil)
	userSvc := services.NewUserService(userRepo, nil, nil, nil, nil)
	credentialSvc := services.NewIntegrationCredentialService(&stubCredentialRepo{credential: credential}, nil)
	jwtSvc := jwtservice.New(&config.Config{SecretKey: "test-secret-key-min-32-chars-long!!!", AccessTokenExpireMinutes: 60}, nil)
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	return AuthWithCredentials(jwtSvc, userSvc, credentialSvc)(next)
}

func TestWidgetCredentialReachesOnlyWidgetActions(t *testing.T) {
	group := uuid.New()
	expires := time.Now().Add(time.Hour)
	credential := &models.IntegrationCredential{
		ID: uuid.New(), UserID: uuid.New(), Kind: services.CredentialKindWidget,
		GroupIDs: []uuid.UUID{group}, Scopes: []string{"widget:write", "lists:write", "chores:write"},
		DeviceID: "device-1234", ExpiresAt: &expires,
	}
	handler := credentialAuthHandler(t, credential)
	listID, itemID, choreID := uuid.NewString(), uuid.NewString(), uuid.NewString()

	tests := []struct {
		name   string
		method string
		path   string
		group  string
		want   int
	}{
		{"snapshot", http.MethodGet, "/api/v1/widget/snapshot", "", http.StatusOK},
		{"register push token", http.MethodPut, "/api/v1/widget/push-token", "", http.StatusOK},
		{"tick item", http.MethodPatch, "/api/v1/lists/" + listID + "/items/" + itemID, group.String(), http.StatusOK},
		{"add item", http.MethodPost, "/api/v1/lists/" + listID + "/items", group.String(), http.StatusOK},
		{"complete chore", http.MethodPost, "/api/v1/chores/" + choreID + "/complete", group.String(), http.StatusOK},
		{"complete chore in another household", http.MethodPost, "/api/v1/chores/" + choreID + "/complete", uuid.NewString(), http.StatusForbidden},
		{"complete chore without household", http.MethodPost, "/api/v1/chores/" + choreID + "/complete", "", http.StatusForbidden},
		{"delete list", http.MethodDelete, "/api/v1/lists/" + listID, group.String(), http.StatusForbidden},
		{"delete item", http.MethodDelete, "/api/v1/lists/" + listID + "/items/" + itemID, group.String(), http.StatusForbidden},
		{"read lists", http.MethodGet, "/api/v1/lists", group.String(), http.StatusForbidden},
		{"edit chore", http.MethodPatch, "/api/v1/chores/" + choreID, group.String(), http.StatusForbidden},
		{"skip chore", http.MethodPost, "/api/v1/chores/" + choreID + "/skip", group.String(), http.StatusForbidden},
		{"clear list", http.MethodPost, "/api/v1/lists/" + listID + "/items/clear", group.String(), http.StatusForbidden},
		{"expenses", http.MethodGet, "/api/v1/expenses", group.String(), http.StatusForbidden},
		{"credential management", http.MethodGet, "/api/v1/auth/integration-credentials", "", http.StatusForbidden},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, nil)
			req.Header.Set("Authorization", "Bearer "+services.IntegrationTokenPrefix+"secret")
			if tc.group != "" {
				req.Header.Set("X-Mitlist-Group-ID", tc.group)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			require.Equal(t, tc.want, rec.Code, rec.Body.String())
		})
	}
}

func TestIntegrationCredentialIsNotLimitedToWidgetRoutes(t *testing.T) {
	group := uuid.New()
	credential := &models.IntegrationCredential{
		ID: uuid.New(), UserID: uuid.New(), Kind: services.CredentialKindIntegration,
		GroupIDs: []uuid.UUID{group}, Scopes: []string{"lists:read"},
	}
	handler := credentialAuthHandler(t, credential)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/lists?group_id="+group.String(), nil)
	req.Header.Set("Authorization", "Bearer "+services.IntegrationTokenPrefix+"secret")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())

	// The widget domain needs its own scope; lists:read does not reach it.
	req = httptest.NewRequest(http.MethodGet, "/api/v1/widget/snapshot", nil)
	req.Header.Set("Authorization", "Bearer "+services.IntegrationTokenPrefix+"secret")
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	require.Equal(t, http.StatusForbidden, rec.Code, rec.Body.String())
}

func TestWidgetCredentialAllowsRouteMatchesFromTheEnd(t *testing.T) {
	id := uuid.NewString()
	require.True(t, widgetCredentialAllowsRoute(http.MethodGet, "/custom/prefix/v1/widget/snapshot"))
	require.True(t, widgetCredentialAllowsRoute(http.MethodPatch, "/v1/lists/"+id+"/items/"+id+"/"))
	require.False(t, widgetCredentialAllowsRoute(http.MethodPatch, "/v1/lists/not-an-id/items/"+id))
	require.False(t, widgetCredentialAllowsRoute(http.MethodPost, "/v1/widget/snapshot"))
	require.True(t, widgetCredentialAllowsRoute(http.MethodPut, "/v1/widget/push-token"))
	require.False(t, widgetCredentialAllowsRoute(http.MethodDelete, "/v1/widget/push-token"))
	require.False(t, widgetCredentialAllowsRoute(http.MethodPut, "/v1/lists/"+id+"/items/"+id))
	require.Equal(t, "widget", integrationDomain("/api/v1/widget/snapshot"))
}
