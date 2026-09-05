package handlers

import (
	"net/http"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// resetCodeFor reads the recovery code from the most recent reset email to
// the address, the way verificationCodeFor does for sign-up codes.
func (m *captureMailService) resetCodeFor(t *testing.T, to string) string {
	t.Helper()
	const marker = "reset code is: "
	for i := len(m.messages) - 1; i >= 0; i-- {
		msg := m.messages[i]
		if msg.to != to {
			continue
		}
		idx := strings.Index(msg.body, marker)
		require.GreaterOrEqual(t, idx, 0, "no reset code in message to %s", to)
		code := msg.body[idx+len(marker):]
		if nl := strings.IndexAny(code, "\r\n"); nl >= 0 {
			code = code[:nl]
		}
		return strings.TrimSpace(code)
	}
	t.Fatalf("no message captured for %s", to)
	return ""
}

// The emailed code proves the address, so confirming a reset signs the person
// in: the response is a session, not a "now go log in" message.
func TestAuth_PasswordResetConfirmSignsIn(t *testing.T) {
	clearTables(t)
	router, _, ms := newAuthRouterWithMail(t)
	createTestUser(t, "reset@example.com", "OldPassword123!")

	rec := execRequest(t, router, "POST", "/api/v1/auth/password-reset",
		map[string]any{"email": "reset@example.com"}, "")
	requireStatus(t, rec, http.StatusAccepted)
	code := ms.resetCodeFor(t, "reset@example.com")
	require.NotEmpty(t, code)

	rec = execRequest(t, router, "POST", "/api/v1/auth/password-reset/confirm",
		map[string]any{"token": code, "new_password": "NewPassword456!"}, "")
	requireStatus(t, rec, http.StatusOK)

	var session map[string]any
	parseJSONResponse(t, rec, &session)
	assert.NotEmpty(t, session["access_token"], "confirm must issue a session")
	assert.NotEmpty(t, session["refresh_token"], "native clients get the refresh token in the body")
	user, _ := session["user"].(map[string]any)
	require.NotNil(t, user)
	assert.Equal(t, "reset@example.com", user["email"])

	// The session is live.
	rec = execRequest(t, router, "POST", "/api/v1/auth/token/refresh",
		map[string]any{"refresh_token": session["refresh_token"]}, "")
	requireStatus(t, rec, http.StatusOK)

	// The password actually changed, and the code is single-use.
	rec = execRequest(t, router, "POST", "/api/v1/auth/login",
		map[string]any{"email": "reset@example.com", "password": "NewPassword456!"}, "")
	requireStatus(t, rec, http.StatusOK)
	rec = execRequest(t, router, "POST", "/api/v1/auth/login",
		map[string]any{"email": "reset@example.com", "password": "OldPassword123!"}, "")
	require.NotEqual(t, http.StatusOK, rec.Code, "old password must stop working")
	rec = execRequest(t, router, "POST", "/api/v1/auth/password-reset/confirm",
		map[string]any{"token": code, "new_password": "Another789!"}, "")
	require.NotEqual(t, http.StatusOK, rec.Code, "a consumed code must not reset again")
}

// The reset email is the styled one: an HTML part with the button link and a
// text part carrying the code, both pointing at the app's reset screen.
func TestAuth_PasswordResetEmailCarriesAppLink(t *testing.T) {
	clearTables(t)
	router, _, ms := newAuthRouterWithMail(t)
	createTestUser(t, "linked@example.com", "OldPassword123!")

	rec := execRequest(t, router, "POST", "/api/v1/auth/password-reset",
		map[string]any{"email": "linked@example.com"}, "")
	requireStatus(t, rec, http.StatusAccepted)

	code := ms.resetCodeFor(t, "linked@example.com")
	last := ms.messages[len(ms.messages)-1]
	assert.Equal(t, "Reset your mitlist password", last.subject)
	assert.Contains(t, last.body, "/reset-password?token="+code)
}
