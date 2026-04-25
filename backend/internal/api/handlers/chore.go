package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// ChoreHandler exposes chore and assignment endpoints.
type ChoreHandler struct {
	service *services.ChoreService
}

// NewChoreHandler creates a new ChoreHandler.
func NewChoreHandler(service *services.ChoreService) *ChoreHandler {
	return &ChoreHandler{service: service}
}

// CreateChore POST /api/v1/chores
func (h *ChoreHandler) CreateChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID      uuid.UUID `json:"group_id"`
		Name         string    `json:"name"`
		Description  *string   `json:"description"`
		RotationType string    `json:"rotation_type"`
		Frequency    string    `json:"frequency"`
		IsActive     bool      `json:"is_active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	chore := &models.Chore{
		GroupID:      req.GroupID,
		Name:         req.Name,
		Description:  req.Description,
		RotationType: req.RotationType,
		Frequency:    req.Frequency,
		IsActive:     req.IsActive,
	}
	if err := h.service.CreateChore(r.Context(), user, chore); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, chore)
}

// ListChores GET /api/v1/chores
func (h *ChoreHandler) ListChores(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	limit, offset := parsePagination(r)

	chores, err := h.service.ListChores(r.Context(), user, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, chores)
}

// GetChore GET /api/v1/chores/{id}
func (h *ChoreHandler) GetChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	chore, err := h.service.GetChore(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, chore)
}

// UpdateChore PATCH /api/v1/chores/{id}
func (h *ChoreHandler) UpdateChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	var req struct {
		Name         string  `json:"name"`
		Description  *string `json:"description"`
		RotationType string  `json:"rotation_type"`
		Frequency    string  `json:"frequency"`
		IsActive     bool    `json:"is_active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	chore := &models.Chore{
		ID:           id,
		Name:         req.Name,
		Description:  req.Description,
		RotationType: req.RotationType,
		Frequency:    req.Frequency,
		IsActive:     req.IsActive,
	}
	chore, err = h.service.UpdateChore(r.Context(), user, chore)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, chore)
}

// DeleteChore DELETE /api/v1/chores/{id}
func (h *ChoreHandler) DeleteChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	if err := h.service.DeleteChore(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// RotateChore POST /api/v1/chores/{id}/rotate
func (h *ChoreHandler) RotateChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	if err := h.service.RotateChore(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// CompleteChore POST /api/v1/chores/{id}/complete
func (h *ChoreHandler) CompleteChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	var req struct {
		Notes *string `json:"notes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.CompleteChore(r.Context(), user, id, req.Notes); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// SkipChore POST /api/v1/chores/{id}/skip
func (h *ChoreHandler) SkipChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	if err := h.service.SkipChore(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// GetAssignments GET /api/v1/chores/{id}/assignments
func (h *ChoreHandler) GetAssignments(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 {
		limit = 50
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	assignments, err := h.service.GetAssignments(r.Context(), user, id, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, assignments)
}
