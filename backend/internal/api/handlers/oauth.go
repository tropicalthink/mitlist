package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/services"
	oauthclient "github.com/mitlist-app/mitlist/internal/services/oauth"
)

// OAuthHandler handles OAuth initiation and callback endpoints.
type OAuthHandler struct {
	service      *services.OAuthService
	googleClient *oauthclient.GoogleClient
	appleClient  *oauthclient.AppleClient
	frontendURL  string
}

const (
	oauthStateCookieName    = "oauth_state"
	oauthRedirectCookieName = "oauth_redirect_uri"
)

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
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}
	if h.googleClient.GetAuthURL("state", redirectURI) == "" {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	state, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	authURL := h.googleClient.GetAuthURL(state, h.googleClient.RedirectURI())

	h.setOAuthCookie(w, oauthStateCookieName, state, 600, r)
	h.setOAuthCookie(w, oauthRedirectCookieName, base64.URLEncoding.EncodeToString([]byte(redirectURI)), 600, r)
	http.Redirect(w, r, authURL, http.StatusFound)
}

func clearOAuthStateCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     oauthStateCookieName,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}

func (h *OAuthHandler) clearOAuthCookie(w http.ResponseWriter, name string, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   h.cookieSecure(r),
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}

func (h *OAuthHandler) setOAuthCookie(w http.ResponseWriter, name, value string, maxAge int, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    value,
		Path:     "/",
		HttpOnly: true,
		Secure:   h.cookieSecure(r),
		SameSite: http.SameSiteLaxMode,
		MaxAge:   maxAge,
	})
}

func (h *OAuthHandler) cookieSecure(r *http.Request) bool {
	if r.TLS != nil {
		return true
	}
	return strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https")
}

// PostGoogleCallback handles the Google OAuth callback.
func (h *OAuthHandler) PostGoogleCallback(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code        string `json:"code"`
		RedirectURI string `json:"redirect_uri"`
		State       string `json:"state"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	cookie, err := r.Cookie(oauthStateCookieName)
	if err != nil || cookie.Value == "" || cookie.Value != req.State {
		h.clearOAuthCookie(w, oauthStateCookieName, r)
		api.RespondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	h.clearOAuthCookie(w, oauthStateCookieName, r)

	user, access, refresh, err := h.service.GoogleLogin(r.Context(), req.Code, req.RedirectURI)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{
		"user":          user,
		"access_token":  access,
		"refresh_token": refresh,
	})
}

// GetGoogleCallback handles a provider redirect, completes login server-side,
// and redirects back to the client callback URL with issued tokens.
func (h *OAuthHandler) GetGoogleCallback(w http.ResponseWriter, r *http.Request) {
	h.completeRedirectFlow(w, r, "google", func() (*servicesOAuthResult, error) {
		user, access, refresh, err := h.service.GoogleLogin(r.Context(), r.URL.Query().Get("code"), "")
		if err != nil {
			return nil, err
		}
		return &servicesOAuthResult{user: user, access: access, refresh: refresh}, nil
	})
}

// GetApple initiates Apple OAuth by redirecting to the provider.
func (h *OAuthHandler) GetApple(w http.ResponseWriter, r *http.Request) {
	redirectURI := r.URL.Query().Get("redirect_uri")
	if redirectURI == "" {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}
	if h.appleClient.GetAuthURL("state", redirectURI) == "" {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	state, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	authURL := h.appleClient.GetAuthURL(state, h.appleClient.RedirectURI())

	h.setOAuthCookie(w, oauthStateCookieName, state, 600, r)
	h.setOAuthCookie(w, oauthRedirectCookieName, base64.URLEncoding.EncodeToString([]byte(redirectURI)), 600, r)
	http.Redirect(w, r, authURL, http.StatusFound)
}

// PostAppleCallback handles the Apple OAuth callback.
func (h *OAuthHandler) PostAppleCallback(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code        string `json:"code"`
		RedirectURI string `json:"redirect_uri"`
		IDToken     string `json:"id_token"`
		State       string `json:"state"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	cookie, err := r.Cookie(oauthStateCookieName)
	if err != nil || cookie.Value == "" || cookie.Value != req.State {
		h.clearOAuthCookie(w, oauthStateCookieName, r)
		api.RespondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	h.clearOAuthCookie(w, oauthStateCookieName, r)

	user, access, refresh, err := h.service.AppleLogin(r.Context(), req.Code, req.RedirectURI, req.IDToken)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{
		"user":          user,
		"access_token":  access,
		"refresh_token": refresh,
	})
}

