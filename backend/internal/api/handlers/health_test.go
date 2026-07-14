package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHealthHandler(t *testing.T) {
	h := NewHealthHandler(testDB)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/health", nil)
	h.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "ok", resp["status"])
	assert.NotNil(t, resp["checks"])
}
