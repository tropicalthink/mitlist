package handlers

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
	appcheckservice "github.com/mitlist-app/mitlist/internal/services/appcheck"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	turnstileservice "github.com/mitlist-app/mitlist/internal/services/turnstile"
)

// AuthHandler exposes authentication and user management endpoints.
type AuthHandler struct {
	cfg               *config.Config
	userService       *services.UserService
	guestService      *services.GuestService
	oauthService      *services.OAuthService
	jwtService        *jwtservice.Service
	appCheck          *appcheckservice.Verifier
	turnstile         *turnstileservice.Verifier
	credentialService *services.IntegrationCredentialService
}

// NewAuthHandler creates an AuthHandler with explicit dependencies.
func NewAuthHandler(
	cfg *config.Config,
	userService *services.UserService,
	guestService *services.GuestService,
	oauthService *services.OAuthService,
	jwtService *jwtservice.Service,
	appCheck ...*appcheckservice.Verifier,
) *AuthHandler {
	var verifier *appcheckservice.Verifier
	if len(appCheck) > 0 {
		verifier = appCheck[0]
	}
	return &AuthHandler{
		cfg:          cfg,
		userService:  userService,
		guestService: guestService,
		oauthService: oauthService,
		jwtService:   jwtService,
		appCheck:     verifier,
	}
}

// SetIntegrationCredentialService enables management of non-interactive,
// scoped credentials without weakening the type-safe constructor used by
// tests and embedded servers.
func (h *AuthHandler) SetIntegrationCredentialService(service *services.IntegrationCredentialService) {
	h.credentialService = service
}

// SetTurnstileVerifier wires web attestation for guest creation. It is a
// setter rather than a constructor argument for the same reason as the
// credential service: the constructor is used by tests and embedded servers
// that have no business knowing about Cloudflare.
func (h *AuthHandler) SetTurnstileVerifier(verifier *turnstileservice.Verifier) {
	h.turnstile = verifier
}

// errPasswordAuthDisabled is the answer for every password route on a server
// that runs without PASSWORD_AUTH_ENABLED. A 403 with a stable message, not a
// 404: the route exists, this deployment has chosen not to offer it, and a
// client that skipped /oauth/providers should learn why rather than retry.
var errPasswordAuthDisabled = &api.PermissionDeniedError{
	Message: "email and password sign-in is disabled on this server",
}

// errGuestAuthDisabled is the answer for guest creation on a server that runs
// without GUEST_AUTH_ENABLED. Same shape as errPasswordAuthDisabled: a 403
// with a stable message, so a client that skipped /oauth/providers learns
// the door is closed rather than retrying.
var errGuestAuthDisabled = &api.PermissionDeniedError{
	Message: "guest accounts are disabled on this server",
}

// requireGuestAuth guards the creation of new guest accounts. Only creation:
// a guest who already exists must still be able to refresh, convert and
// link a provider, or turning the flag off would strand them.
func (h *AuthHandler) requireGuestAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if h.cfg == nil || !h.cfg.GuestAuthEnabled {
			api.RespondError(w, errGuestAuthDisabled)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// requirePasswordAuth guards every route that creates, checks or changes a
// password. Registration is included: an account registered here can only
// ever sign in with a password, so it is pointless where passwords are off.
func (h *AuthHandler) requirePasswordAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if h.cfg == nil || !h.cfg.PasswordAuthEnabled {
			api.RespondError(w, errPasswordAuthDisabled)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// RegisterRoutes mounts all auth routes under the provided router.
func (h *AuthHandler) RegisterRoutes(r chi.Router) {
	r.Route("/auth", func(r chi.Router) {
		r.Post("/token/refresh", h.Refresh)
		r.Post("/logout", h.Logout)
		r.With(h.requireGuestAuth).Post("/guest", h.CreateGuest)

		// Email + password (public), only where the operator turned it on.
		r.Group(func(r chi.Router) {
			r.Use(h.requirePasswordAuth)
			r.Post("/register", h.Register)
			r.Post("/verify-email", h.VerifyEmail)
			r.Post("/verify-email/resend", h.ResendEmailVerification)
			r.Post("/login", h.Login)
			r.Post("/password-reset", h.PasswordReset)
			r.Post("/password-reset/confirm", h.PasswordResetConfirm)
		})

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(h.jwtService, h.userService))
			r.Get("/me", h.GetMe)
			r.Patch("/me", h.UpdateMe)
			r.Delete("/me", h.DeleteMe)
			r.With(h.requirePasswordAuth).Post("/change-password", h.ChangePassword)
			r.With(h.requirePasswordAuth).Post("/guest/convert", h.ConvertGuest)
			r.With(h.requirePasswordAuth).Post("/claim-account", h.ClaimAccount)
			r.Post("/oauth-link", h.CreateOAuthLink)

			// Push subscriptions (web push)
			r.Post("/push-subscriptions", h.CreatePushSubscription)
			r.Get("/push-subscriptions", h.ListPushSubscriptions)
			r.Delete("/push-subscriptions/{id}", h.DeletePushSubscription)

			// Device tokens (FCM — mobile push)
			r.Post("/device-tokens", h.CreateDeviceToken)
			r.Delete("/device-tokens/{id}", h.DeleteDeviceToken)

			if h.credentialService != nil {
				credentialHandler := NewIntegrationCredentialHandler(h.credentialService)
				credentialHandler.RegisterRoutes(r)
			}
		})
	})
}