// GetAppleCallback handles a provider redirect, completes login server-side,
// and redirects back to the client callback URL with issued tokens.
func (h *OAuthHandler) GetAppleCallback(w http.ResponseWriter, r *http.Request) {
	h.completeRedirectFlow(w, r, "apple", func() (*servicesOAuthResult, error) {
		user, access, refresh, err := h.service.AppleLogin(
			r.Context(),
			r.URL.Query().Get("code"),
			"",
			r.URL.Query().Get("id_token"),
		)
		if err != nil {
			return nil, err
		}
		return &servicesOAuthResult{user: user, access: access, refresh: refresh}, nil
	})
}

type servicesOAuthResult struct {
	user    any
	access  string
	refresh string
}

func (h *OAuthHandler) completeRedirectFlow(
	w http.ResponseWriter,
	r *http.Request,
	provider string,
	login func() (*servicesOAuthResult, error),
) {
	finalRedirectURI, err := h.finalRedirectURI(r)
	if err != nil {
		h.clearOAuthCookie(w, oauthStateCookieName, r)
		h.clearOAuthCookie(w, oauthRedirectCookieName, r)
		api.RespondError(w, err)
		return
	}

	requestState := r.URL.Query().Get("state")
	cookie, err := r.Cookie(oauthStateCookieName)
	if err != nil || cookie.Value == "" || cookie.Value != requestState {
		h.clearOAuthCookie(w, oauthStateCookieName, r)
		h.clearOAuthCookie(w, oauthRedirectCookieName, r)
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, "invalid oauth state"), http.StatusFound)
		return
	}

	h.clearOAuthCookie(w, oauthStateCookieName, r)
	h.clearOAuthCookie(w, oauthRedirectCookieName, r)

	if providerError := r.URL.Query().Get("error"); providerError != "" {
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, providerError), http.StatusFound)
		return
	}

	result, err := login()
	if err != nil {
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, err.Error()), http.StatusFound)
		return
	}

	http.Redirect(
		w,
		r,
		h.redirectWithTokens(finalRedirectURI, provider, result.access, result.refresh),
		http.StatusFound,
	)
}

func (h *OAuthHandler) finalRedirectURI(r *http.Request) (string, error) {
	cookie, err := r.Cookie(oauthRedirectCookieName)
	if err != nil || cookie.Value == "" {
		return "", &api.ValidationError{Field: "redirect_uri", Message: "missing redirect URI"}
	}

	raw, err := base64.URLEncoding.DecodeString(cookie.Value)
	if err != nil {
		return "", &api.ValidationError{Field: "redirect_uri", Message: "invalid redirect URI"}
	}
	return string(raw), nil
}

func (h *OAuthHandler) redirectWithTokens(finalRedirectURI, provider, access, refresh string) string {
	redirectURL, err := url.Parse(finalRedirectURI)
	if err != nil {
		return finalRedirectURI
	}
	fragment := url.Values{}
	fragment.Set("provider", provider)
	fragment.Set("access_token", access)
	fragment.Set("refresh_token", refresh)
	redirectURL.RawQuery = ""
	redirectURL.Fragment = ""
	if strings.Contains(finalRedirectURI, "#") {
		redirectURL.RawQuery = fragment.Encode()
	} else {
		redirectURL.Fragment = fragment.Encode()
	}
	return redirectURL.String()
}

func (h *OAuthHandler) redirectWithError(finalRedirectURI, provider, message string) string {
	redirectURL, err := url.Parse(finalRedirectURI)
	if err != nil {
		return finalRedirectURI
	}
	query := redirectURL.Query()
	query.Set("provider", provider)
	query.Set("error", message)
	redirectURL.RawQuery = query.Encode()
	redirectURL.Fragment = ""
	return redirectURL.String()
}

func generateState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("crypto RNG: %w", err)
	}
	return base64.URLEncoding.EncodeToString(b), nil
}
