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
	r.Post("/widget-credential", h.IssueWidget)
	r.Delete("/widget-credential", h.RevokeWidget)
}

type issueWidgetCredentialRequest struct {
	DeviceID string `json:"device_id"`
}

// IssueWidget gives this device's home screen widgets a fresh credential and
// revokes the one they had. The app calls it while it is signed in and in the
// foreground; the token is returned once.
func (h *IntegrationCredentialHandler) IssueWidget(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req issueWidgetCredentialRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	credential, token, err := h.service.IssueWidgetCredential(r.Context(), user.ID, req.DeviceID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, createIntegrationCredentialResponse{IntegrationCredential: credential, Token: token})
}

// RevokeWidget ends this device's widget credential, e.g. on sign-out. It
// succeeds whether or not the device had one.
func (h *IntegrationCredentialHandler) RevokeWidget(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	if err := h.service.RevokeWidgetCredential(r.Context(), user.ID, r.URL.Query().Get("device_id")); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
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
