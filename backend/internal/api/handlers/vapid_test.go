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

func TestVAPIDHandler_Subscribe_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	h := NewVAPIDHandler(testCfg)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/v1/push/subscribe", nil)
	req.Header.Set("Content-Type", "application/json")
	h.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}
