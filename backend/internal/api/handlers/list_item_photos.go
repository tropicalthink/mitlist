package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type ListItemPhotoHandler struct {
	service *services.ListItemPhotoService
}

func NewListItemPhotoHandler(service *services.ListItemPhotoService) *ListItemPhotoHandler {
	return &ListItemPhotoHandler{service: service}
}

func (h *ListItemPhotoHandler) RegisterRoutes(r chi.Router) {
	r.Post("/lists/items/{id}/photos", h.Attach)
	r.Get("/lists/items/{id}/photos", h.List)
	r.Delete("/lists/items/{id}/photos/{attachment_id}", h.Detach)
	r.Get("/lists/{id}/item-photos", h.ListByList)
}

// ListByList returns photos for every item in a list in one response, keyed
// by list item id. Items without photos are absent from the map.
func (h *ListItemPhotoHandler) ListByList(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid list id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	out, err := h.service.ListByList(r.Context(), user.ID, groupID, listID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, out)
}

func (h *ListItemPhotoHandler) Attach(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid list item id"})
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

	if err := h.service.Attach(r.Context(), user.ID, req.GroupID, itemID, req.AttachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

func (h *ListItemPhotoHandler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid list item id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	out, err := h.service.List(r.Context(), user.ID, groupID, itemID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, out)
}

func (h *ListItemPhotoHandler) Detach(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid list item id"})
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

	if err := h.service.Detach(r.Context(), user.ID, groupID, itemID, attachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}
