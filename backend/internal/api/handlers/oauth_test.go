package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/config"
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

func TestOAuth_GetProviders_ReflectsConfiguration(t *testing.T) {
	cases := []struct {
		name string
		cfg  func() *config.Config
		want string
	}{
		{
			name: "none configured",
			cfg:  func() *config.Config { return &config.Config{} },
			want: `{"apple":false,"google":false}`,
		},
		{
			name: "google only",
			cfg: func() *config.Config {
				return &config.Config{GoogleClientID: "id", GoogleClientSecret: "secret"}
			},
			want: `{"apple":false,"google":true}`,
		},
		{
			name: "google secret missing",
			cfg: func() *config.Config {
				return &config.Config{GoogleClientID: "id"}
			},
			want: `{"apple":false,"google":false}`,
		},
		{
			name: "both configured",
			cfg: func() *config.Config {
				return &config.Config{
					GoogleClientID:     "id",
					GoogleClientSecret: "secret",
					AppleClientID:      "me.mitlist",
					AppleTeamID:        "TEAM",
					AppleKeyID:         "KEY",
					ApplePrivateKey:    "pem",
				}
			},
			want: `{"apple":true,"google":true}`,
		},
		{
			name: "apple partially configured",
			cfg: func() *config.Config {
				return &config.Config{AppleClientID: "me.mitlist", AppleTeamID: "TEAM"}
			},
			want: `{"apple":false,"google":false}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := NewOAuthHandler(tc.cfg(), nil)
			r := chi.NewRouter()
			r.Get("/api/v1/auth/oauth/providers", h.GetProviders)

			rec := httptest.NewRecorder()
			req := httptest.NewRequest("GET", "/api/v1/auth/oauth/providers", nil)
			r.ServeHTTP(rec, req)

			require.Equal(t, http.StatusOK, rec.Code)
			assert.JSONEq(t, tc.want, rec.Body.String())
		})
	}
}
