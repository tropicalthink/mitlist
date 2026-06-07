package handlers

import (
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// ChoreHandler exposes chore and assignment endpoints.
type ChoreHandler struct {
	service *services.ChoreService
}

// NewChoreHandler creates a new ChoreHandler.
func NewChoreHandler(service *services.ChoreService) *ChoreHandler {
	return &ChoreHandler{service: service}
}

// RegisterRoutes mounts all chore routes.
func (h *ChoreHandler) RegisterRoutes(r chi.Router) {
	r.Post("/chores", h.CreateChore)
	r.Get("/chores", h.ListChores)
	r.Get("/chores/current", h.ListCurrentChores)
	r.Get("/chores/{id}/details", h.GetChoreDetails)
	r.Get("/chores/{id}", h.GetChore)
	r.Patch("/chores/{id}", h.UpdateChore)
	r.Delete("/chores/{id}", h.DeleteChore)
	r.Post("/chores/{id}/rotate", h.RotateChore)
	r.Post("/chores/{id}/complete", h.CompleteChore)
	r.Post("/chores/{id}/skip", h.SkipChore)
	r.Patch("/chores/{id}/pending", h.RescheduleChore)
	r.Post("/chores/{id}/undo", h.UndoLastChoreExecution)
	r.Get("/chores/{id}/assignments", h.GetAssignments)
	r.Get("/chores/{id}/subtasks", h.ListSubtasks)
	r.Post("/chores/{id}/subtasks", h.CreateSubtask)
	r.Put("/chores/{id}/subtasks/reorder", h.ReorderSubtasks)
	r.Patch("/chores/subtasks/{subtask_id}", h.UpdateSubtask)
	r.Delete("/chores/subtasks/{subtask_id}", h.DeleteSubtask)
	r.Post("/chores/{id}/add-supplies-to-list", h.AddSuppliesToList)
}

// CreateChore POST /api/v1/chores
func (h *ChoreHandler) CreateChore(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID          uuid.UUID   `json:"group_id"`
		Name             string      `json:"name"`
		Description      *string     `json:"description"`
		RotationType     string      `json:"rotation_type"`
		Frequency        string      `json:"frequency"`
		PeriodInterval   int         `json:"period_interval"`
		PeriodConfig     []string    `json:"period_config"`
		StartDate        *time.Time  `json:"start_date"`
		TrackDateOnly    bool        `json:"track_date_only"`
		Rollover         bool        `json:"rollover"`
		AssignmentType   string      `json:"assignment_type"`
		AssignmentConfig []uuid.UUID `json:"assignment_config"`
		IsActive         *bool       `json:"is_active"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	chore := &models.Chore{
		GroupID:          req.GroupID,
		Name:             req.Name,
		Description:      req.Description,
		RotationType:     req.RotationType,
		Frequency:        req.Frequency,
		PeriodInterval:   req.PeriodInterval,
		PeriodConfig:     req.PeriodConfig,
		StartDate:        req.StartDate,
		TrackDateOnly:    req.TrackDateOnly,
		Rollover:         req.Rollover,
		AssignmentType:   req.AssignmentType,
		AssignmentConfig: req.AssignmentConfig,
		IsActive:         isActive,
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

// ListCurrentChores GET /api/v1/chores/current
func (h *ChoreHandler) ListCurrentChores(w http.ResponseWriter, r *http.Request) {
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
	dueSoonDays, _ := strconv.Atoi(r.URL.Query().Get("due_soon_days"))
	if dueSoonDays < 0 {
		dueSoonDays = 0
	}

	chores, err := h.service.ListCurrentChores(r.Context(), user, groupID, limit, offset, dueSoonDays)
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

// GetChoreDetails GET /api/v1/chores/{id}/details
func (h *ChoreHandler) GetChoreDetails(w http.ResponseWriter, r *http.Request) {
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
	dueSoonDays, _ := strconv.Atoi(r.URL.Query().Get("due_soon_days"))
	if dueSoonDays < 0 {
		dueSoonDays = 0
	}

	details, err := h.service.GetChoreDetails(r.Context(), user, id, dueSoonDays)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, details)
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
		Name             string      `json:"name"`
		Description      *string     `json:"description"`
		RotationType     string      `json:"rotation_type"`
		Frequency        string      `json:"frequency"`
		PeriodInterval   int         `json:"period_interval"`
		PeriodConfig     []string    `json:"period_config"`
		StartDate        *time.Time  `json:"start_date"`
		TrackDateOnly    *bool       `json:"track_date_only"`
		Rollover         *bool       `json:"rollover"`
		AssignmentType   string      `json:"assignment_type"`
		AssignmentConfig []uuid.UUID `json:"assignment_config"`
		IsActive         *bool       `json:"is_active"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	existing, err := h.service.GetChore(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	trackDateOnly := existing.TrackDateOnly
	if req.TrackDateOnly != nil {
		trackDateOnly = *req.TrackDateOnly
	}
	rollover := existing.Rollover
	if req.Rollover != nil {
		rollover = *req.Rollover
	}
	isActive := existing.IsActive
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	chore := &models.Chore{
		ID:               id,
		Name:             req.Name,
		Description:      req.Description,
		RotationType:     req.RotationType,
		Frequency:        req.Frequency,
		PeriodInterval:   req.PeriodInterval,
		PeriodConfig:     req.PeriodConfig,
		StartDate:        req.StartDate,
		TrackDateOnly:    trackDateOnly,
		Rollover:         rollover,
		AssignmentType:   req.AssignmentType,
		AssignmentConfig: req.AssignmentConfig,
		IsActive:         isActive,
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
	if err := decodeJSON(r, &req); err != nil {
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

	var req struct {
		SkipReason *string `json:"skip_reason"`
	}
	if err := decodeJSON(r, &req); err != nil && err != io.EOF {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.SkipChore(r.Context(), user, id, req.SkipReason); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// RescheduleChore PATCH /api/v1/chores/{id}/pending
func (h *ChoreHandler) RescheduleChore(w http.ResponseWriter, r *http.Request) {
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
		DueDate    *time.Time `json:"due_date"`
		AssigneeID *uuid.UUID `json:"assignee_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.RescheduleChore(r.Context(), user, id, req.DueDate, req.AssigneeID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// UndoLastChoreExecution POST /api/v1/chores/{id}/undo
func (h *ChoreHandler) UndoLastChoreExecution(w http.ResponseWriter, r *http.Request) {
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

	if err := h.service.UndoLastChoreExecution(r.Context(), user, id); err != nil {
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

// ListSubtasks GET /api/v1/chores/{id}/subtasks
func (h *ChoreHandler) ListSubtasks(w http.ResponseWriter, r *http.Request) {
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

	subtasks, err := h.service.ListSubtasks(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, subtasks)
}

// CreateSubtask POST /api/v1/chores/{id}/subtasks
func (h *ChoreHandler) CreateSubtask(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	choreID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	var req struct {
		Title string `json:"title"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	subtask := &models.ChoreSubtask{
		ChoreID: choreID,
		Title:   req.Title,
	}
	subtask, err = h.service.CreateSubtask(r.Context(), user, subtask)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, subtask)
}

// UpdateSubtask PATCH /api/v1/chores/subtasks/{subtask_id}
func (h *ChoreHandler) UpdateSubtask(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	subtaskID, err := uuid.Parse(chi.URLParam(r, "subtask_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "subtask_id", Message: "invalid subtask id"})
		return
	}

	var req struct {
		Title     *string `json:"title"`
		Completed *bool   `json:"completed"`
		Position  *int    `json:"position"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	subtask := &models.ChoreSubtask{
		ID: subtaskID,
	}
	if req.Title != nil {
		subtask.Title = *req.Title
	}
	if req.Completed != nil {
		subtask.Completed = *req.Completed
	}
	if req.Position != nil {
		subtask.Position = *req.Position
	}

	subtask, err = h.service.UpdateSubtask(r.Context(), user, subtask)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, subtask)
}

// DeleteSubtask DELETE /api/v1/chores/subtasks/{subtask_id}
func (h *ChoreHandler) DeleteSubtask(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	subtaskID, err := uuid.Parse(chi.URLParam(r, "subtask_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "subtask_id", Message: "invalid subtask id"})
		return
	}

	if err := h.service.DeleteSubtask(r.Context(), user, subtaskID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// ReorderSubtasks PUT /api/v1/chores/{id}/subtasks/reorder
func (h *ChoreHandler) ReorderSubtasks(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	choreID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	var req struct {
		SubtaskIDs []uuid.UUID `json:"subtask_ids"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.ReorderSubtasks(r.Context(), user, choreID, req.SubtaskIDs); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// AddSuppliesToList POST /api/v1/chores/{id}/add-supplies-to-list
func (h *ChoreHandler) AddSuppliesToList(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	choreID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore id"})
		return
	}

	var req struct {
		ListID uuid.UUID `json:"list_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.AddSuppliesToList(r.Context(), user, choreID, req.ListID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}
