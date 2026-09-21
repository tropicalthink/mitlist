package handlers

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
)

const testingConsentVersion = "testing-invitations-v1"
const launchUpdatesConsentVersion = "launch-updates-v1"

type testingSignupStore interface {
	Create(context.Context, string, string, string, bool, string) error
	List(context.Context, string) ([]repositories.TestingSignup, error)
	MarkInvited(ctx context.Context, email, platform string) error
}

// inviteMailer sends the store invitation. The once variant is deliberate:
// an ambiguous provider timeout must not fan out into a duplicate invite.
type inviteMailer interface {
	SendHTMLWithHeadersOnce(to, subject, html, text string, headers []mailservice.Header) error
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
	mailer    inviteMailer
	// storeURLs maps a platform to its listing; a missing or empty entry
	// means invitations for that platform are not available yet.
	storeURLs map[string]string
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

// SetInviter enables the invitation email. storeURLs maps platform to the
// store listing the email links to.
func (h *TestingSignupHandler) SetInviter(m inviteMailer, storeURLs map[string]string) {
	h.mailer = m
	h.storeURLs = storeURLs
}

func (h *TestingSignupHandler) RegisterRoutes(r chi.Router) {
	r.Post("/testing/signups", h.Create)
	r.With(AdminGuard).Get("/testing/signups/export", h.Export)
	r.With(AdminGuard).Post("/testing/signups/sync", h.Sync)
	r.With(AdminGuard).Get("/testing/signups/invite/preview", h.InvitePreview)
	r.With(AdminGuard).Post("/testing/signups/invite", h.Invite)
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
		Email         string `json:"email"`
		Platform      string `json:"platform"`
		Consent       bool   `json:"consent"`
		Website       string `json:"website"`
		LaunchUpdates bool   `json:"launch_updates"`
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
	if err := h.store.Create(r.Context(), email, input.Platform, testingConsentVersion, input.LaunchUpdates, launchUpdatesConsentVersion); err != nil {
		http.Error(w, "We couldn’t save your signup. Please try again later.", http.StatusServiceUnavailable)
		return
	}
	forwardedSignup := repositories.TestingSignup{
		Email:          email,
		Platform:       input.Platform,
		ConsentVersion: testingConsentVersion,
		LaunchUpdates:  input.LaunchUpdates,
		CreatedAt:      time.Now(),
	}
	if input.LaunchUpdates {
		launchVersion := launchUpdatesConsentVersion
		consentedAt := forwardedSignup.CreatedAt
		forwardedSignup.LaunchConsentVersion = &launchVersion
		forwardedSignup.LaunchConsentedAt = &consentedAt
	}
	h.forwardAsync(forwardedSignup)
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
	_ = writer.Write([]string{"email", "platform", "signed_up_at", "consent_version", "launch_updates", "launch_consent_version", "launch_consented_at"})
	for _, signup := range signups {
		email := signup.Email
		// Email local parts can start with spreadsheet formula characters.
		if len(email) > 0 && strings.ContainsAny(email[:1], "=+-@") {
			email = "'" + email
		}
		launchVersion, launchAt := "", ""
		if signup.LaunchConsentVersion != nil {
			launchVersion = *signup.LaunchConsentVersion
		}
		if signup.LaunchConsentedAt != nil {
			launchAt = signup.LaunchConsentedAt.UTC().Format(time.RFC3339)
		}
		if err := writer.Write([]string{email, signup.Platform, signup.CreatedAt.UTC().Format(time.RFC3339), signup.ConsentVersion, fmt.Sprint(signup.LaunchUpdates), launchVersion, launchAt}); err != nil {
			return
		}
	}
	writer.Flush()
}

// inviteStoreURL is the listing for a platform, or "" when none is configured.
func (h *TestingSignupHandler) inviteStoreURL(platform string) string {
	if h.storeURLs == nil {
		return ""
	}
	return h.storeURLs[platform]
}

// InvitePreview renders the invitation for a platform so the team can look
// at it in a browser before anything is sent. Operator-only.
func (h *TestingSignupHandler) InvitePreview(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "android"
	}
	if platform != "android" && platform != "ios" {
		http.Error(w, "Choose android or ios.", http.StatusBadRequest)
		return
	}
	storeURL := h.inviteStoreURL(platform)
	if storeURL == "" {
		http.Error(w, "No store listing is configured for "+platform+".", http.StatusServiceUnavailable)
		return
	}
	msg := renderTestingInvite(platform, storeURL)
	if r.URL.Query().Get("format") == "text" {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("Subject: " + msg.Subject + "\n\n" + msg.Text))
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(msg.HTML))
}

// Invite emails the store invitation to signups for one platform. By default
// it goes to everyone on that platform who has not been invited yet and marks
// each one invited as soon as the provider accepts the message. Options in
// the JSON body: "emails" restricts the send to those addresses (they must be
// signups for the platform), "resend" includes people already invited, and
// "dry_run" reports who would get it without sending. Operator-only.
func (h *TestingSignupHandler) Invite(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "android"
	}
	if platform != "android" && platform != "ios" {
		http.Error(w, `{"error":"choose android or ios"}`, http.StatusBadRequest)
		return
	}
	if h.mailer == nil {
		http.Error(w, `{"error":"invitation mail is not configured"}`, http.StatusServiceUnavailable)
		return
	}
	storeURL := h.inviteStoreURL(platform)
	if storeURL == "" {
		http.Error(w, `{"error":"no store listing is configured for `+platform+`"}`, http.StatusServiceUnavailable)
		return
	}
	var input struct {
		Emails []string `json:"emails"`
		Resend bool     `json:"resend"`
		DryRun bool     `json:"dry_run"`
	}
	if r.Body != nil && r.ContentLength != 0 {
		r.Body = http.MaxBytesReader(w, r.Body, 64*1024)
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, `{"error":"invalid json body"}`, http.StatusBadRequest)
			return
		}
	}
	only := map[string]bool{}
	for _, e := range input.Emails {
		only[strings.ToLower(strings.TrimSpace(e))] = true
	}
	signups, err := h.store.List(r.Context(), platform)
	if err != nil {
		http.Error(w, `{"error":"could not read signups"}`, http.StatusServiceUnavailable)
		return
	}
	msg := renderTestingInvite(platform, storeURL)
	recipients, failed := []string{}, []string{}
	alreadyInvited := 0
	for _, signup := range signups {
		if len(only) > 0 && !only[signup.Email] {
			continue
		}
		if signup.InvitedAt != nil && !input.Resend {
			alreadyInvited++
			continue
		}
		if input.DryRun {
			recipients = append(recipients, signup.Email)
			continue
		}
		if err := h.mailer.SendHTMLWithHeadersOnce(signup.Email, msg.Subject, msg.HTML, msg.Text, nil); err != nil {
			failed = append(failed, signup.Email)
			log.Warn().Err(err).Str("platform", platform).Msg("testing signup: invitation send failed")
			continue
		}
		recipients = append(recipients, signup.Email)
		if err := h.store.MarkInvited(r.Context(), signup.Email, platform); err != nil {
			log.Warn().Err(err).Str("platform", platform).Msg("testing signup: could not record invitation")
		}
	}
	_ = json.NewEncoder(w).Encode(map[string]any{
		"platform":        platform,
		"dry_run":         input.DryRun,
		"subject":         msg.Subject,
		"sent":            recipients,
		"failed":          failed,
		"already_invited": alreadyInvited,
	})
}
