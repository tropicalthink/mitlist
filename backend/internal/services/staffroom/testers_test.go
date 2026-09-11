package staffroom

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/mitlist-app/mitlist/internal/repositories"
)

func TestForwardTesterPostsToIntake(t *testing.T) {
	var got map[string]any
	var gotKey, gotPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("X-App-Key")
		gotPath = r.URL.Path
		_ = json.NewDecoder(r.Body).Decode(&got)
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"id":"t1","created":true}`))
	}))
	defer server.Close()

	client := NewWithHTTP(server.URL+"/api/v1/intake/", "key-123", server.Client())
	if !client.Enabled() {
		t.Fatal("client with url and key should be enabled")
	}
	signedUp := time.Date(2026, 9, 11, 12, 0, 0, 0, time.UTC)
	err := client.ForwardTester(context.Background(), repositories.TestingSignup{
		Email: "tester@example.com", Platform: "ios", ConsentVersion: "v1", CreatedAt: signedUp,
	})
	if err != nil {
		t.Fatalf("forward: %v", err)
	}
	if gotKey != "key-123" || gotPath != "/api/v1/intake/testers" {
		t.Fatalf("key=%q path=%q", gotKey, gotPath)
	}
	if got["email"] != "tester@example.com" || got["platform"] != "ios" || got["consentVersion"] != "v1" ||
		got["signedUpAt"] != float64(signedUp.UnixMilli()) {
		t.Fatalf("payload: %#v", got)
	}
}

func TestForwardTesterReportsRejection(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
	}))
	defer server.Close()
	client := NewWithHTTP(server.URL, "bad", server.Client())
	if err := client.ForwardTester(context.Background(), repositories.TestingSignup{Email: "a@b.co", Platform: "android"}); err == nil {
		t.Fatal("expected an error for a 401")
	}
}

func TestDisabledWithoutConfig(t *testing.T) {
	for _, c := range []*Client{nil, New(nil), NewWithHTTP("", "key", nil), NewWithHTTP("https://x", "", nil)} {
		if c.Enabled() {
			t.Fatal("client should be disabled")
		}
		if err := c.ForwardTester(context.Background(), repositories.TestingSignup{}); err != ErrDisabled {
			t.Fatalf("expected ErrDisabled, got %v", err)
		}
	}
}
