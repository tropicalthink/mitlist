package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestReadOnlySmoke(t *testing.T) {
	t.Parallel()
	var writes int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writes++
		}
		switch r.URL.Path {
		case "/healthz", "/readyz":
			w.WriteHeader(http.StatusOK)
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	if err := run(context.Background(), config{
		baseURL: server.URL, mode: "read-only", timeout: time.Second, out: io.Discard,
	}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if writes != 0 {
		t.Fatalf("read-only smoke made %d write requests", writes)
	}
}

func TestFullSmokeRequiresExplicitWriteOptIn(t *testing.T) {
	t.Parallel()
	err := run(context.Background(), config{
		baseURL: "https://example.com", mode: "full", timeout: time.Second, out: io.Discard,
	})
	if err == nil || !strings.Contains(err.Error(), "allow-writes") {
		t.Fatalf("expected allow-writes error, got %v", err)
	}
}

func TestFullSmokeJourneyAndCleanup(t *testing.T) {
	t.Parallel()
	state := &fakeSmokeState{}
	var serverURL string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		state.handle(serverURL, w, r)
	}))
	serverURL = server.URL
	defer server.Close()

	if err := run(context.Background(), config{
		baseURL: server.URL, mode: "full", allowWrites: true,
		emailDomain: "example.invalid", timeout: 5 * time.Second, out: io.Discard,
	}); err != nil {
		t.Fatalf("run: %v", err)
	}

	state.mu.Lock()
	defer state.mu.Unlock()
	if !state.uploaded {
		t.Fatal("expected object upload")
	}
	if !state.loggedOut {
		t.Fatal("expected logout")
	}
	if !state.accountDeleted {
		t.Fatal("expected disposable account deletion")
	}
	if state.used != 0 || state.reserved != 0 {
		t.Fatalf("storage leaked: used=%d reserved=%d", state.used, state.reserved)
	}
}

func TestFullSmokeCleansAccountAfterFailure(t *testing.T) {
	t.Parallel()
	state := &fakeSmokeState{failGroup: true}
	var serverURL string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		state.handle(serverURL, w, r)
	}))
	serverURL = server.URL
	defer server.Close()

	err := run(context.Background(), config{
		baseURL: server.URL, mode: "full", allowWrites: true,
		emailDomain: "example.invalid", timeout: 5 * time.Second, out: io.Discard,
	})
	if err == nil || !strings.Contains(err.Error(), "create household") {
		t.Fatalf("expected household failure, got %v", err)
	}
	state.mu.Lock()
	defer state.mu.Unlock()
	if !state.accountDeleted {
		t.Fatal("expected failed smoke account to be cleaned up")
	}
}

func TestNormalizeBaseURL(t *testing.T) {
	t.Parallel()
	got, err := normalizeBaseURL("https://api.example.com/")
	if err != nil || got != "https://api.example.com" {
		t.Fatalf("normalizeBaseURL = %q, %v", got, err)
	}
	for _, raw := range []string{"", "api.example.com", "ftp://api.example.com", "https://api.example.com?q=1", "https://api.example.com/api"} {
		if _, err := normalizeBaseURL(raw); err == nil {
			t.Fatalf("normalizeBaseURL(%q) unexpectedly succeeded", raw)
		}
	}
}

type fakeSmokeState struct {
	mu             sync.Mutex
	reserved       int64
	used           int64
	uploaded       bool
	loggedOut      bool
	accountDeleted bool
	failGroup      bool
}

func (s *fakeSmokeState) handle(serverURL string, w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	defer s.mu.Unlock()

	switch {
	case r.Method == http.MethodGet && (r.URL.Path == "/healthz" || r.URL.Path == "/readyz"):
		w.WriteHeader(http.StatusOK)
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/auth/register":
		writeJSON(w, http.StatusCreated, tokenPair{AccessToken: "access-registered", RefreshToken: "refresh-registered"})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/auth/token/refresh":
		writeJSON(w, http.StatusOK, tokenPair{AccessToken: "access-refreshed", RefreshToken: "refresh-refreshed"})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/auth/login":
		writeJSON(w, http.StatusOK, tokenPair{AccessToken: "access-cleanup", RefreshToken: "refresh-cleanup"})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/groups":
		if s.failGroup {
			http.Error(w, "database unavailable", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusCreated, entity{ID: "group-1"})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/lists":
		writeJSON(w, http.StatusCreated, entity{ID: "list-1"})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/lists/list-1/items":
		writeJSON(w, http.StatusCreated, entity{ID: "item-1"})
	case r.Method == http.MethodGet && r.URL.Path == "/api/v1/lists/list-1/items":
		writeJSON(w, http.StatusOK, []entity{{ID: "item-1"}})
	case r.Method == http.MethodGet && r.URL.Path == "/api/v1/attachments/storage-usage":
		writeJSON(w, http.StatusOK, storageUsage{UsedBytes: s.used, ReservedBytes: s.reserved, LimitBytes: 1_000_000_000})
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/attachments/upload-intent":
		s.reserved = int64(len("mitlist production smoke\n"))
		writeJSON(w, http.StatusCreated, uploadIntent{Attachment: entity{ID: "attachment-1"}, UploadURL: serverURL + "/object"})
	case r.Method == http.MethodPut && r.URL.Path == "/object":
		payload, _ := io.ReadAll(r.Body)
		s.uploaded = string(payload) == "mitlist production smoke\n"
		w.WriteHeader(http.StatusOK)
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/attachments/attachment-1/finalize":
		s.used, s.reserved = int64(len("mitlist production smoke\n")), 0
		writeJSON(w, http.StatusOK, entity{ID: "attachment-1"})
	case r.Method == http.MethodDelete && r.URL.Path == "/api/v1/attachments/attachment-1":
		s.used, s.reserved = 0, 0
		w.WriteHeader(http.StatusNoContent)
	case r.Method == http.MethodDelete && r.URL.Path == "/api/v1/lists/list-1":
		w.WriteHeader(http.StatusNoContent)
	case r.Method == http.MethodDelete && r.URL.Path == "/api/v1/groups/group-1":
		w.WriteHeader(http.StatusNoContent)
	case r.Method == http.MethodPost && r.URL.Path == "/api/v1/auth/logout":
		s.loggedOut = true
		w.WriteHeader(http.StatusNoContent)
	case r.Method == http.MethodGet && r.URL.Path == "/api/v1/auth/me" && s.loggedOut:
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	case r.Method == http.MethodDelete && r.URL.Path == "/api/v1/auth/me":
		s.accountDeleted = true
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "unexpected smoke request", http.StatusNotFound)
	}
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
