package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type PinwallHandler struct {
	service *services.PinwallService
}

func NewPinwallHandler(service *services.PinwallService) *PinwallHandler {
	return &PinwallHandler{service: service}
}

func (h *PinwallHandler) RegisterRoutes(r chi.Router) {
	r.Post("/pinwall/posts", h.CreatePost)
	r.Get("/pinwall/posts", h.ListPosts)
	r.Delete("/pinwall/posts/{id}", h.DeletePost)
	r.Put("/pinwall/posts/{id}", h.UpdatePost)
	r.Put("/pinwall/posts/{id}/position", h.UpdatePostPosition)
}

type createPinwallPostRequest struct {
	GroupID  uuid.UUID `json:"group_id"`
	Content  string    `json:"content"`
	RemindAt *string   `json:"remind_at,omitempty"`
}

func (h *PinwallHandler) CreatePost(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req createPinwallPostRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	req.Content = strings.TrimSpace(req.Content)

	var remindAt *time.Time
	if req.RemindAt != nil && strings.TrimSpace(*req.RemindAt) != "" {
		parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(*req.RemindAt))
		if err != nil {
			api.RespondError(w, &api.ValidationError{Field: "remind_at", Message: "invalid RFC3339 timestamp"})
			return
		}
		parsed = parsed.UTC()
		remindAt = &parsed
	}

	post, err := h.service.CreatePost(r.Context(), user, req.GroupID, req.Content, remindAt)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, post)
}

func (h *PinwallHandler) ListPosts(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
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

	limit, offset := parsePagination(r)
	posts, err := h.service.ListPosts(r.Context(), user, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, posts)
}

func (h *PinwallHandler) DeletePost(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
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

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if err := h.service.DeletePost(r.Context(), user, groupID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type updatePinwallPostRequest struct {
	GroupID uuid.UUID `json:"group_id"`
	// Nil fields are left unchanged; an empty-string color/size clears the
	// choice back to the client default.
	Content *string `json:"content,omitempty"`
	Color   *string `json:"color,omitempty"`
	Size    *string `json:"size,omitempty"`
}

func (h *PinwallHandler) UpdatePost(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req updatePinwallPostRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	if req.GroupID == uuid.Nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	post, err := h.service.UpdatePost(r.Context(), user, req.GroupID, id, req.Content, req.Color, req.Size)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, post)
}

type updatePinwallPositionRequest struct {
	GroupID uuid.UUID `json:"group_id"`
	X       float64   `json:"x"`
	Y       float64   `json:"y"`
}

func (h *PinwallHandler) UpdatePostPosition(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req updatePinwallPositionRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	if req.GroupID == uuid.Nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	post, err := h.service.UpdatePostPosition(r.Context(), user, req.GroupID, id, req.X, req.Y)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, post)
}
