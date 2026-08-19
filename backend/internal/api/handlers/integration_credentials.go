package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// IntegrationCredentialHandler manages long-lived credentials. The routes are
// mounted beneath /auth and protected by the normal interactive-session auth
// middleware in AuthHandler.RegisterRoutes.
type IntegrationCredentialHandler struct {
	service *services.IntegrationCredentialService
}

func NewIntegrationCredentialHandler(service *services.IntegrationCredentialService) *IntegrationCredentialHandler {
	return &IntegrationCredentialHandler{service: service}
}

func (h *IntegrationCredentialHandler) RegisterRoutes(r chi.Router) {
	r.Get("/integration-credentials", h.List)
	r.Post("/integration-credentials", h.Create)
	r.Delete("/integration-credentials/{id}", h.Revoke)
}

type createIntegrationCredentialRequest struct {
	Name     string      `json:"name"`
	GroupIDs []uuid.UUID `json:"group_ids"`
	Scopes   []string    `json:"scopes"`
}

type createIntegrationCredentialResponse struct {
	*models.IntegrationCredential
	Token string `json:"token"`
}

func (h *IntegrationCredentialHandler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	credentials, err := h.service.List(r.Context(), user.ID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, credentials)
}

func (h *IntegrationCredentialHandler) Create(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req createIntegrationCredentialRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	credential, token, err := h.service.Create(r.Context(), user.ID, services.CreateIntegrationCredentialInput{
		Name: req.Name, GroupIDs: req.GroupIDs, Scopes: req.Scopes,
	})
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, createIntegrationCredentialResponse{IntegrationCredential: credential, Token: token})
}

func (h *IntegrationCredentialHandler) Revoke(w http.ResponseWriter, r *http.Request) {
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
	if err := h.service.Revoke(r.Context(), user.ID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
