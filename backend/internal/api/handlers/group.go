package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// GroupHandler handles group-related HTTP endpoints.
type GroupHandler struct {
	service *services.GroupService
}

// NewGroupHandler creates a new GroupHandler.
func NewGroupHandler(service *services.GroupService) *GroupHandler {
	return &GroupHandler{service: service}
}

// RegisterRoutes mounts all group routes.
func (h *GroupHandler) RegisterRoutes(r chi.Router) {
	r.Post("/groups", h.CreateGroup)
	r.Get("/groups", h.ListGroups)
	r.Get("/groups/{id}", h.GetGroup)
	r.Patch("/groups/{id}", h.UpdateGroup)
	r.Delete("/groups/{id}", h.DeleteGroup)
	r.Get("/groups/{id}/members", h.ListMembers)
	r.Post("/groups/{id}/members", h.InviteMember)
	r.Post("/groups/join", h.JoinGroup)
	r.Delete("/groups/{id}/members/{user_id}", h.RemoveMember)
	r.Patch("/groups/{id}/members/{user_id}", h.UpdateMemberRole)
	r.Get("/groups/{id}/pending-claims", h.GetPendingClaims)
	r.Post("/groups/{id}/pending-claims/{claim_id}/approve", h.ApproveClaim)
	r.Post("/groups/{id}/pending-claims/{claim_id}/reject", h.RejectClaim)
}

// CreateGroup handles POST /api/v1/groups.
func (h *GroupHandler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req services.CreateGroupInput
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	group, err := h.service.CreateGroup(r.Context(), user.ID, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, group)
}

// ListGroups handles GET /api/v1/groups.
func (h *GroupHandler) ListGroups(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	limit, offset := parsePagination(r)
	groups, err := h.service.ListGroups(r.Context(), user.ID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, groups)
}

// GetGroup handles GET /api/v1/groups/{id}.
func (h *GroupHandler) GetGroup(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	group, err := h.service.GetGroup(r.Context(), user.ID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, group)
}

// UpdateGroup handles PATCH /api/v1/groups/{id}.
func (h *GroupHandler) UpdateGroup(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req services.UpdateGroupInput
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	group, err := h.service.UpdateGroup(r.Context(), user.ID, id, req)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, group)
}

// DeleteGroup handles DELETE /api/v1/groups/{id}.
func (h *GroupHandler) DeleteGroup(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	if err := h.service.DeleteGroup(r.Context(), user.ID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// InviteMember handles POST /api/v1/groups/{id}/members.
func (h *GroupHandler) InviteMember(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Role string `json:"role"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	invite, err := h.service.InviteMember(r.Context(), user.ID, id, req.Role)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, invite)
}

// ListMembers handles GET /api/v1/groups/{id}/members.
func (h *GroupHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	members, err := h.service.ListMemberProfiles(r.Context(), user.ID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, members)
}

// JoinGroup handles POST /api/v1/groups/join.
func (h *GroupHandler) JoinGroup(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		Code string `json:"code"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	group, err := h.service.JoinGroup(r.Context(), user.ID, req.Code)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, group)
}

// RemoveMember handles DELETE /api/v1/groups/{id}/members/{user_id}.
func (h *GroupHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	targetUserID, err := uuid.Parse(chi.URLParam(r, "user_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "user_id", Message: "invalid UUID"})
		return
	}

	if err := h.service.RemoveMember(r.Context(), user.ID, groupID, targetUserID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// UpdateMemberRole handles PATCH /api/v1/groups/{id}/members/{user_id}.
func (h *GroupHandler) UpdateMemberRole(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	targetUserID, err := uuid.Parse(chi.URLParam(r, "user_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "user_id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Role string `json:"role"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.UpdateMemberRole(r.Context(), user.ID, groupID, targetUserID, req.Role); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetPendingClaims handles GET /api/v1/groups/{id}/pending-claims.
func (h *GroupHandler) GetPendingClaims(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	claims, err := h.service.GetPendingClaims(r.Context(), user.ID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, claims)
}

// ApproveClaim handles POST /api/v1/groups/{id}/pending-claims/{claim_id}/approve.
func (h *GroupHandler) ApproveClaim(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	claimID, err := uuid.Parse(chi.URLParam(r, "claim_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "claim_id", Message: "invalid UUID"})
		return
	}

	if err := h.service.ApproveClaim(r.Context(), user.ID, groupID, claimID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// RejectClaim handles POST /api/v1/groups/{id}/pending-claims/{claim_id}/reject.
func (h *GroupHandler) RejectClaim(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	claimID, err := uuid.Parse(chi.URLParam(r, "claim_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "claim_id", Message: "invalid UUID"})
		return
	}

	if err := h.service.RejectClaim(r.Context(), user.ID, groupID, claimID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
