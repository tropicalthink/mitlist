package handlers

import (
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAdminGuard_NoCredentials(t *testing.T) {
	t.Setenv("ADMIN_USER", "")
	t.Setenv("ADMIN_PASS", "")
	t.Setenv("DEBUG_ALLOWLIST", "")

	req := httptest.NewRequest("GET", "/admin", nil)
	assert.False(t, isAdminAllowed(req))
}

func TestAdminGuard_EmptyCredentials(t *testing.T) {
	t.Setenv("ADMIN_USER", "")
	t.Setenv("ADMIN_PASS", "")
	t.Setenv("DEBUG_ALLOWLIST", "")

	req := httptest.NewRequest("GET", "/admin", nil)
	assert.False(t, isAdminAllowed(req))
}

func TestAdminGuard_WrongCredentials(t *testing.T) {
	t.Setenv("ADMIN_USER", "admin")
	t.Setenv("ADMIN_PASS", "secret")
	t.Setenv("DEBUG_ALLOWLIST", "")

	req := httptest.NewRequest("GET", "/admin", nil)
	req.SetBasicAuth("admin", "wrong")
	assert.False(t, isAdminAllowed(req))
}

func TestAdminGuard_CorrectCredentials(t *testing.T) {
	t.Setenv("ADMIN_USER", "admin")
	t.Setenv("ADMIN_PASS", "secret")
	t.Setenv("DEBUG_ALLOWLIST", "")

	req := httptest.NewRequest("GET", "/admin", nil)
	req.SetBasicAuth("admin", "secret")
	assert.True(t, isAdminAllowed(req))
}

func TestAdminGuard_Allowlist_OnlyRemoteAddr(t *testing.T) {
	t.Setenv("DEBUG_ALLOWLIST", "192.168.1.1,10.0.0.1")
	t.Setenv("ADMIN_USER", "")
	t.Setenv("ADMIN_PASS", "")

	req := httptest.NewRequest("GET", "/admin", nil)
	req.RemoteAddr = "10.0.0.1:12345"
	assert.True(t, isAdminAllowed(req))

	req2 := httptest.NewRequest("GET", "/admin", nil)
	req2.RemoteAddr = "10.0.0.2:12345"
	req2.Header.Set("X-Forwarded-For", "10.0.0.1")
	assert.False(t, isAdminAllowed(req2))
}
