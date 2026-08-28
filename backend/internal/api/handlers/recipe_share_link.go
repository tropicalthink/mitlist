package handlers

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
)

// shareLinkResponse carries the token plus the URL the client should hand to
// the OS share sheet. The server builds the URL so the link format lives in
// one place — it has to match the paths in the App Link filter and the
// apple-app-site-association file.
type shareLinkResponse struct {
	Token string `json:"token"`
	URL   string `json:"url"`
}

// ShareLinkBaseURL is the origin share links point at. It is the Flutter web
// app, which both serves the association files for native link capture and
// renders the recipe for a recipient who does not have the app.
var ShareLinkBaseURL = "https://app.mitlist.me"

func shareLinkURL(token string) string {
	return strings.TrimRight(ShareLinkBaseURL, "/") + "/r/" + token
}

// CreateShareLink issues (or returns the existing) share link for a recipe.
func (h *RecipeHandler) CreateShareLink(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	token, err := h.service.CreateShareLink(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, shareLinkResponse{Token: token, URL: shareLinkURL(token)})
}

// RevokeShareLink invalidates every link already handed out for a recipe.
func (h *RecipeHandler) RevokeShareLink(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if err := h.service.RevokeShareLink(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// GetSharedRecipe serves a shared recipe to an anonymous caller. Mounted
// OUTSIDE the authenticated route group: the token is the credential, and the
// whole point is that a recipient without the app can still see what was sent.
func (h *RecipeHandler) GetSharedRecipe(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(chi.URLParam(r, "token"))

	shared, err := h.service.GetSharedRecipe(r.Context(), token)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	// A capability URL must never be cached by a shared proxy.
	w.Header().Set("Cache-Control", "private, no-store")
	api.RespondJSON(w, http.StatusOK, shared)
}

type saveSharedRecipeRequest struct {
	// Visibility picks between "save to my recipes" (private, the default) and
	// "save to our household" (household + GroupID).
	Visibility string     `json:"visibility"`
	GroupID    *uuid.UUID `json:"group_id"`
}

// SaveSharedRecipe copies a shared recipe into the caller's own library.
func (h *RecipeHandler) SaveSharedRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	token := strings.TrimSpace(chi.URLParam(r, "token"))

	var req saveSharedRecipeRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	recipe, err := h.service.SaveSharedRecipe(r.Context(), userID, token, req.Visibility, req.GroupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusCreated, recipe)
}