// ---------------------------------------------------------------------------
// Request / Response shapes
// ---------------------------------------------------------------------------

type registerReq struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token"`
}

type passwordResetReq struct {
	Email string `json:"email"`
}

type verifyEmailReq struct {
	Token string `json:"token"`
}

type resendVerificationReq struct {
	Email string `json:"email"`
}

type passwordResetConfirmReq struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

type updateMeReq struct {
	FirstName         *string `json:"first_name,omitempty"`
	LastName          *string `json:"last_name,omitempty"`
	AvatarURL         *string `json:"avatar_url,omitempty"`
	TipsEmailsEnabled *bool   `json:"tips_emails_enabled,omitempty"`
}

type changePasswordReq struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password"`
}

type convertGuestReq struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type claimAccountReq struct {
	Password  string `json:"password"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type tokenPairResp struct {
	User         *models.User `json:"user,omitempty"`
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token,omitempty"`
}

const refreshCookieName = "mitlist_refresh"

func isWebClient(r *http.Request) bool { return r.Header.Get("X-Mitlist-Client") == "web" }

func setBrowserRefreshCookie(w http.ResponseWriter, r *http.Request, refresh string) {
	if !isWebClient(r) {
		return
	}
	secure := r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https"
	sameSite := http.SameSiteLaxMode
	if secure {
		sameSite = http.SameSiteNoneMode
	}
	http.SetCookie(w, &http.Cookie{
		Name: refreshCookieName, Value: refresh, Path: "/", HttpOnly: true,
		Secure: secure, SameSite: sameSite,
	})
}

func clearBrowserRefreshCookie(w http.ResponseWriter, r *http.Request) {
	if !isWebClient(r) {
		return
	}
	secure := r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https"
	sameSite := http.SameSiteLaxMode
	if secure {
		sameSite = http.SameSiteNoneMode
	}
	http.SetCookie(w, &http.Cookie{
		Name: refreshCookieName, Value: "", Path: "/", HttpOnly: true,
		Secure: secure, SameSite: sameSite, MaxAge: -1,
	})
}

func refreshCredential(r *http.Request, bodyToken string) string {
	if bodyToken != "" {
		return bodyToken
	}
	if isWebClient(r) {
		cookie, err := r.Cookie(refreshCookieName)
		if err != nil {
			return ""
		}
		return cookie.Value
	}
	return ""
}

func tokenResponse(w http.ResponseWriter, r *http.Request, status int, user *models.User, access, refresh string) {
	setBrowserRefreshCookie(w, r, refresh)
	if isWebClient(r) {
		refresh = ""
	}
	api.RespondJSON(w, status, tokenPairResp{User: user, AccessToken: access, RefreshToken: refresh})
}

