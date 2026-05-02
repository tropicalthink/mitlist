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
}

type createPinwallPostRequest struct {
	GroupID uuid.UUID `json:"group_id"`
	Content string    `json:"content"`
	RemindAt *string  `json:"remind_at,omitempty"`
}

func (h *PinwallHandler) CreatePost(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	var req createPinwallPostRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}
	req.Content = strings.TrimSpace(req.Content)

	var remindAt *time.Time
	if req.RemindAt != nil && strings.TrimSpace(*req.RemindAt) != "" {
		parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(*req.RemindAt))
		if err != nil {
			respondError(w, &api.ValidationError{Field: "remind_at", Message: "invalid RFC3339 timestamp"})
			return
		}
		parsed = parsed.UTC()
		remindAt = &parsed
	}

	post, err := h.service.CreatePost(r.Context(), user, req.GroupID, req.Content, remindAt)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, post)
}

func (h *PinwallHandler) ListPosts(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	limit, offset := parsePagination(r)
	posts, err := h.service.ListPosts(r.Context(), user, groupID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, posts)
}

func (h *PinwallHandler) DeletePost(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeletePost(r.Context(), user, groupID, id); err != nil {
		respondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

