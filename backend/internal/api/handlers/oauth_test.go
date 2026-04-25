package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestOAuth_GoogleCallback_MissingStateCookie(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Post("/api/v1/auth/oauth/google/callback", h.PostGoogleCallback)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/auth/oauth/google/callback", strings.NewReader(`{"code":"c","redirect_uri":"http://localhost","state":"s"}`))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(rec, req)

	require.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "invalid oauth state")

	cookies := rec.Result().Cookies()
	found := false
	for _, c := range cookies {
		if c.Name == "oauth_state" && c.MaxAge == -1 {
			found = true
			break
		}
	}
	assert.True(t, found, "oauth_state cookie should be cleared")
}

func TestOAuth_GoogleCallback_MismatchedState(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Post("/api/v1/auth/oauth/google/callback", h.PostGoogleCallback)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/auth/oauth/google/callback", strings.NewReader(`{"code":"c","redirect_uri":"http://localhost","state":"request_state"}`))
	req.Header.Set("Content-Type", "application/json")
	req.AddCookie(&http.Cookie{Name: "oauth_state", Value: "cookie_state"})
	r.ServeHTTP(rec, req)

	require.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "invalid oauth state")
}

func TestOAuth_AppleCallback_MissingStateCookie(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Post("/api/v1/auth/oauth/apple/callback", h.PostAppleCallback)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/auth/oauth/apple/callback", strings.NewReader(`{"code":"c","redirect_uri":"http://localhost","id_token":"i","state":"s"}`))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(rec, req)

	require.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "invalid oauth state")

	cookies := rec.Result().Cookies()
	found := false
	for _, c := range cookies {
		if c.Name == "oauth_state" && c.MaxAge == -1 {
			found = true
			break
		}
	}
	assert.True(t, found, "oauth_state cookie should be cleared")
}

func TestOAuth_AppleCallback_MismatchedState(t *testing.T) {
	clearTables(t)
	h := NewOAuthHandler(testCfg, nil)
	r := chi.NewRouter()
	r.Post("/api/v1/auth/oauth/apple/callback", h.PostAppleCallback)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/auth/oauth/apple/callback", strings.NewReader(`{"code":"c","redirect_uri":"http://localhost","id_token":"i","state":"request_state"}`))
	req.Header.Set("Content-Type", "application/json")
	req.AddCookie(&http.Cookie{Name: "oauth_state", Value: "cookie_state"})
	r.ServeHTTP(rec, req)

	require.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "invalid oauth state")
}
