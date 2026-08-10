package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	oauthclient "github.com/mitlist-app/mitlist/internal/services/oauth"
	"github.com/mitlist-app/mitlist/pkg/validation"
)

// OAuthService handles OAuth login flows.
type OAuthService struct {
	userRepo     repositories.UserRepo
	authRepo     repositories.AuthRepo
	jwtService   JWTService
	googleClient *oauthclient.GoogleClient
	appleClient  *oauthclient.AppleClient
}

// NewOAuthService creates a new OAuthService.
func NewOAuthService(
	userRepo repositories.UserRepo,
	authRepo repositories.AuthRepo,
	jwtService JWTService,
	googleClient *oauthclient.GoogleClient,
	appleClient *oauthclient.AppleClient,
) *OAuthService {
	return &OAuthService{
		userRepo:     userRepo,
		authRepo:     authRepo,
		jwtService:   jwtService,
		googleClient: googleClient,
		appleClient:  appleClient,
	}
}

// GoogleLogin validates the redirect URI, exchanges the code, fetches user info,
// creates or links the user, and issues a token pair.
func (s *OAuthService) GoogleIdentity(ctx context.Context, code, redirectURI string, pkceVerifier ...string) (*models.User, error) {
	if redirectURI != "" {
		if !s.googleClient.AllowRedirect(redirectURI) {
			return nil, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"}
		}
	}

	token, err := s.googleClient.ExchangeCode(code, pkceVerifier...)
	if err != nil {
		return nil, fmt.Errorf("exchange code: %w", err)
	}

	googleUser, err := s.googleClient.GetUserInfo(token)
	if err != nil {
		return nil, fmt.Errorf("get user info: %w", err)
	}

	if !googleUser.VerifiedEmail {
		return nil, &api.ValidationError{Field: "email", Message: "provider email is not verified"}
	}
	return s.processOAuthUser(ctx, "google", googleUser.ID, googleUser.Email, googleUser.GivenName, googleUser.FamilyName, googleUser.Picture)
}

func (s *OAuthService) GoogleLogin(ctx context.Context, code, redirectURI string, pkceVerifier ...string) (*models.User, string, string, error) {
	user, err := s.GoogleIdentity(ctx, code, redirectURI, pkceVerifier...)
	if err != nil {
		return nil, "", "", err
	}
	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	return user, access, refresh, err
}

// AppleLogin validates the redirect URI, exchanges the code, validates the identity token,
// creates or links the user, and issues a token pair.
func (s *OAuthService) AppleIdentity(ctx context.Context, code, redirectURI, idToken string, pkceVerifier ...string) (*models.User, error) {
	if redirectURI != "" {
		if !s.appleClient.AllowRedirect(redirectURI) {
			return nil, &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"}
		}
	}

	token, err := s.appleClient.ExchangeCode(code, pkceVerifier...)
	if err != nil {
		return nil, fmt.Errorf("exchange code: %w", err)
	}

	if idToken == "" && token != nil {
		if rawIDToken, ok := token.Extra("id_token").(string); ok {
			idToken = rawIDToken
		}
	}
	if idToken == "" {
		return nil, &api.ValidationError{Field: "id_token", Message: "identity token is required"}
	}

	appleUser, err := s.appleClient.ValidateIdentityToken(idToken)
	if err != nil {
		return nil, fmt.Errorf("validate identity token: %w", err)
	}
	if !appleUser.EmailVerified {
		return nil, &api.ValidationError{Field: "email", Message: "provider email is not verified"}
	}
	return s.processOAuthUser(ctx, "apple", appleUser.ID, appleUser.Email, appleUser.GivenName, appleUser.FamilyName, "")
}

func (s *OAuthService) AppleLogin(ctx context.Context, code, redirectURI, idToken string, pkceVerifier ...string) (*models.User, string, string, error) {
	user, err := s.AppleIdentity(ctx, code, redirectURI, idToken, pkceVerifier...)
	if err != nil {
		return nil, "", "", err
	}
	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	return user, access, refresh, err
}

func (s *OAuthService) processOAuthUser(
	ctx context.Context,
	provider, providerUserID, email, firstName, lastName, avatarURL string,
) (*models.User, error) {
	// Try existing OAuth link.
	oauthAccount, err := s.authRepo.GetOAuthByProviderID(ctx, provider, providerUserID)
	if err == nil {
		user, err := s.userRepo.GetByID(ctx, oauthAccount.UserID)
		if err != nil {
			return nil, fmt.Errorf("get linked user: %w", err)
		}
		return user, nil
	}
	if !isNotFound(err) {
		return nil, fmt.Errorf("get oauth account: %w", err)
	}

	// Try to find user by email.
	var user *models.User
	createdUser := false
	if email != "" {
		email = validation.NormalizeEmail(email)
		user, err = s.userRepo.GetByEmail(ctx, email)
		if err != nil && !isNotFound(err) {
			return nil, fmt.Errorf("get user by email: %w", err)
		}
	}

	if user == nil {
		user = &models.User{
			ID:         uuid.New(),
			Email:      email,
			FirstName:  firstName,
			LastName:   lastName,
			IsActive:   true,
			IsVerified: true,
		}
		if avatarURL != "" {
			user.AvatarURL = &avatarURL
		}
		if err := s.userRepo.Create(ctx, user); err != nil {
			return nil, fmt.Errorf("create user: %w", err)
		}
		createdUser = true
	}

	// Link OAuth account.
	account := &models.OAuthAccount{
		UserID:         user.ID,
		Provider:       provider,
		ProviderUserID: providerUserID,
	}
	// Provider bearer tokens are intentionally not persisted. mitlist uses the
	// provider only to establish identity and has no post-login provider API use.
	if err := s.authRepo.CreateOAuthAccount(ctx, account); err != nil {
		if createdUser {
			_ = s.userRepo.SoftDelete(ctx, user.ID)
		}
		return nil, fmt.Errorf("link oauth account: %w", err)
	}
	return user, nil
}

func (s *OAuthService) CreateHandoff(ctx context.Context, userID uuid.UUID) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	code := base64.RawURLEncoding.EncodeToString(raw)
	digest := sha256.Sum256([]byte(code))
	if err := s.authRepo.CreateOAuthHandoff(ctx, hex.EncodeToString(digest[:]), userID, time.Now().UTC().Add(2*time.Minute)); err != nil {
		return "", err
	}
	return code, nil
}

func (s *OAuthService) ExchangeHandoff(ctx context.Context, code string) (*models.User, string, string, error) {
	digest := sha256.Sum256([]byte(code))
	userID, err := s.authRepo.ConsumeOAuthHandoff(ctx, hex.EncodeToString(digest[:]))
	if err != nil {
		return nil, "", "", &api.ValidationError{Message: "invalid or expired oauth handoff"}
	}
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil || !user.IsActive || !user.IsVerified {
		return nil, "", "", api.ErrUnauthorized
	}
	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	return user, access, refresh, err
}
