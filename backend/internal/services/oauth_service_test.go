package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestOAuthService_linkGuest(t *testing.T) {
	ctx := context.Background()
	identity := &providerIdentity{
		provider: "google", providerUserID: "g-1", email: "Person@Example.com",
		firstName: "Pat", lastName: "Person", avatarURL: "https://img/pat",
	}

	t.Run("upgrades the guest row in place", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

		guestID := uuid.New()
		guest := &models.User{ID: guestID, Email: "guest_x@mitlist.local", FirstName: "Brisk", LastName: "Otter", IsActive: true, IsVerified: true, IsGuest: true}
		userRepo.On("GetByID", ctx, guestID).Return(guest, nil)
		authRepo.On("GetOAuthByProviderID", ctx, "google", "g-1").Return(nil, errors.New("oauth account not found"))
		userRepo.On("GetByEmail", ctx, "person@example.com").Return(nil, errors.New("user not found"))
		userRepo.On("Update", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		authRepo.On("CreateOAuthAccount", ctx, mock.AnythingOfType("*models.OAuthAccount")).Return(nil)
		jwtSvc.On("RevokeUserSessions", guestID).Return(nil)

		user, err := svc.linkGuest(ctx, guestID, identity)
		require.NoError(t, err)
		// Same row, now a real verified account with the provider's address.
		assert.Equal(t, guestID, user.ID)
		assert.False(t, user.IsGuest)
		assert.True(t, user.IsVerified)
		assert.Equal(t, "person@example.com", user.Email)
		// A typed name would have stayed; the generated placeholder did not.
		assert.Equal(t, "Brisk", user.FirstName)
		assert.Equal(t, "Otter", user.LastName)
		require.NotNil(t, user.AvatarURL)
		jwtSvc.AssertCalled(t, "RevokeUserSessions", guestID)
	})

	t.Run("replaces a generated placeholder name", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

		guestID := uuid.New()
		guest := &models.User{ID: guestID, FirstName: "Brisk Otter", LastName: "Guest", IsActive: true, IsVerified: true, IsGuest: true}
		userRepo.On("GetByID", ctx, guestID).Return(guest, nil)
		authRepo.On("GetOAuthByProviderID", ctx, "google", "g-1").Return(nil, errors.New("oauth account not found"))
		userRepo.On("GetByEmail", ctx, "person@example.com").Return(nil, errors.New("user not found"))
		userRepo.On("Update", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		authRepo.On("CreateOAuthAccount", ctx, mock.AnythingOfType("*models.OAuthAccount")).Return(nil)
		jwtSvc.On("RevokeUserSessions", guestID).Return(nil)

		user, err := svc.linkGuest(ctx, guestID, identity)
		require.NoError(t, err)
		assert.Equal(t, "Pat", user.FirstName)
		assert.Equal(t, "Person", user.LastName)
	})

	t.Run("refuses a provider identity that already signs in elsewhere", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		svc := NewOAuthService(userRepo, authRepo, new(mocks.MockJWTService), nil, nil)

		guestID := uuid.New()
		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsActive: true, IsGuest: true}, nil)
		authRepo.On("GetOAuthByProviderID", ctx, "google", "g-1").Return(&models.OAuthAccount{UserID: uuid.New()}, nil)

		_, err := svc.linkGuest(ctx, guestID, identity)
		require.Error(t, err)
		assert.IsType(t, &api.ConflictError{}, err)
		userRepo.AssertNotCalled(t, "Update", mock.Anything, mock.Anything)
	})

	t.Run("refuses an address that belongs to another account", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		svc := NewOAuthService(userRepo, authRepo, new(mocks.MockJWTService), nil, nil)

		guestID := uuid.New()
		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsActive: true, IsGuest: true}, nil)
		authRepo.On("GetOAuthByProviderID", ctx, "google", "g-1").Return(nil, errors.New("oauth account not found"))
		userRepo.On("GetByEmail", ctx, "person@example.com").Return(&models.User{ID: uuid.New()}, nil)

		_, err := svc.linkGuest(ctx, guestID, identity)
		require.Error(t, err)
		assert.IsType(t, &api.ConflictError{}, err)
		userRepo.AssertNotCalled(t, "Update", mock.Anything, mock.Anything)
	})

	t.Run("refuses a non-guest", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewOAuthService(userRepo, new(mocks.MockAuthRepo), new(mocks.MockJWTService), nil, nil)

		id := uuid.New()
		userRepo.On("GetByID", ctx, id).Return(&models.User{ID: id, IsActive: true, IsGuest: false}, nil)

		_, err := svc.linkGuest(ctx, id, identity)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestOAuthService_processOAuthUser(t *testing.T) {
	ctx := context.Background()

	t.Run("success existing oauth", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

		userID := uuid.New()
		authRepo.On("GetOAuthByProviderID", ctx, "google", "google123").Return(&models.OAuthAccount{UserID: userID}, nil)
		userRepo.On("GetByID", ctx, userID).Return(&models.User{ID: userID, IsActive: true, IsVerified: true}, nil)

		user, err := svc.processOAuthUser(ctx, "google", "google123", "", "", "", "")
		require.NoError(t, err)
		assert.Equal(t, userID, user.ID)
	})

	t.Run("success new user", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

		authRepo.On("GetOAuthByProviderID", ctx, "google", "google123").Return(nil, errors.New("oauth account not found"))
		userRepo.On("GetByEmail", ctx, "test@gmail.com").Return(nil, errors.New("user not found"))
		userRepo.On("Create", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		authRepo.On("CreateOAuthAccount", ctx, mock.AnythingOfType("*models.OAuthAccount")).Return(nil)

		user, err := svc.processOAuthUser(ctx, "google", "google123", "test@gmail.com", "Test", "User", "")
		require.NoError(t, err)
		assert.Equal(t, "test@gmail.com", user.Email)
	})

	t.Run("success link existing user by email", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

		userID := uuid.New()
		authRepo.On("GetOAuthByProviderID", ctx, "apple", "apple123").Return(nil, errors.New("oauth account not found"))
		userRepo.On("GetByEmail", ctx, "test@icloud.com").Return(&models.User{ID: userID, Email: "test@icloud.com"}, nil)
		authRepo.On("CreateOAuthAccount", ctx, mock.AnythingOfType("*models.OAuthAccount")).Return(nil)

		user, err := svc.processOAuthUser(ctx, "apple", "apple123", "test@icloud.com", "Test", "User", "")
		require.NoError(t, err)
		assert.Equal(t, userID, user.ID)
	})
}
