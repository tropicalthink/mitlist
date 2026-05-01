package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// ShareHandler exposes share-target endpoints.
type ShareHandler struct {
	service *services.ShareService
}

// NewShareHandler creates a new ShareHandler.
func NewShareHandler(service *services.ShareService) *ShareHandler {
	return &ShareHandler{service: service}
}

func (h *ShareHandler) Routes(r chi.Router) {
	r.Post("/share-target/lists", h.CreateListFromShare)
	r.Post("/share-target/recipes", h.CreateRecipeFromShare)
}

// ---------------------------------------------------------------------------
// Request / Response DTOs
// ---------------------------------------------------------------------------

type shareListRequest struct {
	GroupID string `json:"group_id"`
	Text    string `json:"text"`
}

type shareTargetRecipeRequest struct {
	Text string `json:"text"`
}

type shareListResponse struct {
	List  any   `json:"list"`
	Items []any `json:"items"`
}

// ---------------------------------------------------------------------------
// Share target handlers
// ---------------------------------------------------------------------------

func (h *ShareHandler) CreateListFromShare(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	var req shareListRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	groupID, err := uuid.Parse(req.GroupID)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	if req.Text == "" {
		respondError(w, &api.ValidationError{Field: "text", Message: "text is required"})
		return
	}

	list, items, err := h.service.CreateListFromShare(r.Context(), userID, groupID, req.Text)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, shareListResponse{
		List:  list,
		Items: toAnySlice(items),
	})
}

func (h *ShareHandler) CreateRecipeFromShare(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	var req shareTargetRecipeRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if req.Text == "" {
		respondError(w, &api.ValidationError{Field: "text", Message: "text is required"})
		return
	}

	recipe, err := h.service.CreateRecipeFromShare(r.Context(), userID, req.Text)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, recipe)
}

func toAnySlice[T any](items []T) []any {
	result := make([]any, len(items))
	for i, v := range items {
		result[i] = v
	}
	return result
}
