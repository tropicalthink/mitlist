package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type PinwallMediaHandler struct {
	service *services.PinwallMediaService
}

func NewPinwallMediaHandler(service *services.PinwallMediaService) *PinwallMediaHandler {
	return &PinwallMediaHandler{service: service}
}

func (h *PinwallMediaHandler) RegisterRoutes(r chi.Router) {
	r.Post("/pinwall/posts/{id}/attachments", h.Attach)
	r.Get("/pinwall/posts/{id}/attachments", h.List)
	r.Delete("/pinwall/posts/{id}/attachments/{attachment_id}", h.Detach)
}

func (h *PinwallMediaHandler) Attach(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	postID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid post id"})
		return
	}

	var req struct {
		GroupID      uuid.UUID `json:"group_id"`
		AttachmentID uuid.UUID `json:"attachment_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.Attach(r.Context(), user.ID, req.GroupID, postID, req.AttachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

func (h *PinwallMediaHandler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	postID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid post id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	out, err := h.service.List(r.Context(), user.ID, groupID, postID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, out)
}

func (h *PinwallMediaHandler) Detach(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	postID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid post id"})
		return
	}

	attachmentID, err := uuid.Parse(chi.URLParam(r, "attachment_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "attachment_id", Message: "invalid attachment id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	if err := h.service.Detach(r.Context(), user.ID, groupID, postID, attachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}
