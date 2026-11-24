package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/require"
)

// newAuthRouterWithoutEmail is the auth router of a self-host that turned
// password auth on but configured no email provider.
func newAuthRouterWithoutEmail(t *testing.T) (chi.Router, *AuthHandler, *captureMailService) {
	t.Helper()
	r, h, ms := newAuthRouterWithConfig(t, testCfg)
	h.userService.SetEmailConfigured(false)
	return r, h, ms
}

func TestAuth_Register_NoEmailProvider_SignsInLikeLogin(t *testing.T) {
	clearTables(t)
	router, _, mail := newAuthRouterWithoutEmail(t)

	body := map[string]any{
		"email":      "Selfhost@Example.com",
		"password":   "Password123!",
		"first_name": "Self",
		"last_name":  "Host",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotEmpty(t, resp["access_token"])
	require.NotEmpty(t, resp["refresh_token"])
	require.Nil(t, resp["verification_required"])
	user, ok := resp["user"].(map[string]any)
	require.True(t, ok, "token response carries the user like Login does")
	require.Equal(t, "selfhost@example.com", user["email"])
	require.Empty(t, mail.messages, "nothing can be emailed without a provider")

	// The account is real and usable: the password signs in afterwards.
	rec = execRequest(t, router, "POST", "/api/v1/auth/login", map[string]any{
		"email": "selfhost@example.com", "password": "Password123!",
	}, "")
	requireStatus(t, rec, http.StatusOK)

	// And its address is recorded as claimed, not proven.
	var unproven bool
	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT email_unproven FROM users WHERE email = $1`, "selfhost@example.com").Scan(&unproven))
	require.True(t, unproven)
}

func TestAuth_Register_NoEmailProvider_WebGetsCookieNotBodyToken(t *testing.T) {
	clearTables(t)
	router, _, _ := newAuthRouterWithoutEmail(t)

	req := buildRequest(t, "POST", "/api/v1/auth/register", map[string]any{
		"email": "web@example.com", "password": "Password123!",
	}, "")
	req.Header.Set("X-Mitlist-Client", "web")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotEmpty(t, resp["access_token"])
	require.Nil(t, resp["refresh_token"], "web clients get the refresh token as a cookie only")
	var found bool
	for _, c := range rec.Result().Cookies() {
		if c.Name == refreshCookieName && c.Value != "" && c.HttpOnly {
			found = true
		}
	}
	require.True(t, found, "refresh cookie set exactly as Login sets it")
}

func TestAuth_Register_NoEmailProvider_DuplicateIsAConflict(t *testing.T) {
	clearTables(t)
	router, _, _ := newAuthRouterWithoutEmail(t)

	body := map[string]any{"email": "dup@example.com", "password": "Password123!"}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusCreated)

	// With no code to send, the generic "check your email" answer would
	// strand the person; they are told to sign in instead.
	rec = execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusConflict)
}

func TestAuth_PasswordReset_NoEmailProvider_IsRefused(t *testing.T) {
	clearTables(t)
	router, _, mail := newAuthRouterWithoutEmail(t)
	createTestUser(t, "forgot@example.com", "Password123!")

	for _, email := range []string{"forgot@example.com", "nobody@example.com"} {
		rec := execRequest(t, router, "POST", "/api/v1/auth/password-reset", map[string]any{"email": email}, "")
		requireStatus(t, rec, http.StatusForbidden)
		resp := parseErrorResponse(t, rec)
		require.Equal(t, "email_unavailable", resp["error"])
	}
	require.Empty(t, mail.messages)
}

func TestAuth_Register_WithEmailProvider_StillRequiresVerification(t *testing.T) {
	clearTables(t)
	router, h, mail := newAuthRouterWithConfig(t, testCfg)
	h.userService.SetEmailConfigured(true)

	rec := execRequest(t, router, "POST", "/api/v1/auth/register", map[string]any{
		"email": "mailed@example.com", "password": "Password123!",
	}, "")
	requireStatus(t, rec, http.StatusAccepted)
	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.Equal(t, true, resp["verification_required"])
	require.Nil(t, resp["access_token"])
	require.NotEmpty(t, mail.verificationCodeFor(t, "mailed@example.com"))
}
