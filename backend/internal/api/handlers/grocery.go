package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// GroceryHandler exposes the grocery graph sync endpoints.
type GroceryHandler struct {
	svc *services.GroceryService
}

// NewGroceryHandler creates a new GroceryHandler.
func NewGroceryHandler(svc *services.GroceryService) *GroceryHandler {
	return &GroceryHandler{svc: svc}
}

// RegisterRoutes mounts grocery routes under the authenticated group.
func (h *GroceryHandler) RegisterRoutes(r chi.Router) {
	r.Get("/groups/{groupID}/grocery/graph", h.GetGraph)
	r.Post("/groups/{groupID}/grocery/corrections", h.RecordCorrection)
	r.Patch("/groups/{groupID}/grocery/aisles", h.UpdateAisles)
}

// GetGraph returns the delta since a client cursor.
// Query param: since_version (int64, default 0).
func (h *GroceryHandler) GetGraph(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	groupID, err := parseUUIDParam(r, "groupID")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	sinceVersion, _ := strconv.ParseInt(r.URL.Query().Get("since_version"), 10, 64)

	delta, err := h.svc.GetGraphDelta(r.Context(), userID, groupID, sinceVersion)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, delta)
}

// UpdateAisles persists drag-to-reorder aisle feedback from the review screen.
func (h *GroceryHandler) UpdateAisles(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	groupID, err := parseUUIDParam(r, "groupID")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req services.AisleFeedbackRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	version, err := h.svc.UpdateAisles(r.Context(), userID, groupID, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{"version": version})
}

// RecordCorrection records a confirmed alias correction and notifies other devices.
func (h *GroceryHandler) RecordCorrection(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	groupID, err := parseUUIDParam(r, "groupID")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req services.RecordCorrectionRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	if req.RawText == "" {
		api.RespondError(w, &api.ValidationError{Field: "raw_text", Message: "raw_text is required"})
		return
	}
	if req.Kind == "" {
		req.Kind = "alias"
	}
	if req.Scope == "" {
		req.Scope = "household"
	}

	version, err := h.svc.RecordCorrection(r.Context(), userID, groupID, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{"version": version})
}
