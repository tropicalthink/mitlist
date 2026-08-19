package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"google.golang.org/api/idtoken"
)

// IAPWebhookHandler receives store-side subscription notifications: Apple App
// Store Server Notifications V2 and Google Play Real-Time Developer
// Notifications. Both are public routes — the stores call them directly — and
// both establish trust inside the billing service rather than with a shared
// user token: Apple's payload is a signed JWS, and Google notifications are
// re-verified against the Play API before anything is applied.
type IAPWebhookHandler struct {
	log                  *logger.Logger
	billing              *services.BillingService
	googleAudience       string
	googleServiceAccount string
	validateGoogleToken  func(context.Context, string, string) (*idtoken.Payload, error)
}

// NewIAPWebhookHandler creates a handler backed by the billing service.
func NewIAPWebhookHandler(billing *services.BillingService, log *logger.Logger, googleAudience, googleServiceAccount string) *IAPWebhookHandler {
	return &IAPWebhookHandler{
		log: log, billing: billing,
		googleAudience:       googleAudience,
		googleServiceAccount: googleServiceAccount,
		validateGoogleToken:  idtoken.Validate,
	}
}

// RegisterRoutes mounts the store notification endpoints.
func (h *IAPWebhookHandler) RegisterRoutes(r chi.Router) {
	r.Post("/webhooks/apple", h.ServeApple)
	r.Post("/webhooks/google", h.ServeGoogle)
}

// appleNotificationBody is the envelope Apple posts: a single signed JWS.
type appleNotificationBody struct {
	SignedPayload string `json:"signedPayload"`
}

// ServeApple handles an App Store Server Notification V2. The signature is
// verified inside the billing service; an unverifiable payload is a 400 (no
// retry), a transient failure is a 500 (Apple retries), and a duplicate or
// irrelevant event is a 200.
func (h *IAPWebhookHandler) ServeApple(w http.ResponseWriter, r *http.Request) {
	if !h.billing.AppleIAPEnabled() {
		http.Error(w, "apple iap not configured", http.StatusServiceUnavailable)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "cannot read body", http.StatusBadRequest)
		return
	}
	var payload appleNotificationBody
	if err := json.Unmarshal(body, &payload); err != nil || payload.SignedPayload == "" {
		http.Error(w, "missing signedPayload", http.StatusBadRequest)
		return
	}

	h.respond(w, "apple", h.billing.ApplyAppleNotification(r.Context(), payload.SignedPayload))
}

// ServeGoogle handles a Real-Time Developer Notification delivered as a Pub/Sub
// push. The whole body is the Pub/Sub envelope; the billing service decodes it
// and re-fetches the authoritative state from Google.
func (h *IAPWebhookHandler) ServeGoogle(w http.ResponseWriter, r *http.Request) {
	if !h.billing.GoogleIAPEnabled() {
		http.Error(w, "google iap not configured", http.StatusServiceUnavailable)
		return
	}
	if err := h.authenticateGooglePush(r); err != nil {
		h.log.Warn().Err(err).Msg("iap webhook: rejected unauthenticated Google push")
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "cannot read body", http.StatusBadRequest)
		return
	}

	h.respond(w, "google", h.billing.ApplyGoogleNotification(r.Context(), body))
}

func (h *IAPWebhookHandler) authenticateGooglePush(r *http.Request) error {
	if h.googleAudience == "" || h.googleServiceAccount == "" {
		return errors.New("Google Pub/Sub OIDC is not configured")
	}
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return errors.New("missing bearer token")
	}
	payload, err := h.validateGoogleToken(r.Context(), strings.TrimSpace(strings.TrimPrefix(header, "Bearer ")), h.googleAudience)
	if err != nil {
		return err
	}
	email, _ := payload.Claims["email"].(string)
	emailVerified, _ := payload.Claims["email_verified"].(bool)
	if email != h.googleServiceAccount || !emailVerified {
		return errors.New("unexpected Pub/Sub service account")
	}
	return nil
}

// respond maps a service result to a delivery response. Ignored events succeed
// (nothing to retry); malformed payloads are 400 (retrying will not help);
// everything else is 500 so the store redelivers.
func (h *IAPWebhookHandler) respond(w http.ResponseWriter, provider string, err error) {
	if err == nil || errors.Is(err, services.ErrEventIgnored) {
		w.WriteHeader(http.StatusOK)
		return
	}
	var ve *api.ValidationError
	if errors.As(err, &ve) {
		h.log.Warn().Err(err).Str("provider", provider).Msg("iap webhook: rejected payload")
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}
	h.log.Error().Err(err).Str("provider", provider).Msg("iap webhook: failed to apply notification")
	http.Error(w, "failed to apply notification", http.StatusInternalServerError)
}
