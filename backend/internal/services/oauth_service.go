package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"golang.org/x/oauth2"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	oauthclient "github.com/mitlist-app/mitlist/internal/services/oauth"
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
func (s *OAuthService) GoogleLogin(ctx context.Context, code, redirectURI string) (*models.User, string, string, error) {
	if redirectURI != "" {
		if !s.googleClient.AllowRedirect(redirectURI) {
			return nil, "", "", &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"}
		}
	}

	token, err := s.googleClient.ExchangeCode(code)
	if err != nil {
		return nil, "", "", fmt.Errorf("exchange code: %w", err)
	}

	googleUser, err := s.googleClient.GetUserInfo(token)
	if err != nil {
		return nil, "", "", fmt.Errorf("get user info: %w", err)
	}

	return s.processOAuthUser(ctx, "google", googleUser.ID, googleUser.Email, googleUser.GivenName, googleUser.FamilyName, googleUser.Picture, token)
}

// AppleLogin validates the redirect URI, exchanges the code, validates the identity token,
// creates or links the user, and issues a token pair.
func (s *OAuthService) AppleLogin(ctx context.Context, code, redirectURI, idToken string) (*models.User, string, string, error) {
	if redirectURI != "" {
		if !s.appleClient.AllowRedirect(redirectURI) {
			return nil, "", "", &api.ValidationError{Field: "redirect_uri", Message: "redirect URI not allowed"}
		}
	}

	token, err := s.appleClient.ExchangeCode(code)
	if err != nil {
		return nil, "", "", fmt.Errorf("exchange code: %w", err)
	}

	if idToken == "" && token != nil {
		if rawIDToken, ok := token.Extra("id_token").(string); ok {
			idToken = rawIDToken
		}
	}
	if idToken == "" {
		return nil, "", "", &api.ValidationError{Field: "id_token", Message: "identity token is required"}
	}

	appleUser, err := s.appleClient.ValidateIdentityToken(idToken)
	if err != nil {
		return nil, "", "", fmt.Errorf("validate identity token: %w", err)
	}

	return s.processOAuthUser(ctx, "apple", appleUser.ID, appleUser.Email, appleUser.GivenName, appleUser.FamilyName, "", token)
}

func (s *OAuthService) processOAuthUser(
	ctx context.Context,
	provider, providerUserID, email, firstName, lastName, avatarURL string,
	token *oauth2.Token,
) (*models.User, string, string, error) {
	// Try existing OAuth link.
	oauthAccount, err := s.authRepo.GetOAuthByProviderID(ctx, provider, providerUserID)
	if err == nil {
		user, err := s.userRepo.GetByID(ctx, oauthAccount.UserID)
		if err != nil {
			return nil, "", "", fmt.Errorf("get linked user: %w", err)
		}
		access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
		if err != nil {
			return nil, "", "", fmt.Errorf("generate tokens: %w", err)
		}
		return user, access, refresh, nil
	}

	// Try to find user by email.
	var user *models.User
	if email != "" {
		user, _ = s.userRepo.GetByEmail(ctx, email)
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
			return nil, "", "", fmt.Errorf("create user: %w", err)
		}
	}

	// Link OAuth account.
	account := &models.OAuthAccount{
		UserID:         user.ID,
		Provider:       provider,
		ProviderUserID: providerUserID,
	}
	if token != nil {
		access := token.AccessToken
		refresh := token.RefreshToken
		account.AccessToken = &access
		account.RefreshToken = &refresh
		if !token.Expiry.IsZero() {
			expiry := token.Expiry
			account.ExpiresAt = &expiry
		}
	}
	if err := s.authRepo.CreateOAuthAccount(ctx, account); err != nil {
		return nil, "", "", fmt.Errorf("link oauth account: %w", err)
	}

	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		return nil, "", "", fmt.Errorf("generate tokens: %w", err)
	}

	return user, access, refresh, nil
}
