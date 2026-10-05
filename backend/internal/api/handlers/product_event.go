package handlers

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/services"
)

// Each sender (account, install, or address for a request with neither) gets
// a small bucket on top of the global per-IP limit: the app batches events,
// so a burst of more than a few requests a minute is not the app.
const (
	productEventBurst  = 20
	productEventRefill = 0.2 // per second
)

type productEventRecorder interface {
	Record(ctx context.Context, userID, installID *uuid.UUID, inputs []services.ProductEventInput) (int, error)
}

// ProductEventHandler accepts first-party product events (plans/048 stage 8)
// from the app. It is public: pre-signup events carry only the install id the
// app generated, and a session, when present, attributes them to the user
// (see middleware.OptionalAuth).
type ProductEventHandler struct {
	service productEventRecorder
}

func NewProductEventHandler(service productEventRecorder) *ProductEventHandler {
	return &ProductEventHandler{service: service}
}

func (h *ProductEventHandler) RegisterRoutes(r chi.Router) {
	r.Post("/events", h.Record)
}

type recordProductEventsRequest struct {
	InstallID *uuid.UUID                   `json:"install_id,omitempty"`
	Events    []services.ProductEventInput `json:"events"`
}

// Record stores a batch and answers 202 with how many were accepted. Events
// the server does not know are dropped, not rejected.
func (h *ProductEventHandler) Record(w http.ResponseWriter, r *http.Request) {
	var req recordProductEventsRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	var userID *uuid.UUID
	sender := "ip:" + middleware.ExtractIP(r)
	if user, ok := api.UserFromContext(r.Context()); ok {
		id := user.ID
		userID = &id
		sender = "user:" + id.String()
	} else if req.InstallID != nil {
		sender = "install:" + req.InstallID.String()
	}
	if !middleware.CheckLimit("ratelimit:events:"+sender, productEventBurst, productEventRefill) {
		api.RespondJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate limit exceeded"})
		return
	}

	accepted, err := h.service.Record(r.Context(), userID, req.InstallID, req.Events)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusAccepted, map[string]int{"accepted": accepted})
}
