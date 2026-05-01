package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/services"
)

// CalendarHandler exposes calendar aggregation endpoints.
type CalendarHandler struct {
	service *services.CalendarService
}

// NewCalendarHandler creates a new CalendarHandler.
func NewCalendarHandler(service *services.CalendarService) *CalendarHandler {
	return &CalendarHandler{service: service}
}

// RegisterRoutes mounts calendar routes.
func (h *CalendarHandler) RegisterRoutes(r chi.Router) {
	r.Get("/calendar", h.GetCalendar)
}

func (h *CalendarHandler) GetCalendar(w http.ResponseWriter, r *http.Request) {
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

	fromStr := r.URL.Query().Get("from")
	toStr := r.URL.Query().Get("to")
	if fromStr == "" || toStr == "" {
		respondError(w, &api.ValidationError{Field: "from,to", Message: "from and to dates are required"})
		return
	}

	from, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "from", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}
	to, err := time.Parse("2006-01-02", toStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "to", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}

	events, err := h.service.GetCalendar(r.Context(), user, groupID, from, to)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{"events": events})
}
