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
	"github.com/mitlist-app/mitlist/internal/models"
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
	oauthPKCECookieName     = "oauth_pkce_verifier"
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

// GetProviders reports which OAuth providers the server is configured for,
// so clients can hide sign-in buttons that would dead-end.
func (h *OAuthHandler) GetProviders(w http.ResponseWriter, r *http.Request) {
	api.RespondJSON(w, http.StatusOK, map[string]bool{
		"google": h.googleClient.Configured(),
		"apple":  h.appleClient.Configured(),
	})
}

// GetGoogle initiates Google OAuth by redirecting to the provider.
func (h *OAuthHandler) GetGoogle(w http.ResponseWriter, r *http.Request) {
	redirectURI := r.URL.Query().Get("redirect_uri")
	if redirectURI == "" {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}
	if !h.googleClient.AllowRedirect(redirectURI) {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	state, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	verifier, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	authURL := h.googleClient.AuthURL(state, verifier)

	h.setOAuthCookie(w, oauthStateCookieName, state, 600, r)
	h.setOAuthCookie(w, oauthRedirectCookieName, base64.URLEncoding.EncodeToString([]byte(redirectURI)), 600, r)
	h.setOAuthCookie(w, oauthPKCECookieName, verifier, 600, r)
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
	secure := h.cookieSecure(r)
	// The Apple provider callback arrives as a cross-site POST navigation
	// (response_mode=form_post); SameSite=Lax cookies are NOT sent on cross-site
	// POSTs, so the state/redirect cookies would be missing and login would fail.
	// SameSite=None fixes that, but browsers only accept None with Secure — fall
	// back to Lax when the connection isn't secure (local http dev, where the
	// external OAuth providers aren't used anyway).
	sameSite := http.SameSiteLaxMode
	if secure {
		sameSite = http.SameSiteNoneMode
	}
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    value,
		Path:     "/",
		HttpOnly: true,
		Secure:   secure,
		SameSite: sameSite,
		MaxAge:   maxAge,
	})
}

func (h *OAuthHandler) cookieSecure(r *http.Request) bool {
	if r.TLS != nil {
		return true
	}
	return strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https")
}

