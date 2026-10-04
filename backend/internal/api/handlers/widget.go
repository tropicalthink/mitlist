package handlers

import (
	"context"
	"encoding/hex"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/services"
)

// WidgetHandler serves the data behind the app's home screen widgets. Widgets
// call it with their device credential; the app may call it with a session.
type WidgetHandler struct {
	service *services.WidgetService
	devices widgetPushTokens
}

type widgetPushTokens interface {
	SetPushToken(ctx context.Context, credentialID uuid.UUID, token string) (bool, error)
}

func NewWidgetHandler(service *services.WidgetService, devices widgetPushTokens) *WidgetHandler {
	return &WidgetHandler{service: service, devices: devices}
}

func (h *WidgetHandler) RegisterRoutes(r chi.Router) {
	r.Get("/widget/snapshot", h.GetSnapshot)
	r.Put("/widget/push-token", h.SetPushToken)
}

func (h *WidgetHandler) GetSnapshot(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	// A credential only sees the households it was issued for, even if the
	// person has joined more since.
	var allowedGroups []uuid.UUID
	if identity, integration := middleware.IntegrationCredentialFromContext(r.Context()); integration {
		allowedGroups = append([]uuid.UUID{}, identity.GroupIDs...)
	}
	snapshot, err := h.service.GetSnapshot(r.Context(), user, allowedGroups)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, snapshot)
}

// SetPushToken stores the WidgetKit push token of the calling widget
// extension (iOS 26+, plans/047 contract C6) on its device's widget
// credential. Only a widget credential can call it: the token belongs to
// that device's widgets, not to a session.
func (h *WidgetHandler) SetPushToken(w http.ResponseWriter, r *http.Request) {
	identity, integration := middleware.IntegrationCredentialFromContext(r.Context())
	if !integration || identity.Kind != services.CredentialKindWidget {
		api.RespondError(w, &api.PermissionDeniedError{Message: "only a widget credential can register a widget push token"})
		return
	}
	var req struct {
		Token string `json:"token"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	token := strings.ToLower(strings.TrimSpace(req.Token))
	if _, err := hex.DecodeString(token); err != nil || len(token) < 32 || len(token) > 200 {
		api.RespondError(w, &api.ValidationError{Field: "token", Message: "must be a hex APNs device token"})
		return
	}
	stored, err := h.devices.SetPushToken(r.Context(), identity.CredentialID, token)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if !stored {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
