package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// TemplateHandler exposes list and chore template endpoints.
type TemplateHandler struct {
	service *services.TemplateService
}

// NewTemplateHandler creates a new TemplateHandler.
func NewTemplateHandler(service *services.TemplateService) *TemplateHandler {
	return &TemplateHandler{service: service}
}

// RegisterRoutes mounts all template and chore-template routes.
func (h *TemplateHandler) RegisterRoutes(r chi.Router) {
	r.Post("/templates", h.CreateTemplate)
	r.Get("/templates", h.ListTemplates)
	r.Get("/templates/{id}", h.GetTemplate)
	r.Patch("/templates/{id}", h.UpdateTemplate)
	r.Delete("/templates/{id}", h.DeleteTemplate)
	r.Post("/templates/{id}/apply", h.ApplyTemplate)
	r.Post("/chore-templates", h.CreateChoreTemplate)
	r.Get("/chore-templates", h.ListChoreTemplates)
	r.Get("/chore-templates/{id}", h.GetChoreTemplate)
	r.Patch("/chore-templates/{id}", h.UpdateChoreTemplate)
	r.Delete("/chore-templates/{id}", h.DeleteChoreTemplate)
}

// CreateTemplate POST /api/v1/templates
func (h *TemplateHandler) CreateTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID uuid.UUID `json:"group_id"`
		Name    string    `json:"name"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	tpl := &models.Template{
		GroupID: req.GroupID,
		Name:    req.Name,
	}
	if err := h.service.CreateTemplate(r.Context(), user, tpl); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, tpl)
}

// ListTemplates GET /api/v1/templates
func (h *TemplateHandler) ListTemplates(w http.ResponseWriter, r *http.Request) {
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

	templates, err := h.service.ListTemplates(r.Context(), user, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, templates)
}

// GetTemplate GET /api/v1/templates/{id}
func (h *TemplateHandler) GetTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid template id"})
		return
	}

	tpl, err := h.service.GetTemplate(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, tpl)
}

// UpdateTemplate PATCH /api/v1/templates/{id}
func (h *TemplateHandler) UpdateTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid template id"})
		return
	}

	var req struct {
		Name string `json:"name"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	tpl, err := h.service.UpdateTemplate(r.Context(), user, id, req.Name)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, tpl)
}

// DeleteTemplate DELETE /api/v1/templates/{id}
func (h *TemplateHandler) DeleteTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid template id"})
		return
	}

	if err := h.service.DeleteTemplate(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// ApplyTemplate POST /api/v1/templates/{id}/apply
func (h *TemplateHandler) ApplyTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid template id"})
		return
	}

	var req struct {
		ListName string `json:"list_name"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	list, err := h.service.ApplyTemplate(r.Context(), user, id, req.ListName)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, list)
}

// ------------------------------------------------------------------
// Chore Templates
// ------------------------------------------------------------------

// CreateChoreTemplate POST /api/v1/chore-templates
func (h *TemplateHandler) CreateChoreTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID      uuid.UUID `json:"group_id"`
		Name         string    `json:"name"`
		RotationType string    `json:"rotation_type"`
		Frequency    string    `json:"frequency"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	ct := &models.ChoreTemplate{
		GroupID:      req.GroupID,
		Name:         req.Name,
		RotationType: req.RotationType,
		Frequency:    req.Frequency,
	}
	if err := h.service.CreateChoreTemplate(r.Context(), user, ct); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, ct)
}

// ListChoreTemplates GET /api/v1/chore-templates
func (h *TemplateHandler) ListChoreTemplates(w http.ResponseWriter, r *http.Request) {
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

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 {
		limit = 50
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	templates, err := h.service.ListChoreTemplates(r.Context(), user, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, templates)
}

// GetChoreTemplate GET /api/v1/chore-templates/{id}
func (h *TemplateHandler) GetChoreTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore template id"})
		return
	}

	ct, err := h.service.GetChoreTemplate(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, ct)
}

// UpdateChoreTemplate PATCH /api/v1/chore-templates/{id}
func (h *TemplateHandler) UpdateChoreTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore template id"})
		return
	}

	var req struct {
		Name         string `json:"name"`
		RotationType string `json:"rotation_type"`
		Frequency    string `json:"frequency"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	ct := &models.ChoreTemplate{
		ID:           id,
		Name:         req.Name,
		RotationType: req.RotationType,
		Frequency:    req.Frequency,
	}
	ct, err = h.service.UpdateChoreTemplate(r.Context(), user, ct)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, ct)
}

// DeleteChoreTemplate DELETE /api/v1/chore-templates/{id}
func (h *TemplateHandler) DeleteChoreTemplate(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid chore template id"})
		return
	}

	if err := h.service.DeleteChoreTemplate(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}
