package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/container"
	"github.com/yourorg/mitlist/internal/middleware"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
	jwtservice "github.com/yourorg/mitlist/internal/services/jwt"
)

// AuthHandler exposes authentication and user management endpoints.
type AuthHandler struct {
	cfg          *config.Config
	userService  *services.UserService
	guestService *services.GuestService
	oauthService *services.OAuthService
	jwtService   *jwtservice.Service
}

// NewAuthHandler creates an AuthHandler wired from the container.
func NewAuthHandler(cfg *config.Config, cnt *container.Container) *AuthHandler {
	return &AuthHandler{
		cfg:          cfg,
		userService:  cnt.UserService(),
		guestService: cnt.GuestService(),
		oauthService: cnt.OAuthService(),
		jwtService:   cnt.JWT(),
	}
}

// RegisterRoutes mounts all auth routes under the provided router.
func (h *AuthHandler) RegisterRoutes(r chi.Router) {
	r.Route("/auth", func(r chi.Router) {
		r.Post("/register", h.Register)
		r.Post("/login", h.Login)
		r.Post("/token/refresh", h.Refresh)
		r.Post("/logout", h.Logout)
		r.Post("/password-reset", h.PasswordReset)
		r.Post("/password-reset/confirm", h.PasswordResetConfirm)
		r.Post("/guest", h.CreateGuest)

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(h.jwtService, h.userService))
			r.Get("/me", h.GetMe)
			r.Patch("/me", h.UpdateMe)
			r.Delete("/me", h.DeleteMe)
			r.Post("/change-password", h.ChangePassword)
			r.Post("/guest/convert", h.ConvertGuest)
			r.Post("/claim-account", h.ClaimAccount)

			// Push subscriptions (web push)
			r.Post("/push-subscriptions", h.CreatePushSubscription)
			r.Get("/push-subscriptions", h.ListPushSubscriptions)
			r.Delete("/push-subscriptions/{id}", h.DeletePushSubscription)
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

type passwordResetConfirmReq struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

type updateMeReq struct {
	FirstName *string `json:"first_name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
	AvatarURL *string `json:"avatar_url,omitempty"`
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
	RefreshToken string       `json:"refresh_token"`
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
	user, err := h.userService.Register(r.Context(), services.RegisterInput{
		Email:     req.Email,
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
	respondJSON(w, http.StatusCreated, tokenPairResp{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
	})
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
	respondJSON(w, http.StatusOK, tokenPairResp{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
	})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	claims, err := h.jwtService.ValidateRefreshToken(req.RefreshToken)
	if err != nil {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	if err := h.jwtService.RevokeRefreshToken(claims.ID); err != nil {
		api.RespondError(w, err)
		return
	}
	access, refresh, err := h.jwtService.GenerateTokenPair(claims.Subject, nil)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, tokenPairResp{
		AccessToken:  access,
		RefreshToken: refresh,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	// Revoke the refresh token first.
	claims, err := h.jwtService.ValidateRefreshToken(req.RefreshToken)
	if err == nil {
		_ = h.jwtService.RevokeRefreshToken(claims.ID)
	}

	// Also revoke the access token if one is present in the request.
	if accessToken := middleware.ExtractToken(r); accessToken != "" {
		if accessClaims, err := h.jwtService.ParseAccessToken(accessToken); err == nil {
			_ = h.jwtService.RevokeAccessToken(accessClaims.ID)
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) PasswordReset(w http.ResponseWriter, r *http.Request) {
	var req passwordResetReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	_ = h.userService.RequestPasswordReset(r.Context(), req.Email)
	respondJSON(w, http.StatusAccepted, map[string]string{"message": "if the email exists, a reset link has been sent"})
}

func (h *AuthHandler) PasswordResetConfirm(w http.ResponseWriter, r *http.Request) {
	var req passwordResetConfirmReq
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	if err := h.userService.ConfirmPasswordReset(r.Context(), req.Token, req.NewPassword); err != nil {
		api.RespondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, map[string]string{"message": "password reset successful"})
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
	respondJSON(w, http.StatusOK, user)
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
		FirstName: req.FirstName,
		LastName:  req.LastName,
		AvatarURL: req.AvatarURL,
	})
	if err != nil {
		api.RespondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, user)
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
	respondJSON(w, http.StatusOK, map[string]string{"message": "password changed"})
}

func (h *AuthHandler) CreateGuest(w http.ResponseWriter, r *http.Request) {
	user, access, refresh, err := h.guestService.CreateGuest(r.Context())
	if err != nil {
		api.RespondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, tokenPairResp{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
	})
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
	respondJSON(w, http.StatusOK, tokenPairResp{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
	})
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
	respondJSON(w, http.StatusOK, tokenPairResp{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
	})
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
	respondJSON(w, http.StatusCreated, sub)
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
	respondJSON(w, http.StatusOK, subs)
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
