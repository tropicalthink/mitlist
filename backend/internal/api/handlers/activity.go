package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/services"
)

// ActivityHandler exposes activity endpoints.
type ActivityHandler struct {
	service *services.ActivityService
}

// NewActivityHandler creates a new ActivityHandler.
func NewActivityHandler(service *services.ActivityService) *ActivityHandler {
	return &ActivityHandler{service: service}
}

// RegisterRoutes mounts activity routes.
func (h *ActivityHandler) RegisterRoutes(r chi.Router) {
	r.Get("/activity", h.ListActivity)
}

func (h *ActivityHandler) ListActivity(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	limit := 10
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	events, err := h.service.ListRecentActivity(r.Context(), user, groupID, limit)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{"events": events})
}
