package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/onboarding"
)

type fakeTipsStore struct {
	calls []uuid.UUID
}

func (f *fakeTipsStore) SetTipsEmailsEnabled(_ context.Context, id uuid.UUID, enabled bool) error {
	if enabled {
		panic("unsubscribe must only ever turn tips off")
	}
	f.calls = append(f.calls, id)
	return nil
}

func newUnsubscribeRouter(store *fakeTipsStore) (chi.Router, *config.Config) {
	cfg := &config.Config{SecretKey: "unit-test-secret-key-that-is-long-enough", FrontendURL: "https://app.example.test"}
	r := chi.NewRouter()
	NewEmailUnsubscribeHandler(cfg, store).RegisterRoutes(r)
	return r, cfg
}

func TestEmailUnsubscribe_ValidTokenTurnsTipsOff(t *testing.T) {
	store := &fakeTipsStore{}
	r, cfg := newUnsubscribeRouter(store)
	id := uuid.New()
	token := onboarding.UnsubscribeToken([]byte(cfg.SecretKey), id)

	for _, method := range []string{http.MethodGet, http.MethodPost} {
		req := httptest.NewRequest(method, "/email/unsubscribe?token="+token, strings.NewReader("List-Unsubscribe=One-Click"))
		req.RemoteAddr = "203.0.113.7:1234"
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("%s: status = %d, body=%s", method, rec.Code, rec.Body.String())
		}
		if method == http.MethodGet && !strings.Contains(rec.Body.String(), "unsubscribed") {
			t.Errorf("GET page lacks confirmation: %s", rec.Body.String())
		}
	}
	if len(store.calls) != 2 || store.calls[0] != id || store.calls[1] != id {
		t.Errorf("store calls = %v, want [%s %s]", store.calls, id, id)
	}
}

func TestEmailUnsubscribe_BadTokenIsRejectedWithoutTouchingStore(t *testing.T) {
	store := &fakeTipsStore{}
	r, _ := newUnsubscribeRouter(store)
	for _, token := range []string{"", "garbage", onboarding.UnsubscribeToken([]byte("other-secret"), uuid.New())} {
		req := httptest.NewRequest(http.MethodGet, "/email/unsubscribe?token="+token, nil)
		req.RemoteAddr = "203.0.113.8:1234"
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		if rec.Code != http.StatusBadRequest {
			t.Errorf("token %q: status = %d, want 400", token, rec.Code)
		}
	}
	if len(store.calls) != 0 {
		t.Errorf("store touched for bad tokens: %v", store.calls)
	}
}

func TestEmailUnsubscribe_HeroIsPublicAndCacheable(t *testing.T) {
	r, _ := newUnsubscribeRouter(&fakeTipsStore{})
	req := httptest.NewRequest(http.MethodGet, "/email/assets/day1-household.jpg", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}
	if got := w.Header().Get("Content-Type"); got != "image/jpeg" {
		t.Errorf("Content-Type = %q", got)
	}
	if got := w.Header().Get("Cache-Control"); got != "public, max-age=31536000, immutable" {
		t.Errorf("Cache-Control = %q", got)
	}
	if body := w.Body.Bytes(); len(body) < 3 || body[0] != 0xff || body[1] != 0xd8 || body[2] != 0xff {
		t.Error("response is not an embedded JPEG")
	}
}

func TestEmailUnsubscribe_HeroRejectsUnknownAssets(t *testing.T) {
	r, _ := newUnsubscribeRouter(&fakeTipsStore{})
	req := httptest.NewRequest(http.MethodGet, "/email/assets/not-a-campaign-file.jpg", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}
