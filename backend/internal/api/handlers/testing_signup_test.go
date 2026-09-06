package handlers

import (
	"context"
	"encoding/csv"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

type memoryTestingSignups struct {
	signups []repositories.TestingSignup
	err     error
}

func (s *memoryTestingSignups) Create(_ context.Context, email, platform, consent string) error {
	if s.err != nil {
		return s.err
	}
	for _, signup := range s.signups {
		if signup.Email == email && signup.Platform == platform {
			return nil
		}
	}
	s.signups = append(s.signups, repositories.TestingSignup{Email: email, Platform: platform, ConsentVersion: consent, CreatedAt: time.Now()})
	return nil
}

func (s *memoryTestingSignups) List(_ context.Context, platform string) ([]repositories.TestingSignup, error) {
	var result []repositories.TestingSignup
	for _, signup := range s.signups {
		if platform == "" || signup.Platform == platform {
			result = append(result, signup)
		}
	}
	return result, s.err
}

func TestTestingSignupValidation(t *testing.T) {
	for _, tc := range []struct {
		name, body  string
		code, count int
	}{
		{"valid", `{"email":" Tester@Example.com ","platform":"android","consent":true}`, 202, 1},
		{"ios", `{"email":"tester@example.com","platform":"ios","consent":true}`, 202, 1},
		{"no consent", `{"email":"tester@example.com","platform":"ios"}`, 400, 0},
		{"invalid email", `{"email":"bad","platform":"ios","consent":true}`, 400, 0},
		{"display name", `{"email":"Tester <tester@example.com>","platform":"ios","consent":true}`, 400, 0},
		{"platform", `{"email":"tester@example.com","platform":"web","consent":true}`, 400, 0},
		{"honeypot", `{"website":"spam","email":"tester@example.com","platform":"ios","consent":true}`, 202, 0},
		{"malformed", `{`, 400, 0},
		{"trailing json", `{"email":"tester@example.com","platform":"ios","consent":true}{}`, 400, 0},
		{"large body", `{"email":"` + strings.Repeat("a", 5000) + `@example.com","platform":"ios","consent":true}`, 400, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			middleware.ResetLimit("testing-signup:192.0.2.1")
			store := &memoryTestingSignups{}
			handler := NewTestingSignupHandler(store)
			rec := httptest.NewRecorder()
			handler.Create(rec, httptest.NewRequest("POST", "/testing/signups", strings.NewReader(tc.body)))
			if rec.Code != tc.code || len(store.signups) != tc.count {
				t.Fatalf("status=%d signups=%d", rec.Code, len(store.signups))
			}
			if tc.count > 0 && (store.signups[0].Email != "tester@example.com" || store.signups[0].ConsentVersion != testingConsentVersion) {
				t.Fatal("email or consent not normalized")
			}
		})
	}
}

func TestTestingSignupFailureAndRateLimit(t *testing.T) {
	middleware.ResetLimit("testing-signup:192.0.2.1")
	store := &memoryTestingSignups{err: errors.New("database unavailable")}
	handler := NewTestingSignupHandler(store)
	body := `{"email":"tester@example.com","platform":"ios","consent":true}`
	for i := 0; i < 6; i++ {
		rec := httptest.NewRecorder()
		handler.Create(rec, httptest.NewRequest("POST", "/testing/signups", strings.NewReader(body)))
		want := 503
		if i == 5 {
			want = 429
		}
		if rec.Code != want {
			t.Fatalf("attempt %d: status %d", i, rec.Code)
		}
		if strings.Contains(rec.Body.String(), "database") {
			t.Fatal("leaked internal error")
		}
	}
}

func TestTestingSignupExportIsPrivate(t *testing.T) {
	t.Setenv("DEBUG_ALLOWLIST", "")
	t.Setenv("ADMIN_USER", "operator")
	t.Setenv("ADMIN_PASS", "testing-export-password")
	store := &memoryTestingSignups{signups: []repositories.TestingSignup{
		{Email: "tester@example.com", Platform: "ios"},
		{Email: "+formula@example.com", Platform: "android"},
	}}
	router := chi.NewRouter()
	NewTestingSignupHandler(store).RegisterRoutes(router)
	request := httptest.NewRequest("GET", "/testing/signups/export?platform=android", nil)
	unauth := httptest.NewRecorder()
	router.ServeHTTP(unauth, request)
	if unauth.Code != http.StatusUnauthorized || strings.Contains(unauth.Body.String(), "example.com") {
		t.Fatal("export accessible without admin authentication")
	}
	request.SetBasicAuth("operator", "testing-export-password")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, request)
	rows, err := csv.NewReader(rec.Body).ReadAll()
	if err != nil || rec.Code != 200 || len(rows) != 2 || rows[1][0] != "'+formula@example.com" {
		t.Fatalf("invalid export: %#v, %v", rows, err)
	}
	if rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("private export can be cached")
	}
}
