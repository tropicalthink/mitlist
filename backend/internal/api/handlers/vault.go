package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// VaultHandler exposes vault endpoints.
type VaultHandler struct {
	service *services.VaultService
}

// NewVaultHandler creates a new VaultHandler.
func NewVaultHandler(service *services.VaultService) *VaultHandler {
	return &VaultHandler{service: service}
}

func (h *VaultHandler) RegisterRoutes(r chi.Router) {
	r.Post("/vault", h.CreateVaultItem)
	r.Get("/vault", h.ListVaultItems)
	r.Get("/vault/{id}", h.GetVaultItem)
	r.Patch("/vault/{id}", h.UpdateVaultItem)
	r.Delete("/vault/{id}", h.DeleteVaultItem)
	r.Post("/vault/{id}/share", h.ShareVaultItem)
	r.Delete("/vault/{id}/share/{share_id}", h.RevokeShare)
}

type createVaultItemRequest struct {
	GroupID      uuid.UUID  `json:"group_id"`
	Type         string     `json:"type"`
	Title        string     `json:"title"`
	Content      string     `json:"content"`
	ReminderDate *time.Time `json:"reminder_date,omitempty"`
}

func (h *VaultHandler) CreateVaultItem(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	var req createVaultItemRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	item := &models.VaultItem{
		GroupID:      req.GroupID,
		Type:         req.Type,
		Title:        req.Title,
		Content:      req.Content,
		ReminderDate: req.ReminderDate,
	}

	if err := h.service.CreateVaultItem(r.Context(), userID, item); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, item)
}

func (h *VaultHandler) ListVaultItems(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		respondError(w, api.ErrValidation)
		return
	}
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		respondError(w, api.ErrValidation)
		return
	}

	limit, offset := parsePagination(r)
	items, err := h.service.ListVaultItems(r.Context(), userID, groupID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, items)
}

func (h *VaultHandler) GetVaultItem(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	item, err := h.service.GetVaultItem(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, item)
}

type updateVaultItemRequest struct {
	Title        *string    `json:"title,omitempty"`
	Content      *string   `json:"content,omitempty"`
	Type         *string   `json:"type,omitempty"`
	ReminderDate *time.Time `json:"reminder_date,omitempty"`
}

func (h *VaultHandler) UpdateVaultItem(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateVaultItemRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetVaultItem(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.Title != nil {
		existing.Title = *req.Title
	}
	if req.Content != nil {
		existing.Content = *req.Content
	}
	if req.Type != nil {
		existing.Type = *req.Type
	}
	if req.ReminderDate != nil {
		existing.ReminderDate = req.ReminderDate
	}

	if err := h.service.UpdateVaultItem(r.Context(), userID, existing); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, existing)
}

func (h *VaultHandler) DeleteVaultItem(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteVaultItem(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type shareVaultItemRequest struct {
	SharedWithUserID uuid.UUID `json:"shared_with_user_id"`
	Permission       string    `json:"permission"`
}

func (h *VaultHandler) ShareVaultItem(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req shareVaultItemRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	share, err := h.service.ShareVaultItem(r.Context(), userID, id, req.SharedWithUserID, req.Permission)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, share)
}

func (h *VaultHandler) RevokeShare(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	vaultItemID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	shareID, err := parseUUIDParam(r, "share_id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.RevokeShare(r.Context(), userID, vaultItemID, shareID); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