type pushSubscriptionReq struct {
	Endpoint string `json:"endpoint"`
	P256dh   string `json:"p256dh"`
	Auth     string `json:"auth"`
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func currentUserID(r *http.Request) (uuid.UUID, error) {
	idStr := middleware.UserIDFromContext(r.Context())
	if idStr == "" {
		return uuid.Nil, api.ErrUnauthorized
	}
	return uuid.Parse(idStr)
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	_, err := h.userService.Register(r.Context(), services.RegisterInput{
		Email:     req.Email,
		Password:  req.Password,
		FirstName: req.FirstName,
		LastName:  req.LastName,
	})
	if err != nil {
		// Do not turn registration into an account-enumeration oracle. The
		// address may already belong to an active account, a pending account,
		// or a deleted tombstone; callers receive the same acknowledgement.
		if errors.Is(err, api.ErrConflict) {
			// A previous provider failure may have left a legitimate pending
			// registration without its code. Retry delivery without exposing
			// whether the address exists or is already verified.
			if resendErr := h.userService.ResendEmailVerification(r.Context(), req.Email); resendErr != nil {
				api.RespondError(w, resendErr)
				return
			}
			api.RespondJSON(w, http.StatusAccepted, map[string]any{
				"verification_required": true,
				"message":               "if the address can be registered, a verification code has been sent",
			})
			return
		}
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusAccepted, map[string]any{
		"verification_required": true,
		"message":               "if the address can be registered, a verification code has been sent",
	})
}

func (h *AuthHandler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	user, err := h.userService.VerifyEmail(r.Context(), req.Token)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	access, refresh, err := h.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

func (h *AuthHandler) ResendEmailVerification(w http.ResponseWriter, r *http.Request) {
	var req resendVerificationReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	// Deliberately return the same response for every address.
	if err := h.userService.ResendEmailVerification(r.Context(), req.Email); err != nil {
		log.Error().Err(err).Msg("email verification resend failed")
	}
	api.RespondJSON(w, http.StatusOK, map[string]string{"message": "if the account is pending verification, a new code has been sent"})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	user, access, refresh, err := h.userService.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	credential := refreshCredential(r, req.RefreshToken)
	claims, err := h.jwtService.ValidateRefreshToken(credential)
	if err != nil {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	// A locked guest may return only by presenting a still-valid refresh
	// session. Normal inactive accounts are not reactivated here.
	if userID, parseErr := uuid.Parse(claims.Subject); parseErr == nil {
		if err := h.userService.ReactivateGuestForRefresh(r.Context(), userID); err != nil {
			api.RespondError(w, api.ErrUnauthorized)
			return
		}
	}
	access, refresh, err := h.jwtService.RotateRefreshToken(credential)
	if err != nil {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	tokenResponse(w, r, http.StatusOK, nil, access, refresh)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	// Revoke the refresh token first.
	claims, err := h.jwtService.ValidateRefreshToken(refreshCredential(r, req.RefreshToken))
	if err == nil {
		_ = h.jwtService.RevokeRefreshToken(claims.ID)
	}

	// Also revoke the access token if one is present in the request.
	if accessToken := middleware.ExtractToken(r); accessToken != "" {
		if accessClaims, err := h.jwtService.ParseAccessToken(accessToken); err == nil {
			_ = h.jwtService.RevokeAccessToken(accessClaims.ID)
		}
	}

	clearBrowserRefreshCookie(w, r)
	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) PasswordReset(w http.ResponseWriter, r *http.Request) {
	var req passwordResetReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	if err := h.userService.RequestPasswordReset(r.Context(), req.Email); err != nil {
		log.Error().Err(err).Msg("password reset delivery failed")
	}
	api.RespondJSON(w, http.StatusAccepted, map[string]string{"message": "if the email exists, a reset link has been sent"})
}

func (h *AuthHandler) PasswordResetConfirm(w http.ResponseWriter, r *http.Request) {
	var req passwordResetConfirmReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	user, err := h.userService.ConfirmPasswordReset(r.Context(), req.Token, req.NewPassword)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	// The emailed code proved the address; sign the person in rather than
	// sending them to type the password they just chose. The consume revoked
	// every older session, so this is the account's only live one.
	access, refresh, err := h.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

func (h *AuthHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	user, err := h.userService.GetMe(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, user)
}

func (h *AuthHandler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req updateMeReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	user, err := h.userService.UpdateMe(r.Context(), userID, services.UpdateMeInput{
		FirstName:         req.FirstName,
		LastName:          req.LastName,
		AvatarURL:         req.AvatarURL,
		TipsEmailsEnabled: req.TipsEmailsEnabled,
	})
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, user)
}

func (h *AuthHandler) DeleteMe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if err := h.userService.DeleteMe(r.Context(), userID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req changePasswordReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	if err := h.userService.ChangePassword(r.Context(), userID, req.OldPassword, req.NewPassword); err != nil {
		api.RespondError(w, err)
		return
	}
	access, refresh, err := h.jwtService.GenerateTokenPair(userID.String(), nil)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, nil, access, refresh)
}

func (h *AuthHandler) CreateGuest(w http.ResponseWriter, r *http.Request) {
	// Attestation is deliberately enforced at the guest boundary only, and the
	// proof depends on where the caller runs: mobile presents an App Check
	// token (Play Integrity / App Attest), web presents a Turnstile token,
	// because App Check's only web provider is reCAPTCHA Enterprise.
	//
	// Whichever proof is presented must verify. The last branch is the one
	// that matters: if App Check is enforced and the caller sends no proof at
	// all, that is a rejection, not an unattested guest — otherwise omitting a
	// header would be a bypass.
	installIdentity := ""
	appCheckToken := r.Header.Get("X-Firebase-AppCheck")
	appCheckOn := h.appCheck != nil && h.appCheck.Enabled()
	turnstileOn := h.turnstile != nil && h.turnstile.Enabled()

	switch {
	case appCheckOn && appCheckToken != "":
		claims, err := h.appCheck.Verify(r.Context(), appCheckToken)
		if err != nil {
			api.RespondError(w, api.ErrUnauthorized)
			return
		}
		installIdentity = claims.QuotaIdentity(r.Header.Get("X-Mitlist-Install-ID"))
	case turnstileOn:
		result, err := h.turnstile.Verify(
			r.Context(), r.Header.Get("X-Mitlist-Turnstile"), middleware.ExtractIP(r),
		)
		if err != nil {
			api.RespondError(w, api.ErrUnauthorized)
			return
		}
		installIdentity = result.QuotaIdentity(r.Header.Get("X-Mitlist-Install-ID"))
	case appCheckOn:
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	user, access, refresh, err := h.guestService.CreateGuestForIdentity(
		r.Context(), middleware.ExtractIP(r), installIdentity,
	)
	if err != nil {
		if errors.Is(err, services.ErrGuestCreationLimit) {
			w.Header().Set("Retry-After", "3600")
			api.RespondJSON(w, http.StatusTooManyRequests, map[string]string{
				"error": "guest creation limit reached; sign in or try again later",
			})
			return
		}
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusCreated, user, access, refresh)
}

func (h *AuthHandler) ConvertGuest(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req convertGuestReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	user, access, refresh, err := h.guestService.ConvertGuest(r.Context(), userID, req.Email, req.Password, req.FirstName, req.LastName)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

// CreateOAuthLink mints the one-time token a guest hands to GET /oauth/{provider}
// (as `link`) so that finishing the provider round-trip upgrades this guest
// rather than signing in someone new.
func (h *AuthHandler) CreateOAuthLink(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	user, err := h.userService.GetMe(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if !user.IsGuest {
		api.RespondError(w, &api.ValidationError{Field: "user", Message: "only a guest account can be linked to a provider"})
		return
	}
	token, err := h.oauthService.CreateLinkToken(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, map[string]any{"link_token": token, "expires_in": 600})
}

func (h *AuthHandler) ClaimAccount(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req claimAccountReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	user, err := h.userService.ClaimAccount(r.Context(), userID, services.ClaimAccountInput{
		Password:  req.Password,
		FirstName: req.FirstName,
		LastName:  req.LastName,
	})
	if err != nil {
		api.RespondError(w, err)
		return
	}
	access, refresh, err := h.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	tokenResponse(w, r, http.StatusOK, user, access, refresh)
}

// ---------------------------------------------------------------------------
// Push subscriptions (web push)
// ---------------------------------------------------------------------------

func (h *AuthHandler) CreatePushSubscription(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req pushSubscriptionReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	sub := &models.PushSubscription{
		UserID:   userID,
		Endpoint: req.Endpoint,
		P256dh:   req.P256dh,
		Auth:     req.Auth,
	}
	if err := h.userService.CreatePushSubscription(r.Context(), sub); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, sub)
}

func (h *AuthHandler) ListPushSubscriptions(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	subs, err := h.userService.ListPushSubscriptions(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, subs)
}

func (h *AuthHandler) DeletePushSubscription(w http.ResponseWriter, r *http.Request) {
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
	if err := h.userService.DeletePushSubscription(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// Device tokens (FCM — mobile push)
// ---------------------------------------------------------------------------

func (h *AuthHandler) CreateDeviceToken(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req struct {
		Platform string `json:"platform"`
		Token    string `json:"token"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	dt, err := h.userService.SaveDeviceToken(r.Context(), userID, req.Platform, req.Token)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, dt)
}

func (h *AuthHandler) DeleteDeviceToken(w http.ResponseWriter, r *http.Request) {
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
	if err := h.userService.DeleteDeviceToken(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