// isFormPost reports whether the request is a form-encoded POST, i.e. Apple's
// response_mode=form_post callback rather than a native/SPA JSON POST.
func isFormPost(r *http.Request) bool {
	if r.Method != http.MethodPost {
		return false
	}
	ct := r.Header.Get("Content-Type")
	return strings.HasPrefix(ct, "application/x-www-form-urlencoded") ||
		strings.HasPrefix(ct, "multipart/form-data")
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
		h.clearOAuthCookie(w, oauthPKCECookieName, r)
		api.RespondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	h.clearOAuthCookie(w, oauthStateCookieName, r)
	verifier, err := h.pkceVerifier(r)
	h.clearOAuthCookie(w, oauthPKCECookieName, r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	user, access, refresh, err := h.service.GoogleLogin(r.Context(), req.Code, req.RedirectURI, verifier)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

// GetGoogleCallback handles a provider redirect, completes login server-side,
// and redirects back to the client callback URL with issued tokens.
func (h *OAuthHandler) GetGoogleCallback(w http.ResponseWriter, r *http.Request) {
	h.completeRedirectFlow(w, r, "google", func() (*servicesOAuthResult, error) {
		verifier, verifierErr := h.pkceVerifier(r)
		if verifierErr != nil {
			return nil, verifierErr
		}
		user, err := h.service.GoogleIdentity(r.Context(), r.URL.Query().Get("code"), "", verifier)
		if err != nil {
			return nil, err
		}
		return &servicesOAuthResult{user: user}, nil
	})
}

// GetApple initiates Apple OAuth by redirecting to the provider.
func (h *OAuthHandler) GetApple(w http.ResponseWriter, r *http.Request) {
	redirectURI := r.URL.Query().Get("redirect_uri")
	if redirectURI == "" {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect_uri is required"})
		return
	}
	if !h.appleClient.AllowRedirect(redirectURI) {
		api.RespondError(w, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"})
		return
	}

	state, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	verifier, err := generateState()
	if err != nil {
		api.RespondError(w, err)
		return
	}
	authURL := h.appleClient.AuthURL(state, verifier)

	h.setOAuthCookie(w, oauthStateCookieName, state, 600, r)
	h.setOAuthCookie(w, oauthRedirectCookieName, base64.URLEncoding.EncodeToString([]byte(redirectURI)), 600, r)
	h.setOAuthCookie(w, oauthPKCECookieName, verifier, 600, r)
	http.Redirect(w, r, authURL, http.StatusFound)
}

// PostAppleCallback handles the Apple OAuth callback.
//
// Apple's web sign-in uses response_mode=form_post (required when name/email
// scopes are requested), so it delivers the callback as a form-encoded, cross-
// site POST navigation. Those go through the server-side redirect flow, exactly
// like the GET callback. Native/SPA clients instead POST JSON and receive the
// token pair in the response body.
func (h *OAuthHandler) PostAppleCallback(w http.ResponseWriter, r *http.Request) {
	if isFormPost(r) {
		h.completeRedirectFlow(w, r, "apple", func() (*servicesOAuthResult, error) {
			verifier, verifierErr := h.pkceVerifier(r)
			if verifierErr != nil {
				return nil, verifierErr
			}
			user, err := h.service.AppleIdentity(
				r.Context(),
				r.FormValue("code"),
				"",
				r.FormValue("id_token"),
				verifier,
			)
			if err != nil {
				return nil, err
			}
			return &servicesOAuthResult{user: user}, nil
		})
		return
	}

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
		h.clearOAuthCookie(w, oauthPKCECookieName, r)
		api.RespondError(w, &api.ValidationError{Message: "invalid oauth state"})
		return
	}
	h.clearOAuthCookie(w, oauthStateCookieName, r)
	verifier, err := h.pkceVerifier(r)
	h.clearOAuthCookie(w, oauthPKCECookieName, r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	user, access, refresh, err := h.service.AppleLogin(r.Context(), req.Code, req.RedirectURI, req.IDToken, verifier)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

// GetAppleCallback handles a provider redirect, completes login server-side,
// and redirects back to the client callback URL with issued tokens.
func (h *OAuthHandler) GetAppleCallback(w http.ResponseWriter, r *http.Request) {
	h.completeRedirectFlow(w, r, "apple", func() (*servicesOAuthResult, error) {
		verifier, verifierErr := h.pkceVerifier(r)
		if verifierErr != nil {
			return nil, verifierErr
		}
		user, err := h.service.AppleIdentity(
			r.Context(),
			r.URL.Query().Get("code"),
			"",
			r.URL.Query().Get("id_token"),
			verifier,
		)
		if err != nil {
			return nil, err
		}
		return &servicesOAuthResult{user: user}, nil
	})
}

func (h *OAuthHandler) pkceVerifier(r *http.Request) (string, error) {
	cookie, err := r.Cookie(oauthPKCECookieName)
	if err != nil || cookie.Value == "" {
		return "", &api.ValidationError{Message: "missing oauth PKCE verifier"}
	}
	return cookie.Value, nil
}

type servicesOAuthResult struct {
	user *models.User
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
		h.clearOAuthCookie(w, oauthPKCECookieName, r)
		api.RespondError(w, err)
		return
	}

	requestState := r.FormValue("state")
	cookie, err := r.Cookie(oauthStateCookieName)
	if err != nil || cookie.Value == "" || cookie.Value != requestState {
		h.clearOAuthCookie(w, oauthStateCookieName, r)
		h.clearOAuthCookie(w, oauthRedirectCookieName, r)
		h.clearOAuthCookie(w, oauthPKCECookieName, r)
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, "invalid oauth state"), http.StatusFound)
		return
	}

	h.clearOAuthCookie(w, oauthStateCookieName, r)
	h.clearOAuthCookie(w, oauthRedirectCookieName, r)
	h.clearOAuthCookie(w, oauthPKCECookieName, r)

	if providerError := r.FormValue("error"); providerError != "" {
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, providerError), http.StatusFound)
		return
	}

	result, err := login()
	if err != nil {
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, err.Error()), http.StatusFound)
		return
	}

	handoff, err := h.service.CreateHandoff(r.Context(), result.user.ID)
	if err != nil {
		http.Redirect(w, r, h.redirectWithError(finalRedirectURI, provider, "oauth handoff failed"), http.StatusFound)
		return
	}
	http.Redirect(
		w,
		r,
		h.redirectWithHandoff(finalRedirectURI, provider, handoff),
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

func (h *OAuthHandler) redirectWithHandoff(finalRedirectURI, provider, handoff string) string {
	redirectURL, err := url.Parse(finalRedirectURI)
	if err != nil {
		return finalRedirectURI
	}
	tokens := url.Values{}
	tokens.Set("provider", provider)
	tokens.Set("handoff", handoff)
	redirectURL.RawQuery = ""
	redirectURL.Fragment = ""
	// Custom-scheme deep links (mitlist://) must use the query string: mobile
	// OS handlers and Flutter's router read queryParameters, not fragments.
	if redirectURL.Scheme == "mitlist" || strings.Contains(finalRedirectURI, "#") {
		redirectURL.RawQuery = tokens.Encode()
	} else {
		redirectURL.Fragment = tokens.Encode()
	}
	return redirectURL.String()
}

func (h *OAuthHandler) ExchangeHandoff(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code string `json:"code"`
	}
	if err := decodeJSON(r, &req); err != nil || req.Code == "" {
		api.RespondError(w, &api.ValidationError{Field: "code", Message: "handoff code is required"})
		return
	}
	user, access, refresh, err := h.service.ExchangeHandoff(r.Context(), req.Code)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, user, access, refresh)
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
