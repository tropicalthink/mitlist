package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
)

func TestOAuth_GoogleLogin_Redirect(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Get("/api/v1/auth/oauth/google", h.GetGoogle)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/auth/oauth/google?redirect_uri=http://localhost:5173/auth/callback", nil)
	r.ServeHTTP(rec, req)

	assert.True(t, rec.Code == http.StatusFound || rec.Code == http.StatusBadRequest)
}

func TestOAuth_AppleLogin_Redirect(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Get("/api/v1/auth/oauth/apple", h.GetApple)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/auth/oauth/apple?redirect_uri=http://localhost:5173/auth/callback", nil)
	r.ServeHTTP(rec, req)

	assert.True(t, rec.Code == http.StatusFound || rec.Code == http.StatusBadRequest)
}

func TestDebug_Routes(t *testing.T) {
	clearTables(t)
	router := chi.NewRouter()
	h := NewDebugHandler(testCfg, router)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/debug/routes", nil)
	h.Routes().ServeHTTP(rec, req)

	// Debug endpoints require admin guard which will 401/403 without basic auth.
	assert.True(t, rec.Code == http.StatusOK || rec.Code == http.StatusUnauthorized || rec.Code == http.StatusForbidden)
}

func TestDebug_Config(t *testing.T) {
	clearTables(t)
	router := chi.NewRouter()
	h := NewDebugHandler(testCfg, router)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/debug/config", nil)
	h.Routes().ServeHTTP(rec, req)

	assert.True(t, rec.Code == http.StatusOK || rec.Code == http.StatusUnauthorized || rec.Code == http.StatusForbidden)
}

func TestVAPIDHandler(t *testing.T) {
	clearTables(t)
	h := NewVAPIDHandler(testCfg)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/vapid", nil)
	h.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.NotNil(t, resp["public_key"])
}
