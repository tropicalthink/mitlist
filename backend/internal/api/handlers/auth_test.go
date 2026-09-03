package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	appcheckservice "github.com/mitlist-app/mitlist/internal/services/appcheck"
	turnstileservice "github.com/mitlist-app/mitlist/internal/services/turnstile"
)

func TestAuth_Register(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	body := map[string]any{
		"email":      "auth@example.com",
		"password":   "Password123!",
		"first_name": "Auth",
		"last_name":  "Test",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusAccepted)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.Equal(t, true, resp["verification_required"])
	require.Nil(t, resp["access_token"])
	require.Nil(t, resp["refresh_token"])
}

func TestAuth_Register_DuplicateEmail(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	body := map[string]any{
		"email":      "dup@example.com",
		"password":   "Password123!",
		"first_name": "Dup",
		"last_name":  "Test",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusAccepted)

	rec = execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	// Duplicate registration does not reveal whether the address is already
	// active; it receives the same generic acknowledgement as other requests.
	requireStatus(t, rec, http.StatusAccepted)
}

func TestAuth_Login(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	createTestUser(t, "login@example.com", "Password123!")

	body := map[string]any{
		"email":    "login@example.com",
		"password": "Password123!",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/login", body, "")
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotNil(t, resp["access_token"])
}

func TestAuth_Login_InvalidCredentials(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	createTestUser(t, "bad@example.com", "Password123!")

	body := map[string]any{
		"email":    "bad@example.com",
		"password": "wrongpassword",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/login", body, "")
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestAuth_Login_UnverifiedIsActionable(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "unverified@example.com", "Password123!")
	user.IsVerified = false
	require.NoError(t, newTestUserRepo().Update(context.Background(), user))

	body := map[string]any{"email": "unverified@example.com", "password": "Password123!"}
	rec := execRequest(t, router, "POST", "/api/v1/auth/login", body, "")
	requireStatus(t, rec, http.StatusForbidden)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	// The client keys off this code to open the verification step, so it
	// must stay distinct from a wrong password's validation_error.
	assert.Equal(t, "email_unverified", resp["error"])

	// A wrong password on the same account must not leak the unverified
	// state: it is a plain credential failure.
	body["password"] = "wrong"
	rec = execRequest(t, router, "POST", "/api/v1/auth/login", body, "")
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestAuth_CodeEmailsAreThrottledPerAddress(t *testing.T) {
	clearTables(t)
	router, _, mail := newAuthRouterWithMail(t)
	user := createTestUser(t, "throttle@example.com", "Password123!")
	user.IsVerified = false
	require.NoError(t, newTestUserRepo().Update(context.Background(), user))

	body := map[string]any{"email": "throttle@example.com"}
	for i := 0; i < 5; i++ {
		rec := execRequest(t, router, "POST", "/api/v1/auth/verify-email/resend", body, "")
		// Same answer every time: a throttled request is indistinguishable
		// from a delivered one, so the address is never confirmed.
		requireStatus(t, rec, http.StatusOK)
	}
	assert.Len(t, mail.messages, 3, "only the first three resends reach the mailer")

	// Password reset has its own budget under a separate key.
	user.IsVerified = true
	require.NoError(t, newTestUserRepo().Update(context.Background(), user))
	for i := 0; i < 5; i++ {
		rec := execRequest(t, router, "POST", "/api/v1/auth/password-reset", body, "")
		requireStatus(t, rec, http.StatusAccepted)
	}
	assert.Len(t, mail.messages, 6)
}

func TestAuth_OAuthLinkTokenIsForGuestsOnly(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	rec := execRequest(t, router, "POST", "/api/v1/auth/guest", map[string]any{}, "")
	requireStatus(t, rec, http.StatusCreated)
	var guest map[string]any
	parseJSONResponse(t, rec, &guest)
	guestToken, _ := guest["access_token"].(string)

	rec = execRequest(t, router, "POST", "/api/v1/auth/oauth-link", nil, guestToken)
	requireStatus(t, rec, http.StatusCreated)
	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	token, _ := resp["link_token"].(string)
	require.NotEmpty(t, token)

	// A real account has nothing to upgrade.
	full := createTestUser(t, "linked@example.com", "Password123!")
	rec = execRequest(t, router, "POST", "/api/v1/auth/oauth-link", nil, generateTestToken(full.ID))
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestAuth_PasswordRoutesDisabled(t *testing.T) {
	clearTables(t)
	cfg := *testCfg
	cfg.PasswordAuthEnabled = false
	router, _, _ := newAuthRouterWithConfig(t, &cfg)
	createTestUser(t, "gated@example.com", "Password123!")

	// Every route that creates, checks or changes a password is off; the
	// caller gets one stable, explained refusal rather than a 404.
	public := []struct {
		path string
		body map[string]any
	}{
		{"/api/v1/auth/register", map[string]any{"email": "new@example.com", "password": "Password123!", "first_name": "New", "last_name": "User"}},
		{"/api/v1/auth/login", map[string]any{"email": "gated@example.com", "password": "Password123!"}},
		{"/api/v1/auth/verify-email", map[string]any{"token": "000000"}},
		{"/api/v1/auth/verify-email/resend", map[string]any{"email": "gated@example.com"}},
		{"/api/v1/auth/password-reset", map[string]any{"email": "gated@example.com"}},
		{"/api/v1/auth/password-reset/confirm", map[string]any{"token": "x", "new_password": "Password123!"}},
	}
	for _, tc := range public {
		rec := execRequest(t, router, "POST", tc.path, tc.body, "")
		requireStatus(t, rec, http.StatusForbidden)
		var resp map[string]any
		parseJSONResponse(t, rec, &resp)
		assert.Equal(t, "permission_denied", resp["code"], tc.path)
	}

	// Sessions that exist keep working: refresh, logout and guest creation
	// are not password features.
	rec := execRequest(t, router, "POST", "/api/v1/auth/guest", map[string]any{}, "")
	requireStatus(t, rec, http.StatusCreated)

	var guest map[string]any
	parseJSONResponse(t, rec, &guest)
	token, _ := guest["access_token"].(string)
	require.NotEmpty(t, token)

	rec = execRequest(t, router, "GET", "/api/v1/auth/me", nil, token)
	requireStatus(t, rec, http.StatusOK)

	authed := []struct {
		path string
		body map[string]any
	}{
		{"/api/v1/auth/change-password", map[string]any{"old_password": "Password123!", "new_password": "Password456!"}},
		{"/api/v1/auth/guest/convert", map[string]any{"email": "g@example.com", "password": "Password123!", "first_name": "G", "last_name": "U"}},
		{"/api/v1/auth/claim-account", map[string]any{"password": "Password123!", "first_name": "G", "last_name": "U"}},
	}
	for _, tc := range authed {
		rec := execRequest(t, router, "POST", tc.path, tc.body, token)
		requireStatus(t, rec, http.StatusForbidden)
	}
}

func TestAuth_GetMe(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "me@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/auth/me", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "me@example.com", resp["email"])
}

func TestAuth_GetMe_Unauthorized(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	rec := execRequest(t, router, "GET", "/api/v1/auth/me", nil, "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestAuth_UpdateMe(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "update@example.com", "Password123!")
	token := generateTestToken(user.ID)

	body := map[string]any{"first_name": "Updated"}
	rec := execRequest(t, router, "PATCH", "/api/v1/auth/me", body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Updated", resp["first_name"])
}

func TestAuth_DeleteMe(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "delete@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "DELETE", "/api/v1/auth/me", nil, token)
	requireStatus(t, rec, http.StatusNoContent)

	// After deletion the user no longer exists, so the token can no longer
	// resolve to a user and the request is rejected as unauthorized.
	rec = execRequest(t, router, "GET", "/api/v1/auth/me", nil, token)
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestAuth_ChangePassword(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "changepw@example.com", "Oldpassword12!")
	token := generateTestToken(user.ID)

	body := map[string]any{
		"old_password": "Oldpassword12!",
		"new_password": "newPassword123!",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/change-password", body, token)
	requireStatus(t, rec, http.StatusOK)

	loginBody := map[string]any{
		"email":    "changepw@example.com",
		"password": "newPassword123!",
	}
	rec = execRequest(t, router, "POST", "/api/v1/auth/login", loginBody, "")
	requireStatus(t, rec, http.StatusOK)
}

func TestAuth_PasswordReset(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	createTestUser(t, "reset@example.com", "Password123!")

	body := map[string]any{"email": "reset@example.com"}
	rec := execRequest(t, router, "POST", "/api/v1/auth/password-reset", body, "")
	requireStatus(t, rec, http.StatusAccepted)
}

func TestAuth_Guest(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	rec := execRequest(t, router, "POST", "/api/v1/auth/guest", nil, "")
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotNil(t, resp["access_token"])
	require.NotNil(t, resp["user"])
	assert.True(t, resp["user"].(map[string]any)["is_guest"].(bool))
}

func TestAuth_GuestRejectsMissingRequiredAppCheckToken(t *testing.T) {
	clearTables(t)
	router, handler := newAuthRouter(t)
	handler.appCheck = appcheckservice.NewForTesting(
		"1234567890",
		"https://jwks.test",
		nil,
	)

	rec := execRequest(t, router, "POST", "/api/v1/auth/guest", nil, "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

// siteverifyStub stands in for Cloudflare, answering every request with the
// given body.
func siteverifyStub(t *testing.T, body string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func guestWithHeader(t *testing.T, router http.Handler, header, value string) *httptest.ResponseRecorder {
	t.Helper()
	req := buildRequest(t, "POST", "/api/v1/auth/guest", nil, "")
	if header != "" {
		req.Header.Set(header, value)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestAuth_GuestAcceptsTurnstileToken(t *testing.T) {
	clearTables(t)
	router, handler := newAuthRouter(t)
	stub := siteverifyStub(t, `{"success":true,"hostname":"app.mitlist.me"}`)
	handler.turnstile = turnstileservice.NewForTesting("secret", stub.URL, stub.Client())

	rec := guestWithHeader(t, router, "X-Mitlist-Turnstile", "solved")
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.True(t, resp["user"].(map[string]any)["is_guest"].(bool))
}

func TestAuth_GuestRejectsMissingTurnstileToken(t *testing.T) {
	clearTables(t)
	router, handler := newAuthRouter(t)
	stub := siteverifyStub(t, `{"success":true}`)
	handler.turnstile = turnstileservice.NewForTesting("secret", stub.URL, stub.Client())

	rec := guestWithHeader(t, router, "", "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestAuth_GuestRejectsFailedTurnstileChallenge(t *testing.T) {
	clearTables(t)
	router, handler := newAuthRouter(t)
	stub := siteverifyStub(t, `{"success":false,"error-codes":["invalid-input-response"]}`)
	handler.turnstile = turnstileservice.NewForTesting("secret", stub.URL, stub.Client())

	rec := guestWithHeader(t, router, "X-Mitlist-Turnstile", "forged")
	requireStatus(t, rec, http.StatusUnauthorized)
}

// The bypass worth guarding: with both enforced, dropping the App Check header
// must fall through to Turnstile rather than skipping attestation entirely.
func TestAuth_GuestWithBothEnforcedStillRequiresOneProof(t *testing.T) {
	clearTables(t)
	router, handler := newAuthRouter(t)
	stub := siteverifyStub(t, `{"success":true,"hostname":"app.mitlist.me"}`)
	handler.appCheck = appcheckservice.NewForTesting("1234567890", "https://jwks.test", nil)
	handler.turnstile = turnstileservice.NewForTesting("secret", stub.URL, stub.Client())

	requireStatus(t, guestWithHeader(t, router, "", ""), http.StatusUnauthorized)
	requireStatus(t, guestWithHeader(t, router, "X-Mitlist-Turnstile", "solved"), http.StatusCreated)
}

func TestAuth_Refresh(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "refresh@example.com", "Password123!")
	_, refresh, err := testJWT.GenerateTokenPair(user.ID.String(), nil)
	require.NoError(t, err)

	body := map[string]any{"refresh_token": refresh}
	rec := execRequest(t, router, "POST", "/api/v1/auth/token/refresh", body, "")
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotNil(t, resp["access_token"])
}

func TestAuth_Refresh_RotatesToken(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "refresh-rotate@example.com", "Password123!")
	_, refresh, err := testJWT.GenerateTokenPair(user.ID.String(), nil)
	require.NoError(t, err)

	body := map[string]any{"refresh_token": refresh}
	rec := execRequest(t, router, "POST", "/api/v1/auth/token/refresh", body, "")
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	require.NotNil(t, resp["access_token"])
	require.NotNil(t, resp["refresh_token"])

	// Old refresh token should now be revoked
	rec = execRequest(t, router, "POST", "/api/v1/auth/token/refresh", body, "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestAuth_Logout(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "logout@example.com", "Password123!")
	_, refresh, err := testJWT.GenerateTokenPair(user.ID.String(), nil)
	require.NoError(t, err)

	body := map[string]any{"refresh_token": refresh}
	rec := execRequest(t, router, "POST", "/api/v1/auth/logout", body, "")
	requireStatus(t, rec, http.StatusNoContent)
}
