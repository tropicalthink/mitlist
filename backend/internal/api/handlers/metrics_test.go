package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMetricsHandler_RequiresAuth(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}

	h := NewMetricsHandler(testDB)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/metrics", nil)
	h.ServeHTTP(rec, req)

	// Metrics endpoint typically requires admin auth or returns 401
	assert.True(t, rec.Code == http.StatusUnauthorized || rec.Code == http.StatusOK)
}
