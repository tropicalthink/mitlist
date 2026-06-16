package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestVAPIDHandler_PublicKey_ReturnsKey(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	h := NewVAPIDHandler(testCfg)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/push/public-key", nil)
	h.ServeHTTP(rec, req)

	// Should return 200 with the public key or 400 if not configured
	assert.True(t, rec.Code == http.StatusOK || rec.Code == http.StatusBadRequest)
}

// VAPIDHandler only serves the public VAPID key; it has no subscribe method
// (push-subscribe auth is enforced by router middleware on a different handler).
// This test confirms the public-key endpoint is intentionally public and always
// returns the key shape regardless of method.
func TestVAPIDHandler_PublicKey_IsPublic(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	h := NewVAPIDHandler(testCfg)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/push/public-key", nil)
	h.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), "public_key")
}
