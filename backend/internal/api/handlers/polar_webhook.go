package handlers

import (
	"errors"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/internal/services/polar"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// PolarWebhookHandler receives billing events from Polar and hands them to the
// billing service, which owns the subscription state they describe.
//
// Polar authenticates itself with a Standard Webhooks signature rather than a
// user token, so this route is public. Everything it accepts is signature-
// verified first.
type PolarWebhookHandler struct {
	log     *logger.Logger
	billing *services.BillingService
	wh      *polar.WebhookVerifier
}

// NewPolarWebhookHandler creates a handler backed by cfg.PolarWebhookSecret.
// When the secret is unset, the returned handler answers every request with
// 503 — billing is opt-in and off by default.
func NewPolarWebhookHandler(cfg *config.Config, billing *services.BillingService, log *logger.Logger) (*PolarWebhookHandler, error) {
	h := &PolarWebhookHandler{log: log, billing: billing}
	if cfg.PolarWebhookSecret == "" {
		return h, nil
	}
	wh, err := polar.NewWebhookVerifier(cfg.PolarWebhookSecret)
	if err != nil {
		return nil, err
	}
	h.wh = wh
	return h, nil
}

// RegisterRoutes mounts the webhook endpoint.
func (h *PolarWebhookHandler) RegisterRoutes(r chi.Router) {
	r.Post("/webhooks/polar", h.ServeHTTP)
}

func (h *PolarWebhookHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if h.wh == nil {
		http.Error(w, "billing not configured", http.StatusServiceUnavailable)
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "cannot read body", http.StatusBadRequest)
		return
	}

	if err := h.wh.Verify(body, r.Header); err != nil {
		h.log.Warn().Err(err).Msg("polar webhook: signature verification failed")
		http.Error(w, "invalid signature", http.StatusUnauthorized)
		return
	}

	deliveryID := r.Header.Get(polar.HeaderWebhookID)

	// A failure here is answered with 5xx so Polar retries. Anything the
	// service deliberately skips — a redelivery, another app's event — is a
	// success as far as delivery is concerned.
	if err := h.billing.ApplyWebhookEvent(r.Context(), deliveryID, body); err != nil {
		if errors.Is(err, services.ErrEventIgnored) {
			w.WriteHeader(http.StatusOK)
			return
		}
		h.log.Error().Err(err).Str("delivery_id", deliveryID).Msg("polar webhook: failed to apply event")
		http.Error(w, "failed to apply event", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}
