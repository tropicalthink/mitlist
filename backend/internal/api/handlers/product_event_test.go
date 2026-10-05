package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

type recordedEvents struct {
	userID    *uuid.UUID
	installID *uuid.UUID
	inputs    []services.ProductEventInput
}

type fakeEventRecorder struct {
	calls []recordedEvents
	err   error
}

func (f *fakeEventRecorder) Record(_ context.Context, userID, installID *uuid.UUID, inputs []services.ProductEventInput) (int, error) {
	f.calls = append(f.calls, recordedEvents{userID: userID, installID: installID, inputs: inputs})
	if f.err != nil {
		return 0, f.err
	}
	return len(inputs), nil
}

func postEvents(t *testing.T, h *ProductEventHandler, body string, user *models.User) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/events", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if user != nil {
		req = req.WithContext(api.WithUser(req.Context(), user))
	}
	rec := httptest.NewRecorder()
	h.Record(rec, req)
	return rec
}

func TestProductEventHandler_AcceptsAnInstallBatch(t *testing.T) {
	recorder := &fakeEventRecorder{}
	h := NewProductEventHandler(recorder)
	install := uuid.New()
	middleware.ResetLimit("ratelimit:events:install:" + install.String())

	rec := postEvents(t, h, `{"install_id":"`+install.String()+`","events":[{"name":"welcome_shown"},{"name":"tour_skipped","props":{"page":"1"}}]}`, nil)

	require.Equal(t, http.StatusAccepted, rec.Code)
	assert.JSONEq(t, `{"accepted":2}`, rec.Body.String())
	require.Len(t, recorder.calls, 1)
	assert.Nil(t, recorder.calls[0].userID)
	assert.Equal(t, install, *recorder.calls[0].installID)
	assert.Equal(t, "1", recorder.calls[0].inputs[1].Props["page"])
}

func TestProductEventHandler_AttributesSignedInEventsToTheSession(t *testing.T) {
	recorder := &fakeEventRecorder{}
	h := NewProductEventHandler(recorder)
	user := &models.User{ID: uuid.New()}
	middleware.ResetLimit("ratelimit:events:user:" + user.ID.String())

	rec := postEvents(t, h, `{"events":[{"name":"household_created"}]}`, user)

	require.Equal(t, http.StatusAccepted, rec.Code)
	require.Len(t, recorder.calls, 1)
	assert.Equal(t, user.ID, *recorder.calls[0].userID)
}

func TestProductEventHandler_RejectsMalformedBodies(t *testing.T) {
	h := NewProductEventHandler(&fakeEventRecorder{})
	rec := postEvents(t, h, `{"events":[{"name":"welcome_shown","ip":"1.2.3.4"}]}`, nil)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestProductEventHandler_PassesValidationErrorsThrough(t *testing.T) {
	h := NewProductEventHandler(&fakeEventRecorder{err: &api.ValidationError{Field: "install_id", Message: "is required without a session"}})
	middleware.ResetLimit("ratelimit:events:ip:192.0.2.1")
	rec := postEvents(t, h, `{"events":[{"name":"welcome_shown"}]}`, nil)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestProductEventHandler_RateLimitsASender(t *testing.T) {
	h := NewProductEventHandler(&fakeEventRecorder{})
	install := uuid.New()
	key := "ratelimit:events:install:" + install.String()
	middleware.ResetLimit(key)
	t.Cleanup(func() { middleware.ResetLimit(key) })

	body := `{"install_id":"` + install.String() + `","events":[{"name":"welcome_shown"}]}`
	var last int
	for i := 0; i < productEventBurst+1; i++ {
		last = postEvents(t, h, body, nil).Code
	}
	assert.Equal(t, http.StatusTooManyRequests, last)
}
