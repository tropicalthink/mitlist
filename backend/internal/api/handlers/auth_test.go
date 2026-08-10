package handlers

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAuth_Register(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)

	body := map[string]any{
		"email":      "auth@example.com",
		"password":   "password123!",
		"first_name": "Auth",
		"last_name":  "Test",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusCreated)

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
		"password":   "password123!",
		"first_name": "Dup",
		"last_name":  "Test",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusCreated)

	rec = execRequest(t, router, "POST", "/api/v1/auth/register", body, "")
	requireStatus(t, rec, http.StatusConflict)
}

func TestAuth_Login(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	createTestUser(t, "login@example.com", "password123!")

	body := map[string]any{
		"email":    "login@example.com",
		"password": "password123!",
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
	createTestUser(t, "bad@example.com", "password123!")

	body := map[string]any{
		"email":    "bad@example.com",
		"password": "wrongpassword",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/login", body, "")
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestAuth_GetMe(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "me@example.com", "password123!")
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
	user := createTestUser(t, "update@example.com", "password123!")
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
	user := createTestUser(t, "delete@example.com", "password123!")
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
	user := createTestUser(t, "changepw@example.com", "oldpassword12!")
	token := generateTestToken(user.ID)

	body := map[string]any{
		"old_password": "oldpassword12!",
		"new_password": "newpassword123!",
	}
	rec := execRequest(t, router, "POST", "/api/v1/auth/change-password", body, token)
	requireStatus(t, rec, http.StatusOK)

	loginBody := map[string]any{
		"email":    "changepw@example.com",
		"password": "newpassword123!",
	}
	rec = execRequest(t, router, "POST", "/api/v1/auth/login", loginBody, "")
	requireStatus(t, rec, http.StatusOK)
}

func TestAuth_PasswordReset(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	createTestUser(t, "reset@example.com", "password123!")

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

func TestAuth_Refresh(t *testing.T) {
	clearTables(t)
	router, _ := newAuthRouter(t)
	user := createTestUser(t, "refresh@example.com", "password123!")
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
	user := createTestUser(t, "refresh-rotate@example.com", "password123!")
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
	user := createTestUser(t, "logout@example.com", "password123!")
	_, refresh, err := testJWT.GenerateTokenPair(user.ID.String(), nil)
	require.NoError(t, err)

	body := map[string]any{"refresh_token": refresh}
	rec := execRequest(t, router, "POST", "/api/v1/auth/logout", body, "")
	requireStatus(t, rec, http.StatusNoContent)
}
