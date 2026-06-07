package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type AttachmentHandler struct {
	service *services.AttachmentService
}

func NewAttachmentHandler(service *services.AttachmentService) *AttachmentHandler {
	return &AttachmentHandler{service: service}
}

func (h *AttachmentHandler) RegisterRoutes(r chi.Router) {
	r.Post("/attachments/upload-intent", h.CreateUploadIntent)
	r.Post("/attachments/{id}/finalize", h.Finalize)
	r.Get("/attachments/{id}/url", h.GetURL)
	r.Delete("/attachments/{id}", h.Delete)
}

func (h *AttachmentHandler) CreateUploadIntent(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req services.CreateUploadIntentInput
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	intent, err := h.service.CreateUploadIntent(r.Context(), user, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, intent)
}

func (h *AttachmentHandler) Finalize(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	attachmentID, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req struct {
		GroupID uuid.UUID `json:"group_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	a, err := h.service.FinalizeUpload(r.Context(), user, req.GroupID, attachmentID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, a)
}

func (h *AttachmentHandler) GetURL(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	attachmentID, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	url, err := h.service.GetDownloadURL(r.Context(), user, groupID, attachmentID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"url": url})
}

func (h *AttachmentHandler) Delete(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	attachmentID, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	if err := h.service.DeleteAttachment(r.Context(), user, groupID, attachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

