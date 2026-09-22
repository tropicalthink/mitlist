package handlers

import (
	"context"
	"encoding/csv"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
	turnstileservice "github.com/mitlist-app/mitlist/internal/services/turnstile"
)

type memoryTestingSignups struct {
	signups []repositories.TestingSignup
	err     error
}

func (s *memoryTestingSignups) Create(_ context.Context, email, platform, consent string, launchUpdates bool, launchConsent string) error {
	if s.err != nil {
		return s.err
	}
	for _, signup := range s.signups {
		if signup.Email == email && signup.Platform == platform {
			return nil
		}
	}
	var version *string
	var consentedAt *time.Time
	if launchUpdates {
		version = &launchConsent
		now := time.Now()
		consentedAt = &now
	}
	s.signups = append(s.signups, repositories.TestingSignup{Email: email, Platform: platform, ConsentVersion: consent, LaunchUpdates: launchUpdates, LaunchConsentVersion: version, LaunchConsentedAt: consentedAt, CreatedAt: time.Now()})
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

func (s *memoryTestingSignups) MarkInvited(_ context.Context, email, platform string) error {
	if s.err != nil {
		return s.err
	}
	for i := range s.signups {
		if s.signups[i].Email == email && s.signups[i].Platform == platform && s.signups[i].InvitedAt == nil {
			now := time.Now()
			s.signups[i].InvitedAt = &now
		}
	}
	return nil
}

type memoryForwarder struct {
	mu       sync.Mutex
	enabled  bool
	err      error
	received []repositories.TestingSignup
}

func (f *memoryForwarder) Enabled() bool { return f.enabled }

func (f *memoryForwarder) ForwardTester(_ context.Context, s repositories.TestingSignup) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return f.err
	}
	f.received = append(f.received, s)
	return nil
}

func (f *memoryForwarder) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.received)
}

func TestTestingSignupValidation(t *testing.T) {
	for _, tc := range []struct {
		name, body  string
		code, count int
	}{
		{"valid", `{"email":" Tester@Example.com ","platform":"android","consent":true}`, 202, 1},
		{"valid with separate launch consent", `{"email":"tester@example.com","platform":"android","consent":true,"launch_updates":true}`, 202, 1},
		{"ios", `{"email":"tester@example.com","platform":"ios","consent":true}`, 202, 1},
		{"no consent", `{"email":"tester@example.com","platform":"ios"}`, 400, 0},
		{"invalid email", `{"email":"bad","platform":"ios","consent":true}`, 400, 0},
		{"display name", `{"email":"Tester <tester@example.com>","platform":"ios","consent":true}`, 400, 0},
		{"platform", `{"email":"tester@example.com","platform":"web","consent":true}`, 400, 0},
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
			if tc.name == "valid with separate launch consent" &&
				(!store.signups[0].LaunchUpdates || store.signups[0].LaunchConsentVersion == nil || store.signups[0].LaunchConsentedAt == nil) {
				t.Fatal("separate launch consent was not recorded")
			}
		})
	}
}

