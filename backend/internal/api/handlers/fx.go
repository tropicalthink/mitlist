package handlers

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	fxsvc "github.com/mitlist-app/mitlist/internal/services/fx"
)

// FxHandler serves advisory exchange-rate suggestions for the add-expense form.
// The feature is opt-in (controlled by FX_RATE_API_URL); when disabled or on
// any provider failure the endpoint returns {"available":false} — never a 5xx.
type FxHandler struct {
	svc *fxsvc.RateService
}

// NewFxHandler creates a handler backed by svc.
func NewFxHandler(svc *fxsvc.RateService) *FxHandler {
	return &FxHandler{svc: svc}
}

// RegisterRoutes mounts the FX rate endpoint next to the finance routes.
func (h *FxHandler) RegisterRoutes(r chi.Router) {
	r.Get("/fx/rate", h.GetRate)
}

// fxRateResponse is the JSON body for an available rate.
type fxRateResponse struct {
	Available bool    `json:"available"`
	Rate      float64 `json:"rate,omitempty"`
	From      string  `json:"from,omitempty"`
	To        string  `json:"to,omitempty"`
}

// GetRate GET /fx/rate?from=USD&to=EUR
//
// Returns {"available":true,"rate":0.92,"from":"USD","to":"EUR"} on success or
// {"available":false} when the feature is disabled, params are invalid, or the
// provider is unreachable. Always returns HTTP 200 — the client must never need
// to handle a 5xx for "no rate available".
func (h *FxHandler) GetRate(w http.ResponseWriter, r *http.Request) {
	from := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("from")))
	to := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("to")))

	if from == "" || to == "" {
		api.RespondError(w, &api.ValidationError{Message: "from and to query parameters are required"})
		return
	}

	rate, available, err := h.svc.GetRate(r.Context(), from, to)
	if err != nil {
		// GetRate only surfaces an error for non-recoverable internal conditions;
		// degrade to unavailable rather than surfacing 5xx to the client.
		api.RespondJSON(w, http.StatusOK, fxRateResponse{Available: false})
		return
	}

	if !available {
		api.RespondJSON(w, http.StatusOK, fxRateResponse{Available: false})
		return
	}

	api.RespondJSON(w, http.StatusOK, fxRateResponse{
		Available: true,
		Rate:      rate,
		From:      from,
		To:        to,
	})
}
