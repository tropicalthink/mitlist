package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type HomeHandler struct {
	service *services.HomeService
}

func NewHomeHandler(service *services.HomeService) *HomeHandler {
	return &HomeHandler{service: service}
}

func (h *HomeHandler) RegisterRoutes(r chi.Router) {
	r.Get("/groups/{id}/home", h.GetSnapshot)
}

func (h *HomeHandler) GetSnapshot(w http.ResponseWriter, r *http.Request) {
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

	date, err := time.Parse("2006-01-02", r.URL.Query().Get("date"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "date", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}

	snapshot, err := h.service.GetSnapshot(r.Context(), user, groupID, date)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, snapshot)
}
