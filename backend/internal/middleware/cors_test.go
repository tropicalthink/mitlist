package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestTestingSignupCorsIsLimitedToPublicSubmission(t *testing.T) {
	handler := CorsMiddleware("https://app.mitlist.me", "production", PublicRouteOrigin{
		Path: "/api/v1/testing/signups", Origin: "https://mitlist.me",
	})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }))
	for _, tc := range []struct {
		path, method, origin string
		allowed              bool
	}{
		{"/api/v1/testing/signups", "POST", "https://mitlist.me", true},
		{"/api/v1/testing/signups", "OPTIONS", "https://mitlist.me", true},
		{"/api/v1/testing/signups", "POST", "https://evil.example", false},
		{"/api/v1/testing/signups/export", "GET", "https://mitlist.me", false},
		{"/api/v1/auth/me", "GET", "https://mitlist.me", false},
	} {
		req := httptest.NewRequest(tc.method, tc.path, nil)
		req.Header.Set("Origin", tc.origin)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		require.Equal(t, tc.allowed, rec.Header().Get("Access-Control-Allow-Origin") != "", tc.path)
		require.Empty(t, rec.Header().Get("Access-Control-Allow-Credentials"))
	}
}

func TestCorsMiddlewareAllowsConfiguredOrigin(t *testing.T) {
	handler := CorsMiddleware("http://localhost:5173", "production")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/register", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	require.Equal(t, "http://localhost:5173", rec.Header().Get("Access-Control-Allow-Origin"))
	require.Equal(t, "true", rec.Header().Get("Access-Control-Allow-Credentials"))
}

func TestCorsMiddlewareAllowsLocalhostOriginsInDevelopment(t *testing.T) {
	handler := CorsMiddleware("http://localhost:5173", "development")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodOptions, "/api/v1/auth/register", nil)
	req.Header.Set("Origin", "http://127.0.0.1:64516")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	require.Equal(t, http.StatusNoContent, rec.Code)
	require.Equal(t, "http://127.0.0.1:64516", rec.Header().Get("Access-Control-Allow-Origin"))
	require.Equal(t, "Origin", rec.Header().Get("Vary"))
}

func TestCorsMiddlewareRejectsUnexpectedOriginOutsideDevelopment(t *testing.T) {
	handler := CorsMiddleware("http://localhost:5173", "production")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/register", nil)
	req.Header.Set("Origin", "http://127.0.0.1:64516")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	require.Empty(t, rec.Header().Get("Access-Control-Allow-Origin"))
}

func TestCorsMiddlewareRejectsNonHTTPDevelopmentOrigin(t *testing.T) {
	handler := CorsMiddleware("http://localhost:5173", "development")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/register", nil)
	req.Header.Set("Origin", "chrome-extension://localhost")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	require.Empty(t, rec.Header().Get("Access-Control-Allow-Origin"))
}
