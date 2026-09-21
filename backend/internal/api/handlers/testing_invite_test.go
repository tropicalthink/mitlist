package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/repositories"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
)

type memoryInviteMailer struct {
	sent   []string
	failOn string
}

func (m *memoryInviteMailer) SendHTMLWithHeadersOnce(to, subject, html, text string, _ []mailservice.Header) error {
	if to == m.failOn {
		return errors.New("provider down")
	}
	if !strings.Contains(html, "play.google.com") || !strings.Contains(text, "play.google.com") || subject == "" {
		return errors.New("store link missing from message")
	}
	m.sent = append(m.sent, to)
	return nil
}

const playURL = "https://play.google.com/store/apps/details?id=me.mitlist"

func TestRenderTestingInvite(t *testing.T) {
	msg := renderTestingInvite("android", playURL)
	for _, want := range []string{playURL, "Get it on Google Play", "feedback.mitlist.me", "mitlist.me/mobile-beta", "<strong"} {
		if !strings.Contains(msg.HTML, want) {
			t.Fatalf("html lacks %q", want)
		}
	}
	if !strings.Contains(msg.Text, playURL) || strings.Contains(msg.Text, "<") {
		t.Fatalf("text part wrong: %q", msg.Text)
	}
	if !strings.Contains(msg.HTML, ">1<") || !strings.Contains(msg.HTML, ">3<") {
		t.Fatal("steps are not numbered from one")
	}
	if !strings.Contains(renderTestingInvite("ios", "https://testflight.apple.com/join/x").HTML, "TestFlight") {
		t.Fatal("ios invite does not mention TestFlight")
	}
}

func newInviteRouter(store *memoryTestingSignups, mailer *memoryInviteMailer) *chi.Mux {
	router := chi.NewRouter()
	handler := NewTestingSignupHandler(store)
	handler.SetInviter(mailer, map[string]string{"android": playURL, "ios": ""})
	handler.RegisterRoutes(router)
	return router
}

func inviteRequest(t *testing.T, router http.Handler, method, target, body string) (*httptest.ResponseRecorder, map[string]any) {
	t.Helper()
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	req.SetBasicAuth("operator", "testing-invite-password")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec, out
}

func TestTestingSignupInvite(t *testing.T) {
	t.Setenv("DEBUG_ALLOWLIST", "")
	t.Setenv("ADMIN_USER", "operator")
	t.Setenv("ADMIN_PASS", "testing-invite-password")
	earlier := time.Now().Add(-time.Hour)
	store := &memoryTestingSignups{signups: []repositories.TestingSignup{
		{Email: "one@example.com", Platform: "android"},
		{Email: "two@example.com", Platform: "android"},
		{Email: "done@example.com", Platform: "android", InvitedAt: &earlier},
		{Email: "apple@example.com", Platform: "ios"},
	}}
	mailer := &memoryInviteMailer{failOn: "two@example.com"}
	router := newInviteRouter(store, mailer)

	// Anonymous callers get nothing, and nobody is emailed.
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, httptest.NewRequest("POST", "/testing/signups/invite", nil))
	if rec.Code != http.StatusUnauthorized || len(mailer.sent) != 0 {
		t.Fatalf("anonymous invite: status %d sent %d", rec.Code, len(mailer.sent))
	}

	// Preview renders without sending.
	rec, _ = inviteRequest(t, router, "GET", "/testing/signups/invite/preview", "")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), playURL) || len(mailer.sent) != 0 {
		t.Fatalf("preview: status %d", rec.Code)
	}
	rec, _ = inviteRequest(t, router, "GET", "/testing/signups/invite/preview?platform=ios", "")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("ios preview without a listing: status %d", rec.Code)
	}

	// Dry run lists the pending people only.
	rec, out := inviteRequest(t, router, "POST", "/testing/signups/invite", `{"dry_run":true}`)
	if rec.Code != 200 || len(mailer.sent) != 0 || out["already_invited"].(float64) != 1 || len(out["sent"].([]any)) != 2 {
		t.Fatalf("dry run: status %d body %s", rec.Code, rec.Body.String())
	}

	// The real send skips the invited one, records the delivered one, reports the failure.
	rec, out = inviteRequest(t, router, "POST", "/testing/signups/invite?platform=android", "")
	if rec.Code != 200 || len(mailer.sent) != 1 || mailer.sent[0] != "one@example.com" {
		t.Fatalf("send: status %d sent %v body %s", rec.Code, mailer.sent, rec.Body.String())
	}
	if failed := out["failed"].([]any); len(failed) != 1 || failed[0] != "two@example.com" {
		t.Fatalf("failed list: %v", failed)
	}
	if store.signups[0].InvitedAt == nil || store.signups[1].InvitedAt != nil {
		t.Fatal("invited marks wrong after send")
	}

	// A second run only reaches the one that failed.
	mailer.failOn = ""
	_, out = inviteRequest(t, router, "POST", "/testing/signups/invite", "")
	if sent := out["sent"].([]any); len(sent) != 1 || sent[0] != "two@example.com" {
		t.Fatalf("second run sent %v", sent)
	}

	// Explicit addresses plus resend reach an already-invited person; other platforms never.
	_, out = inviteRequest(t, router, "POST", "/testing/signups/invite", `{"emails":["Done@example.com","apple@example.com"],"resend":true}`)
	if sent := out["sent"].([]any); len(sent) != 1 || sent[0] != "done@example.com" {
		t.Fatalf("targeted resend sent %v", sent)
	}
	if store.signups[2].InvitedAt == nil || !store.signups[2].InvitedAt.Equal(earlier) {
		t.Fatal("resend moved the original invited timestamp")
	}

	// No listing, no send.
	rec, _ = inviteRequest(t, router, "POST", "/testing/signups/invite?platform=ios", "")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("ios invite without a listing: status %d", rec.Code)
	}
}
