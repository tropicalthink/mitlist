// Package turnstile verifies Cloudflare Turnstile tokens for requests that
// create unauthenticated guest accounts from the web.
//
// It exists because App Check has no web attestation provider we want: the
// built-in one is reCAPTCHA Enterprise, which needs GCP billing, and the only
// thing being protected is a single guest-signup endpoint that this service
// enforces itself. Mobile keeps App Check (Play Integrity / App Attest), so
// the guest boundary accepts either proof — see AuthHandler.CreateGuest.
package turnstile

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
)

const (
	defaultVerifyURL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
	maxResponseBytes = 1 << 16
	requestTimeout   = 5 * time.Second
)

var (
	ErrDisabled = errors.New("turnstile is disabled")
	ErrMissing  = errors.New("turnstile token is missing")
	ErrInvalid  = errors.New("turnstile token is invalid")
)

// Result holds the verified parts of a siteverify response.
type Result struct {
	Hostname    string
	Action      string
	ChallengeTS time.Time
}

// QuotaIdentity mirrors appcheck.Claims.QuotaIdentity: a caller-supplied
// installation ID only ever supplements verified state, never replaces it, and
// a malformed one yields no identity at all rather than a spoofable string.
//
// Turnstile has no per-app subject the way an App Check token does, so the
// namespace is the scheme itself. That is deliberately weaker than
// "app:<id>:installation:<uuid>" — a solved challenge proves a human-ish
// browser, not which app asked.
func (r *Result) QuotaIdentity(installationID string) string {
	if r == nil {
		return ""
	}
	parsed, err := uuid.Parse(strings.TrimSpace(installationID))
	if err != nil || parsed == uuid.Nil {
		return ""
	}
	return "turnstile:installation:" + parsed.String()
}

// Verifier calls Cloudflare's siteverify endpoint.
type Verifier struct {
	secret    string
	verifyURL string
	client    *http.Client
}

// New returns a verifier that is disabled unless TURNSTILE_SECRET_KEY is set.
// Absent config is not an error: self-hosted builds run without it, exactly as
// they run without App Check.
func New(cfg *config.Config) *Verifier {
	if cfg == nil {
		return &Verifier{}
	}
	return &Verifier{
		secret:    strings.TrimSpace(cfg.TurnstileSecretKey),
		verifyURL: defaultVerifyURL,
		client:    &http.Client{Timeout: requestTimeout},
	}
}

// NewForTesting builds a verifier against an injected endpoint.
func NewForTesting(secret, verifyURL string, client *http.Client) *Verifier {
	if client == nil {
		client = &http.Client{Timeout: requestTimeout}
	}
	return &Verifier{secret: strings.TrimSpace(secret), verifyURL: verifyURL, client: client}
}

// Enabled reports whether a secret was configured.
func (v *Verifier) Enabled() bool {
	return v != nil && v.secret != ""
}

type siteVerifyResponse struct {
	Success     bool     `json:"success"`
	ErrorCodes  []string `json:"error-codes"`
	Hostname    string   `json:"hostname"`
	Action      string   `json:"action"`
	ChallengeTS string   `json:"challenge_ts"`
}

// Verify exchanges a client-side token for a verdict. remoteIP is optional;
// Cloudflare treats it as advisory, so a proxy that mangles it degrades the
// check rather than failing it.
func (v *Verifier) Verify(ctx context.Context, token, remoteIP string) (*Result, error) {
	if !v.Enabled() {
		return nil, ErrDisabled
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, ErrMissing
	}

	form := url.Values{}
	form.Set("secret", v.secret)
	form.Set("response", token)
	if ip := strings.TrimSpace(remoteIP); ip != "" {
		form.Set("remoteip", ip)
	}

	reqCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, v.verifyURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, ErrInvalid
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := v.client.Do(req)
	if err != nil {
		return nil, ErrInvalid
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		return nil, ErrInvalid
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil || len(body) > maxResponseBytes {
		return nil, ErrInvalid
	}

	var parsed siteVerifyResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, ErrInvalid
	}
	if !parsed.Success {
		return nil, ErrInvalid
	}

	result := &Result{Hostname: parsed.Hostname, Action: parsed.Action}
	if ts, err := time.Parse(time.RFC3339, parsed.ChallengeTS); err == nil {
		result.ChallengeTS = ts
	}
	return result, nil
}
