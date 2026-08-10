package push

import (
	"context"
	"io"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

// stubAuthRepo satisfies repositories.AuthRepo minimally for push tests.
// Only DeletePushSubscription is exercised; all others panic.
type stubAuthRepo struct {
	mu      sync.Mutex
	deleted []uuid.UUID
}

func (r *stubAuthRepo) DeletePushSubscription(_ context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.deleted = append(r.deleted, id)
	return nil
}

func (r *stubAuthRepo) CreateOAuthAccount(_ context.Context, _ *models.OAuthAccount) error {
	panic("not impl")
}
func (r *stubAuthRepo) GetOAuthByProviderID(_ context.Context, _, _ string) (*models.OAuthAccount, error) {
	panic("not impl")
}
func (r *stubAuthRepo) CreatePasswordResetToken(_ context.Context, _ *models.PasswordResetToken) error {
	panic("not impl")
}
func (r *stubAuthRepo) GetPasswordResetToken(_ context.Context, _ string) (*models.PasswordResetToken, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ConsumeToken(_ context.Context, _ uuid.UUID) error { panic("not impl") }
func (r *stubAuthRepo) ConsumePasswordReset(_ context.Context, _, _ string) (uuid.UUID, error) {
	panic("not impl")
}
func (r *stubAuthRepo) UpdatePasswordAndRevokeSessions(_ context.Context, _ uuid.UUID, _ string) error {
	panic("not impl")
}
func (r *stubAuthRepo) CreateUnverifiedUser(_ context.Context, _ *models.User, _ string, _ time.Time) error {
	panic("not impl")
}
func (r *stubAuthRepo) CreateEmailVerification(_ context.Context, _ uuid.UUID, _ string, _ time.Time) error {
	panic("not impl")
}
func (r *stubAuthRepo) ConsumeEmailVerification(_ context.Context, _ string) (uuid.UUID, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ReserveLoginAttempt(_ context.Context, _ string, _ int, _ time.Duration) (bool, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ClearLoginAttempts(_ context.Context, _ string) error {
	panic("not impl")
}
func (r *stubAuthRepo) CreatePushSubscription(_ context.Context, _ *models.PushSubscription) error {
	panic("not impl")
}
func (r *stubAuthRepo) ListPushSubscriptionsByUser(_ context.Context, _ uuid.UUID) ([]models.PushSubscription, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ListPushSubscriptionsByUserIDs(_ context.Context, _ []uuid.UUID) (map[uuid.UUID][]models.PushSubscription, error) {
	panic("not impl")
}
func (r *stubAuthRepo) SaveDeviceToken(_ context.Context, _ uuid.UUID, _, _ string) (*models.DeviceToken, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ListDeviceTokensByUser(_ context.Context, _ uuid.UUID) ([]models.DeviceToken, error) {
	panic("not impl")
}
func (r *stubAuthRepo) ListDeviceTokensByUserIDs(_ context.Context, _ []uuid.UUID) (map[uuid.UUID][]models.DeviceToken, error) {
	panic("not impl")
}
func (r *stubAuthRepo) DeleteDeviceToken(_ context.Context, _, _ uuid.UUID) error {
	panic("not impl")
}
func (r *stubAuthRepo) CreateOAuthHandoff(_ context.Context, _ string, _ uuid.UUID, _ time.Time) error {
	panic("not impl")
}
func (r *stubAuthRepo) ConsumeOAuthHandoff(_ context.Context, _ string) (uuid.UUID, error) {
	panic("not impl")
}

// stubHTTPClient is a webpush.HTTPClient that returns a canned status code.
// It satisfies webpush.HTTPClient (Do(*http.Request) (*http.Response, error)).
type stubHTTPClient struct {
	status   int
	statuses []int
	delay    time.Duration // if > 0, sleep before returning
	calls    int
}

func (c *stubHTTPClient) Do(req *http.Request) (*http.Response, error) {
	c.calls++
	if c.delay > 0 {
		select {
		case <-req.Context().Done():
			return nil, req.Context().Err()
		case <-time.After(c.delay):
		}
	}
	status := c.status
	if len(c.statuses) >= c.calls {
		status = c.statuses[c.calls-1]
	}
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader("")),
	}, nil
}

func TestSendWebPush_BlockedEndpointSkipsSend(t *testing.T) {
	stub := &stubAuthRepo{}
	httpStub := &stubHTTPClient{status: http.StatusCreated}
	svc := newTestService(t, stub, httpStub)

	sub := validSub()
	sub.Endpoint = "https://100.64.0.1/wpush/v2/blocked"
	svc.sendWebPush(context.Background(), sub, `{"title":"hi"}`)

	if httpStub.calls != 0 {
		t.Fatalf("expected blocked endpoint to skip HTTP send, got %d calls", httpStub.calls)
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// newTestService builds a Service wired to the given authRepo and webpush client.
func newTestService(t *testing.T, authRepo *stubAuthRepo, wpClient webpush.HTTPClient) *Service {
	t.Helper()
	log := logger.New("production")
	cfg := &config.Config{
		VapidSubject:    "mailto:test@example.com",
		VapidPublicKey:  "BNNL5ZaTfK81qhXOx23-wewhigUeFb632jN6LvRWCFH1ubQr77FE_9qV1FuojuRmHP42zmf34rXgW80OvUVDgTk",
		VapidPrivateKey: "p0vB6tTzFslORDvL0Hd_qlr7cPSVoIp0aME0QiJpPo",
	}
	return &Service{
		cfg:           cfg,
		log:           log,
		authRepo:      authRepo,
		webpushClient: wpClient,
	}
}

// validSub returns a PushSubscription with well-formed EC keys (from webpush-go test suite).
func validSub() models.PushSubscription {
	return models.PushSubscription{
		ID:     uuid.New(),
		UserID: uuid.New(),
		// Endpoint is irrelevant after validation — our stubHTTPClient intercepts
		// before the real network.
		Endpoint: "https://93.184.216.34/wpush/v2/gAAAAA",
		P256dh:   "BNNL5ZaTfK81qhXOx23-wewhigUeFb632jN6LvRWCFH1ubQr77FE_9qV1FuojuRmHP42zmf34rXgW80OvUVDgTk",
		Auth:     "zqbxT6JKstKSY9JKibZLSQ",
	}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

// TestSendWebPush_201_NoDelete verifies that a 201 response does NOT cause deletion.
func TestSendWebPush_201_NoDelete(t *testing.T) {
	stub := &stubAuthRepo{}
	svc := newTestService(t, stub, &stubHTTPClient{status: http.StatusCreated})

	sub := validSub()
	svc.sendWebPush(context.Background(), sub, `{"title":"hi"}`)

	stub.mu.Lock()
	defer stub.mu.Unlock()
	if len(stub.deleted) != 0 {
		t.Errorf("expected no deletions on 201, got %v", stub.deleted)
	}
}

// TestSendWebPush_410_Prunes verifies that a 410 Gone response triggers deletion.
func TestSendWebPush_410_Prunes(t *testing.T) {
	stub := &stubAuthRepo{}
	svc := newTestService(t, stub, &stubHTTPClient{status: http.StatusGone})

	sub := validSub()
	svc.sendWebPush(context.Background(), sub, `{"title":"hi"}`)

	stub.mu.Lock()
	defer stub.mu.Unlock()
	if len(stub.deleted) != 1 || stub.deleted[0] != sub.ID {
		t.Errorf("expected deletion of sub %v on 410, got %v", sub.ID, stub.deleted)
	}
}

// TestSendWebPush_404_Prunes verifies that a 404 Not Found response triggers deletion.
func TestSendWebPush_404_Prunes(t *testing.T) {
	stub := &stubAuthRepo{}
	svc := newTestService(t, stub, &stubHTTPClient{status: http.StatusNotFound})

	sub := validSub()
	svc.sendWebPush(context.Background(), sub, `{"title":"hi"}`)

	stub.mu.Lock()
	defer stub.mu.Unlock()
	if len(stub.deleted) != 1 || stub.deleted[0] != sub.ID {
		t.Errorf("expected deletion of sub %v on 404, got %v", sub.ID, stub.deleted)
	}
}

// TestSendWebPush_500_NoPrune verifies that a 5xx response does NOT prune the sub.
func TestSendWebPush_500_NoPrune(t *testing.T) {
	stub := &stubAuthRepo{}
	svc := newTestService(t, stub, &stubHTTPClient{status: http.StatusInternalServerError})

	sub := validSub()
	svc.sendWebPush(context.Background(), sub, `{"title":"hi"}`)

	stub.mu.Lock()
	defer stub.mu.Unlock()
	if len(stub.deleted) != 0 {
		t.Errorf("expected no deletions on 500, got %v", stub.deleted)
	}
}

func TestSendWebPush_TransientFailureRetriesOnce(t *testing.T) {
	stub := &stubAuthRepo{}
	httpStub := &stubHTTPClient{statuses: []int{http.StatusTooManyRequests, http.StatusCreated}}
	svc := newTestService(t, stub, httpStub)

	svc.sendWebPush(context.Background(), validSub(), `{"title":"hi"}`)

	if httpStub.calls != 2 {
		t.Fatalf("expected one retry after transient response, got %d calls", httpStub.calls)
	}
}

func TestNotificationCollapseKey(t *testing.T) {
	t.Run("groups updates for the same entity", func(t *testing.T) {
		got := notificationCollapseKey(map[string]string{
			"entity_type": "chore",
			"id":          "11111111-1111-1111-1111-111111111111",
		})
		if got != "chore:11111111-1111-1111-1111-111111111111" {
			t.Fatalf("unexpected collapse key %q", got)
		}
	})

	t.Run("does not collapse unrelated generic notifications", func(t *testing.T) {
		if got := notificationCollapseKey(map[string]string{"notification_id": uuid.NewString()}); got != "" {
			t.Fatalf("expected no collapse key, got %q", got)
		}
	})
}

// TestSendWebPush_Timeout verifies that a hanging endpoint unblocks within the client timeout.
//
// Strategy: inject a stubHTTPClient that hangs for a long duration, and set the
// Service's webpushClient to a real *http.Client with a very short Timeout. The
// webpush library calls client.Do(req) where req carries a deadline derived from
// the http.Client.Timeout. Our stub blocks on the request context Done channel,
// so the call returns once the deadline fires.
//
// We can't use a *http.Client with a stub transport directly via webpush because
// webpush accepts webpush.HTTPClient (the Do interface). Instead we confirm timeout
// behaviour by using the stub's context-aware delay path:
//   - stub.delay is long (10 s)
//   - we set a ctx with a 200 ms deadline on the sendWebPush call, so the stub's
//     req.Context().Done() fires first — proving the timeout propagates correctly.
func TestSendWebPush_Timeout(t *testing.T) {
	stub := &stubAuthRepo{}
	shortTimeout := 200 * time.Millisecond

	// stubHTTPClient with a long delay: it blocks on the request context.
	hangingClient := &stubHTTPClient{delay: 10 * time.Second}
	svc := newTestService(t, stub, hangingClient)

	sub := validSub()

	// Drive the call with a context that expires in shortTimeout.
	ctx, cancel := context.WithTimeout(context.Background(), shortTimeout)
	defer cancel()

	start := time.Now()
	svc.sendWebPush(ctx, sub, `{"title":"hi"}`)
	elapsed := time.Since(start)

	// Should return shortly after shortTimeout — allow 5× slack for slow CI.
	maxAllowed := shortTimeout * 5
	if elapsed > maxAllowed {
		t.Errorf("sendWebPush took %v, expected to return within %v (context timeout=%v)", elapsed, maxAllowed, shortTimeout)
	}

	// No deletion on timeout (err path, not a 404/410 response).
	stub.mu.Lock()
	defer stub.mu.Unlock()
	if len(stub.deleted) != 0 {
		t.Errorf("expected no deletion on timeout, got %v", stub.deleted)
	}
}
