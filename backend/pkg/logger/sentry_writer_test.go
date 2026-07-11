package logger

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/getsentry/sentry-go"
)

// captureTransport is a mock sentry.Transport that records sent events so tests
// can assert what the bridge forwarded.
type captureTransport struct {
	mu     sync.Mutex
	events []*sentry.Event
}

func (t *captureTransport) Configure(sentry.ClientOptions) {}
func (t *captureTransport) SendEvent(e *sentry.Event) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.events = append(t.events, e)
}
func (t *captureTransport) Flush(time.Duration) bool              { return true }
func (t *captureTransport) FlushWithContext(context.Context) bool { return true }
func (t *captureTransport) Close()                                {}

func (t *captureTransport) all() []*sentry.Event {
	t.mu.Lock()
	defer t.mu.Unlock()
	return append([]*sentry.Event(nil), t.events...)
}

// withMockSentry initializes the SDK with a capture transport for the duration
// of a test and restores the previous hub afterward.
func withMockSentry(t *testing.T) *captureTransport {
	t.Helper()
	tr := &captureTransport{}
	if err := sentry.Init(sentry.ClientOptions{
		Dsn:       "https://test@example.com/1",
		Transport: tr,
	}); err != nil {
		t.Fatalf("sentry.Init: %v", err)
	}
	t.Cleanup(func() { sentry.CurrentHub().BindClient(nil) })
	return tr
}

func TestSentryBridge_CapturesErrorWithContext(t *testing.T) {
	tr := withMockSentry(t)
	log := New("production", WithSentryBridge())

	log.Error().
		Err(errors.New("boom: db timeout")).
		Str("request_id", "req-123").
		Str("path", "/api/v1/lists").
		Str("user_id", "user-abc").
		Int("attempt", 2).
		Msg("failed to load lists")

	events := tr.all()
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}
	ev := events[0]

	if ev.Level != sentry.LevelError {
		t.Errorf("level = %q, want error", ev.Level)
	}
	if ev.Message != "failed to load lists" {
		t.Errorf("message = %q", ev.Message)
	}
	if len(ev.Exception) != 1 || ev.Exception[0].Value != "boom: db timeout" {
		t.Errorf("exception = %+v, want value 'boom: db timeout'", ev.Exception)
	}
	if ev.Tags["request_id"] != "req-123" || ev.Tags["path"] != "/api/v1/lists" {
		t.Errorf("tags = %+v, want request_id/path promoted", ev.Tags)
	}
	if ev.Transaction != "/api/v1/lists" {
		t.Errorf("transaction = %q, want the request path", ev.Transaction)
	}
	if ev.User.ID != "user-abc" {
		t.Errorf("user.ID = %q, want user-abc", ev.User.ID)
	}
	if ev.Contexts["log"] == nil || ev.Contexts["log"]["attempt"] == nil {
		t.Errorf("expected non-mapped field 'attempt' in log context, got %+v", ev.Contexts["log"])
	}
}

func TestSentryBridge_IgnoresInfoAndSkipped(t *testing.T) {
	tr := withMockSentry(t)
	log := New("production", WithSentryBridge())

	log.Info().Msg("just informational")               // below Error → ignored
	log.Error().Bool(SentrySkipField, true).Msg("dup") // explicitly skipped

	if got := len(tr.all()); got != 0 {
		t.Fatalf("expected 0 events, got %d", got)
	}
}
