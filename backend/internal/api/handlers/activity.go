package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/services"
)

// ActivityHandler exposes activity log endpoints.
type ActivityHandler struct {
	service *services.ActivityService
}

// NewActivityHandler creates a new ActivityHandler.
func NewActivityHandler(service *services.ActivityService) *ActivityHandler {
	return &ActivityHandler{service: service}
}

func (h *ActivityHandler) RegisterRoutes(r chi.Router) {
	r.Get("/activity-logs", h.ListActivityLogs)
	r.Get("/activity-logs/{id}", h.GetActivityLog)
	r.Delete("/activity-logs/{id}", h.DeleteActivityLog)
}

func (h *ActivityHandler) ListActivityLogs(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		respondError(w, api.ErrValidation)
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		respondError(w, api.ErrValidation)
		return
	}

	limit, offset := parsePagination(r)
	logs, err := h.service.ListActivityLogs(r.Context(), userID, groupID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, logs)
}

func (h *ActivityHandler) GetActivityLog(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	logEntry, err := h.service.GetActivityLog(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, logEntry)
}

func (h *ActivityHandler) DeleteActivityLog(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteActivityLog(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
