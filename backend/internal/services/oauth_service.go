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

// providerIdentity is what a provider vouches for once its code has been
// exchanged: a stable id, a verified address, and whatever name it shares.
type providerIdentity struct {
	provider, providerUserID, email, firstName, lastName, avatarURL string
}

// googleProfile exchanges the code and returns Google's verified identity
// without touching the user table.
func (s *OAuthService) googleProfile(code, redirectURI string, pkceVerifier ...string) (*providerIdentity, error) {
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
	return &providerIdentity{
		provider:       "google",
		providerUserID: googleUser.ID,
		email:          googleUser.Email,
		firstName:      googleUser.GivenName,
		lastName:       googleUser.FamilyName,
		avatarURL:      googleUser.Picture,
	}, nil
}

// GoogleIdentity validates the redirect URI, exchanges the code, fetches user
// info, and creates or links the user.
func (s *OAuthService) GoogleIdentity(ctx context.Context, code, redirectURI string, pkceVerifier ...string) (*models.User, error) {
	id, err := s.googleProfile(code, redirectURI, pkceVerifier...)
	if err != nil {
		return nil, err
	}
	return s.processOAuthUser(ctx, id.provider, id.providerUserID, id.email, id.firstName, id.lastName, id.avatarURL)
}

// LinkGuestGoogle turns the guest [guestID] into a Google-backed account.
func (s *OAuthService) LinkGuestGoogle(ctx context.Context, guestID uuid.UUID, code, redirectURI string, pkceVerifier ...string) (*models.User, error) {
	id, err := s.googleProfile(code, redirectURI, pkceVerifier...)
	if err != nil {
		return nil, err
	}
	return s.linkGuest(ctx, guestID, id)
}

func (s *OAuthService) GoogleLogin(ctx context.Context, code, redirectURI string, pkceVerifier ...string) (*models.User, string, string, error) {
	user, err := s.GoogleIdentity(ctx, code, redirectURI, pkceVerifier...)
	if err != nil {
		return nil, "", "", err
	}
	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	return user, access, refresh, err
}

// appleProfile exchanges the code, validates the identity token and returns
// Apple's verified identity without touching the user table.
func (s *OAuthService) appleProfile(code, redirectURI, idToken string, pkceVerifier ...string) (*providerIdentity, error) {
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
	return &providerIdentity{
		provider:       "apple",
		providerUserID: appleUser.ID,
		email:          appleUser.Email,
		firstName:      appleUser.GivenName,
		lastName:       appleUser.FamilyName,
	}, nil
}

// AppleIdentity validates the redirect URI, exchanges the code, validates the
// identity token, and creates or links the user.
func (s *OAuthService) AppleIdentity(ctx context.Context, code, redirectURI, idToken string, pkceVerifier ...string) (*models.User, error) {
	id, err := s.appleProfile(code, redirectURI, idToken, pkceVerifier...)
	if err != nil {
		return nil, err
	}
	return s.processOAuthUser(ctx, id.provider, id.providerUserID, id.email, id.firstName, id.lastName, id.avatarURL)
}

// LinkGuestApple turns the guest [guestID] into an Apple-backed account.
func (s *OAuthService) LinkGuestApple(ctx context.Context, guestID uuid.UUID, code, redirectURI, idToken string, pkceVerifier ...string) (*models.User, error) {
	id, err := s.appleProfile(code, redirectURI, idToken, pkceVerifier...)
	if err != nil {
		return nil, err
	}
	return s.linkGuest(ctx, guestID, id)
}

// linkGuest upgrades a guest in place: the provider's verified address and
// identity go onto the guest's own row, so every list, expense and household
// membership the guest built up stays theirs. Nothing is merged — a provider
// identity or address that already belongs to another account is refused,
// because silently joining two accounts is how people lose data.
func (s *OAuthService) linkGuest(ctx context.Context, guestID uuid.UUID, id *providerIdentity) (*models.User, error) {
	guest, err := s.userRepo.GetByID(ctx, guestID)
	if err != nil {
		return nil, &api.NotFoundError{Resource: "guest user", ID: guestID.String()}
	}
	if !guest.IsGuest {
		return nil, &api.ValidationError{Field: "user", Message: "user is not a guest"}
	}
	if !guest.IsActive {
		return nil, &api.ValidationError{Message: "guest account is locked; refresh the app session to reactivate it"}
	}

	if _, err := s.authRepo.GetOAuthByProviderID(ctx, id.provider, id.providerUserID); err == nil {
		return nil, &api.ConflictError{Message: "that " + id.provider + " account already signs in to another mitlist account"}
	} else if !isNotFound(err) {
		return nil, fmt.Errorf("get oauth account: %w", err)
	}

	email := validation.NormalizeEmail(id.email)
	if email == "" {
		return nil, &api.ValidationError{Field: "email", Message: "provider did not share an email address"}
	}
	if existing, err := s.userRepo.GetByEmail(ctx, email); err == nil && existing.ID != guestID {
		return nil, &api.ConflictError{Message: "email is not available"}
	} else if err != nil && !isNotFound(err) {
		return nil, fmt.Errorf("get user by email: %w", err)
	}

	guest.Email = email
	// A guest keeps a name they typed themselves; the generated "<adjective>
	// <noun> Guest" placeholder gives way to what the provider knows.
	if guest.LastName == "Guest" && (id.firstName != "" || id.lastName != "") {
		guest.FirstName = id.firstName
		guest.LastName = id.lastName
	}
	if guest.AvatarURL == nil && id.avatarURL != "" {
		avatar := id.avatarURL
		guest.AvatarURL = &avatar
	}
	guest.IsGuest = false
	guest.IsVerified = true

	if err := s.userRepo.Update(ctx, guest); err != nil {
		return nil, fmt.Errorf("upgrade guest: %w", err)
	}
	if err := s.authRepo.CreateOAuthAccount(ctx, &models.OAuthAccount{
		UserID:         guest.ID,
		Provider:       id.provider,
		ProviderUserID: id.providerUserID,
	}); err != nil {
		return nil, fmt.Errorf("link oauth account: %w", err)
	}
	// The guest-scoped sessions must not outlive the guest. The handoff that
	// follows issues the account its first real pair.
	if err := s.jwtService.RevokeUserSessions(guest.ID); err != nil {
		return nil, fmt.Errorf("revoke guest sessions: %w", err)
	}
	return guest, nil
}

// linkTokenDigest keys link tokens apart from handoff codes in the shared
// table, so a link token can never be cashed in at the handoff exchange.
func linkTokenDigest(code string) string {
	digest := sha256.Sum256([]byte("link:" + code))
	return hex.EncodeToString(digest[:])
}

// CreateLinkToken mints the one-time token a guest carries into the provider
// round-trip, so the callback can tell whose account to upgrade.
func (s *OAuthService) CreateLinkToken(ctx context.Context, guestID uuid.UUID) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	code := base64.RawURLEncoding.EncodeToString(raw)
	if err := s.authRepo.CreateOAuthHandoff(ctx, linkTokenDigest(code), guestID, time.Now().UTC().Add(10*time.Minute)); err != nil {
		return "", err
	}
	return code, nil
}

// ConsumeLinkToken returns the guest a link token was minted for, once.
func (s *OAuthService) ConsumeLinkToken(ctx context.Context, code string) (uuid.UUID, error) {
	guestID, err := s.authRepo.ConsumeOAuthHandoff(ctx, linkTokenDigest(code))
	if err != nil {
		return uuid.Nil, &api.ValidationError{Message: "invalid or expired link request"}
	}
	return guestID, nil
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
