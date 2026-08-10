package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

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
