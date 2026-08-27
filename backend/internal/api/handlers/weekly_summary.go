package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// WeeklySummaryHandler exposes the household weekly summary.
type WeeklySummaryHandler struct {
	service *services.WeeklySummaryService
}

// NewWeeklySummaryHandler creates a new WeeklySummaryHandler.
func NewWeeklySummaryHandler(service *services.WeeklySummaryService) *WeeklySummaryHandler {
	return &WeeklySummaryHandler{service: service}
}

// RegisterRoutes mounts weekly summary routes.
func (h *WeeklySummaryHandler) RegisterRoutes(r chi.Router) {
	r.Get("/groups/{id}/weekly-summary", h.GetWeeklySummary)
}

// GetWeeklySummary handles GET /api/v1/groups/{id}/weekly-summary.
//
// The optional `tz_offset` query parameter is the caller's UTC offset in
// minutes (Dart's `DateTime.timeZoneOffset.inMinutes`) and only affects how the
// daily sparkline is bucketed. It is range-checked here so a malformed value is
// a 400 rather than a surprising interval in the query.
func (h *WeeklySummaryHandler) GetWeeklySummary(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	// Real-world UTC offsets span UTC-12:00 to UTC+14:00.
	const minOffset, maxOffset = -12 * 60, 14 * 60
	offsetMinutes := 0
	if raw := r.URL.Query().Get("tz_offset"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < minOffset || parsed > maxOffset {
			api.RespondError(w, &api.ValidationError{
				Field:   "tz_offset",
				Message: "must be minutes from UTC between -720 and 840",
			})
			return
		}
		offsetMinutes = parsed
	}

	summary, err := h.service.GetWeeklySummary(r.Context(), user, groupID, offsetMinutes)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, summary)
}