// testingSiteverifyStub stands in for Cloudflare, answering every request
// with the given body. Deliberately separate from the auth tests' stub so this
// file stays runnable without the database-backed TestMain.
func testingSiteverifyStub(t *testing.T, body string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestTestingSignupVerifiesTurnstile(t *testing.T) {
	for _, tc := range []struct {
		name     string
		enforce  bool
		token    string
		response string
		code     int
		count    int
	}{
		{"unconfigured accepts without a token", false, "", `{"success":true}`, 202, 1},
		{"valid token", true, "solved", `{"success":true,"hostname":"mitlist.me"}`, 202, 1},
		{"missing token", true, "", `{"success":true}`, 400, 0},
		{"failed challenge", true, "forged", `{"success":false,"error-codes":["invalid-input-response"]}`, 400, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			middleware.ResetLimit("testing-signup:192.0.2.1")
			stub := testingSiteverifyStub(t, tc.response)
			store := &memoryTestingSignups{}
			handler := NewTestingSignupHandler(store)
			if tc.enforce {
				handler.SetTurnstileVerifier(turnstileservice.NewForTesting("secret", stub.URL, stub.Client()))
			}
			request := httptest.NewRequest("POST", "/testing/signups", strings.NewReader(`{"email":"tester@example.com","platform":"android","consent":true}`))
			if tc.token != "" {
				request.Header.Set("X-Mitlist-Turnstile", tc.token)
			}
			rec := httptest.NewRecorder()
			handler.Create(rec, request)
			if rec.Code != tc.code || len(store.signups) != tc.count {
				t.Fatalf("status=%d signups=%d body=%s", rec.Code, len(store.signups), rec.Body.String())
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

func TestTestingSignupForwardsAfterCreate(t *testing.T) {
	middleware.ResetLimit("testing-signup:192.0.2.1")
	forwarder := &memoryForwarder{enabled: true}
	handler := NewTestingSignupHandler(&memoryTestingSignups{})
	handler.SetForwarder(forwarder)
	rec := httptest.NewRecorder()
	handler.Create(rec, httptest.NewRequest("POST", "/testing/signups", strings.NewReader(`{"email":"Tester@example.com","platform":"android","consent":true}`)))
	if rec.Code != http.StatusAccepted {
		t.Fatalf("status %d", rec.Code)
	}
	deadline := time.Now().Add(2 * time.Second)
	for forwarder.count() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if forwarder.count() != 1 || forwarder.received[0].Email != "tester@example.com" || forwarder.received[0].Platform != "android" ||
		forwarder.received[0].ConsentVersion != testingConsentVersion || forwarder.received[0].CreatedAt.IsZero() {
		t.Fatalf("forwarded: %#v", forwarder.received)
	}

	// A failed save forwards nothing: Postgres is the record.
	middleware.ResetLimit("testing-signup:192.0.2.1")
	failing := NewTestingSignupHandler(&memoryTestingSignups{err: errors.New("down")})
	failing.SetForwarder(forwarder)
	rec = httptest.NewRecorder()
	failing.Create(rec, httptest.NewRequest("POST", "/testing/signups", strings.NewReader(`{"email":"other@example.com","platform":"ios","consent":true}`)))
	time.Sleep(20 * time.Millisecond)
	if rec.Code != http.StatusServiceUnavailable || forwarder.count() != 1 {
		t.Fatalf("status %d forwarded %d", rec.Code, forwarder.count())
	}
}

func TestTestingSignupSync(t *testing.T) {
	t.Setenv("DEBUG_ALLOWLIST", "")
	t.Setenv("ADMIN_USER", "operator")
	t.Setenv("ADMIN_PASS", "testing-sync-password")
	store := &memoryTestingSignups{signups: []repositories.TestingSignup{
		{Email: "one@example.com", Platform: "ios", CreatedAt: time.Now()},
		{Email: "two@example.com", Platform: "android", CreatedAt: time.Now()},
	}}
	forwarder := &memoryForwarder{enabled: true}
	handler := NewTestingSignupHandler(store)
	handler.SetForwarder(forwarder)
	router := chi.NewRouter()
	handler.RegisterRoutes(router)

	unauth := httptest.NewRecorder()
	router.ServeHTTP(unauth, httptest.NewRequest("POST", "/testing/signups/sync", nil))
	if unauth.Code != http.StatusUnauthorized || forwarder.count() != 0 {
		t.Fatal("sync ran without admin authentication")
	}

	request := httptest.NewRequest("POST", "/testing/signups/sync", nil)
	request.SetBasicAuth("operator", "testing-sync-password")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, request)
	if rec.Code != http.StatusOK || forwarder.count() != 2 || !strings.Contains(rec.Body.String(), `"forwarded":2`) {
		t.Fatalf("status %d body %s forwarded %d", rec.Code, rec.Body.String(), forwarder.count())
	}

	// Without a configured forwarder the endpoint says so instead of pretending.
	bare := NewTestingSignupHandler(store)
	bare.SetForwarder(&memoryForwarder{})
	bareRouter := chi.NewRouter()
	bare.RegisterRoutes(bareRouter)
	request = httptest.NewRequest("POST", "/testing/signups/sync", nil)
	request.SetBasicAuth("operator", "testing-sync-password")
	rec = httptest.NewRecorder()
	bareRouter.ServeHTTP(rec, request)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status %d", rec.Code)
	}
}
