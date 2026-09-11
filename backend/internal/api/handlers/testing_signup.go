package handlers

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"io"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

const testingConsentVersion = "testing-invitations-v1"

type testingSignupStore interface {
	Create(context.Context, string, string, string) error
	List(context.Context, string) ([]repositories.TestingSignup, error)
}

// testerForwarder mirrors a signup onto the team's tester list elsewhere
// (Staffroom). Forwarding is best-effort: Postgres is the record, and the
// sync endpoint exists to repair whatever a forward missed.
type testerForwarder interface {
	Enabled() bool
	ForwardTester(context.Context, repositories.TestingSignup) error
}

type TestingSignupHandler struct {
	store     testingSignupStore
	forwarder testerForwarder
	// forwardTimeout bounds the detached forward after a signup; the request
	// itself never waits on it.
	forwardTimeout time.Duration
}

func NewTestingSignupHandler(store testingSignupStore) *TestingSignupHandler {
	return &TestingSignupHandler{store: store, forwardTimeout: 10 * time.Second}
}

// SetForwarder enables mirroring new signups to the team's tester list.
func (h *TestingSignupHandler) SetForwarder(f testerForwarder) {
	h.forwarder = f
}

func (h *TestingSignupHandler) RegisterRoutes(r chi.Router) {
	r.Post("/testing/signups", h.Create)
	r.With(AdminGuard).Get("/testing/signups/export", h.Export)
	r.With(AdminGuard).Post("/testing/signups/sync", h.Sync)
}

func (h *TestingSignupHandler) Create(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if !middleware.CheckLimit("testing-signup:"+middleware.ExtractIP(r), 5, 5.0/600) {
		w.Header().Set("Retry-After", "120")
		http.Error(w, "Please wait before trying again.", http.StatusTooManyRequests)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	var input struct {
		Email    string `json:"email"`
		Platform string `json:"platform"`
		Consent  bool   `json:"consent"`
		Website  string `json:"website"`
	}
	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&input); err != nil {
		http.Error(w, "Please check your signup details.", http.StatusBadRequest)
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		http.Error(w, "Please check your signup details.", http.StatusBadRequest)
		return
	}
	if input.Website != "" {
		w.WriteHeader(http.StatusAccepted)
		return
	}
	email := strings.ToLower(strings.TrimSpace(input.Email))
	address, err := mail.ParseAddress(email)
	if err != nil || address.Address != email || len(email) > 254 || strings.ContainsAny(email, "\r\n") ||
		!input.Consent || (input.Platform != "android" && input.Platform != "ios") {
		http.Error(w, "Enter a valid email, choose your phone, and agree to testing emails.", http.StatusBadRequest)
		return
	}
	if err := h.store.Create(r.Context(), email, input.Platform, testingConsentVersion); err != nil {
		http.Error(w, "We couldn’t save your signup. Please try again later.", http.StatusServiceUnavailable)
		return
	}
	h.forwardAsync(repositories.TestingSignup{Email: email, Platform: input.Platform, ConsentVersion: testingConsentVersion, CreatedAt: time.Now()})
	w.WriteHeader(http.StatusAccepted)
}

// forwardAsync mirrors a signup without holding the response: the person on
// the landing page should not wait on, or hear about, a second service. A
// failure is logged; the next Sync picks it up.
func (h *TestingSignupHandler) forwardAsync(signup repositories.TestingSignup) {
	if h.forwarder == nil || !h.forwarder.Enabled() {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), h.forwardTimeout)
		defer cancel()
		if err := h.forwarder.ForwardTester(ctx, signup); err != nil {
			log.Warn().Err(err).Str("platform", signup.Platform).Msg("testing signup: forward to staffroom failed")
		}
	}()
}

// Sync re-sends every stored signup to the tester list. The intake side is
// idempotent, so this is safe to run any time: after enabling forwarding
// (backfill), or after an outage. Operator-only, like Export.
func (h *TestingSignupHandler) Sync(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	if h.forwarder == nil || !h.forwarder.Enabled() {
		http.Error(w, `{"error":"staffroom intake is not configured"}`, http.StatusServiceUnavailable)
		return
	}
	signups, err := h.store.List(r.Context(), "")
	if err != nil {
		http.Error(w, `{"error":"could not read signups"}`, http.StatusServiceUnavailable)
		return
	}
	forwarded, failed := 0, 0
	for _, signup := range signups {
		if err := h.forwarder.ForwardTester(r.Context(), signup); err != nil {
			failed++
			log.Warn().Err(err).Str("platform", signup.Platform).Msg("testing signup: sync to staffroom failed")
			continue
		}
		forwarded++
	}
	_ = json.NewEncoder(w).Encode(map[string]int{"forwarded": forwarded, "failed": failed})
}

// Export is deliberately separate from the public board and guarded by the
// existing operator authentication. Invitations are sent by the team after
// adding testers in Play Console / App Store Connect.
func (h *TestingSignupHandler) Export(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	platform := r.URL.Query().Get("platform")
	if platform != "" && platform != "android" && platform != "ios" {
		http.Error(w, "Choose android or ios.", http.StatusBadRequest)
		return
	}
	signups, err := h.store.List(r.Context(), platform)
	if err != nil {
		http.Error(w, "Could not export signups.", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="mitlist-testers.csv"`)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	writer := csv.NewWriter(w)
	_ = writer.Write([]string{"email", "platform", "signed_up_at", "consent_version"})
	for _, signup := range signups {
		email := signup.Email
		// Email local parts can start with spreadsheet formula characters.
		if len(email) > 0 && strings.ContainsAny(email[:1], "=+-@") {
			email = "'" + email
		}
		if err := writer.Write([]string{email, signup.Platform, signup.CreatedAt.UTC().Format(time.RFC3339), signup.ConsentVersion}); err != nil {
			return
		}
	}
	writer.Flush()
}
