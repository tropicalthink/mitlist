package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

const (
	maxCorrectionRawTextLength = 200
	maxCorrectionLangLength    = 8
	maxAisleFeedbackBatchSize  = 200
	maxAisleNameLength         = 64
	maxAisleSortOrder          = 100000
)

// These values mirror CHECK constraints in migration
// 000027_add_grocery_graph.up.sql.
var (
	validCorrectionKinds  = map[string]struct{}{"alias": {}, "canonical": {}, "aisle": {}, "unit": {}, "reject": {}}
	validCorrectionScopes = map[string]struct{}{"household": {}, "user": {}}
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
	if err := validateAisleFeedback(req); err != nil {
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
	req.RawText = strings.TrimSpace(req.RawText)
	if req.Kind == "" {
		req.Kind = "alias"
	}
	if req.Scope == "" {
		req.Scope = "household"
	}
	if err := validateCorrection(req); err != nil {
		api.RespondError(w, err)
		return
	}
	if req.Kind == "alias" && req.ResolvedCanonicalID != nil && req.CanonicalItem == nil {
		api.RespondError(w, &api.ValidationError{Field: "canonical_item", Message: "canonical_item is required"})
		return
	}

	version, err := h.svc.RecordCorrection(r.Context(), userID, groupID, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{"version": version})
}

func validateCorrection(req services.RecordCorrectionRequest) error {
	if req.RawText == "" {
		return &api.ValidationError{Field: "raw_text", Message: "raw_text is required"}
	}
	if len(req.RawText) > maxCorrectionRawTextLength {
		return &api.ValidationError{Field: "raw_text", Message: "raw_text exceeds maximum length"}
	}
	if _, ok := validCorrectionKinds[req.Kind]; !ok {
		return &api.ValidationError{Field: "kind", Message: "kind must be alias, canonical, aisle, unit, or reject"}
	}
	if _, ok := validCorrectionScopes[req.Scope]; !ok {
		return &api.ValidationError{Field: "scope", Message: "scope must be household or user"}
	}
	if len(req.Lang) > maxCorrectionLangLength {
		return &api.ValidationError{Field: "lang", Message: "lang exceeds maximum length"}
	}
	return nil
}

func validateAisleFeedback(req services.AisleFeedbackRequest) error {
	if len(req.Aisles) > maxAisleFeedbackBatchSize {
		return &api.ValidationError{Field: "aisles", Message: "aisles exceeds maximum batch size"}
	}
	for i, item := range req.Aisles {
		if len(item.Aisle) > maxAisleNameLength {
			return &api.ValidationError{
				Field:   "aisles",
				Message: fmt.Sprintf("aisles[%d].aisle exceeds maximum length", i),
			}
		}
		if item.SortOrder < 0 || item.SortOrder > maxAisleSortOrder {
			return &api.ValidationError{
				Field:   "aisles",
				Message: fmt.Sprintf("aisles[%d].sort_order must be between 0 and %d", i, maxAisleSortOrder),
			}
		}
	}
	return nil
}
