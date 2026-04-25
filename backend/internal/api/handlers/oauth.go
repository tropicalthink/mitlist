package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/services"
	oauthclient "github.com/yourorg/mitlist/internal/services/oauth"
)

// OAuthHandler handles OAuth initiation and callback endpoints.
type OAuthHandler struct {
	service      *services.OAuthService
	googleClient *oauthclient.GoogleClient
	appleClient  *oauthclient.AppleClient
	frontendURL  string
}

// NewOAuthHandler creates a new OAuthHandler.
func NewOAuthHandler(cfg *config.Config, service *services.OAuthService) *OAuthHandler {
	return &OAuthHandler{
		service:      service,
		googleClient: oauthclient.NewGoogleClient(cfg),
		appleClient:  oauthclient.NewAppleClient(cfg),
		frontendURL:  cfg.FrontendURL,
	}
}

// GetGoogle initiates Google OAuth by redirecting to the provider.
func (h *OAuthHandler) GetGoogle(w http.ResponseWriter, r *http.Request) {
	redirectURI := r.URL.Query().Get("redirect_uri")
	if redirectURI == "" {
		respondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}

	state, err := generateState()
	if err != nil {
		respondError(w, err)
		return
	}
	url := h.googleClient.GetAuthURL(state, redirectURI)
	if url == "" {
		respondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "oauth_state",
		Value:    state,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   600,
	})
	http.Redirect(w, r, url, http.StatusFound)
}

func clearOAuthStateCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     "oauth_state",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}

// PostGoogleCallback handles the Google OAuth callback.
func (h *OAuthHandler) PostGoogleCallback(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code        string `json:"code"`
		RedirectURI string `json:"redirect_uri"`
		State       string `json:"state"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	cookie, err := r.Cookie("oauth_state")
	if err != nil || cookie.Value == "" || cookie.Value != req.State {
		clearOAuthStateCookie(w)
		respondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	clearOAuthStateCookie(w)

	user, access, refresh, err := h.service.GoogleLogin(r.Context(), req.Code, req.RedirectURI)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{
		"user":          user,
		"access_token":  access,
		"refresh_token": refresh,
	})
}

// GetApple initiates Apple OAuth by redirecting to the provider.
func (h *OAuthHandler) GetApple(w http.ResponseWriter, r *http.Request) {
	redirectURI := r.URL.Query().Get("redirect_uri")
	if redirectURI == "" {
		respondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}

	state, err := generateState()
	if err != nil {
		respondError(w, err)
		return
	}
	url := h.appleClient.GetAuthURL(state, redirectURI)
	if url == "" {
		respondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "oauth_state",
		Value:    state,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   600,
	})
	http.Redirect(w, r, url, http.StatusFound)
}

// PostAppleCallback handles the Apple OAuth callback.
func (h *OAuthHandler) PostAppleCallback(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code        string `json:"code"`
		RedirectURI string `json:"redirect_uri"`
		IDToken     string `json:"id_token"`
		State       string `json:"state"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	cookie, err := r.Cookie("oauth_state")
	if err != nil || cookie.Value == "" || cookie.Value != req.State {
		clearOAuthStateCookie(w)
		respondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	clearOAuthStateCookie(w)

	user, access, refresh, err := h.service.AppleLogin(r.Context(), req.Code, req.RedirectURI, req.IDToken)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{
		"user":          user,
		"access_token":  access,
		"refresh_token": refresh,
	})
}

func generateState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("crypto RNG: %w", err)
	}
	return base64.URLEncoding.EncodeToString(b), nil
}
