package services

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestGuestService_CreateGuest(t *testing.T) {
	ctx := context.Background()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		jwtSvc := new(mocks.MockJWTService)
		svc := NewGuestService(userRepo, jwtSvc, nil)

		userRepo.On("Create", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		jwtSvc.On("GenerateTokenPair", mock.AnythingOfType("string"), mock.Anything).Return("access", "refresh", nil)

		user, access, refresh, err := svc.CreateGuest(ctx)
		require.NoError(t, err)
		assert.True(t, user.IsGuest)
		assert.Equal(t, "access", access)
		assert.Equal(t, "refresh", refresh)
	})
}

func TestGuestService_GetGuest(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil)

		userRepo.On("GetByID", ctx, userID).Return(&models.User{ID: userID, IsGuest: true, IsActive: true}, nil)

		user, err := svc.GetGuest(ctx, userID)
		require.NoError(t, err)
		assert.True(t, user.IsGuest)
	})

	t.Run("locked guest is retained and rejected", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil)
		userRepo.On("GetByID", ctx, userID).Return(&models.User{
			ID: userID, IsGuest: true, IsActive: false,
		}, nil)

		_, err := svc.GetGuest(ctx, userID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		userRepo.AssertExpectations(t)
	})

	t.Run("not a guest", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil)

		userRepo.On("GetByID", ctx, userID).Return(&models.User{ID: userID, IsGuest: false}, nil)

		_, err := svc.GetGuest(ctx, userID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGuestService_ConvertGuest(t *testing.T) {
	ctx := context.Background()
	guestID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		passSvc := new(mocks.MockPasswordService)
		mailSvc := new(mocks.MockMailService)
		svc := NewGuestServiceWithAuth(userRepo, jwtSvc, passSvc, authRepo, mailSvc)

		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsGuest: true, IsActive: true}, nil)
		userRepo.On("GetByEmail", ctx, "new@example.com").Return(nil, fmt.Errorf("user not found"))
		passSvc.On("Hash", "Password123!").Return("hash", nil)
		userRepo.On("Update", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		authRepo.On("CreateEmailVerification", ctx, guestID, mock.AnythingOfType("string"), mock.AnythingOfType("time.Time")).Return(nil)
		mailSvc.On("Send", "new@example.com", "Verify your mitlist account", mock.AnythingOfType("string"), false).Return(nil)
		jwtSvc.On("RevokeUserSessions", guestID).Return(nil)
		jwtSvc.On("GenerateTokenPair", guestID.String(), mock.Anything).Return("access", "refresh", nil)

		user, access, _, err := svc.ConvertGuest(ctx, guestID, "new@example.com", "Password123!", "Test", "User")
		require.NoError(t, err)
		assert.True(t, user.IsGuest)
		assert.False(t, user.IsVerified)
		assert.Equal(t, "new@example.com", user.Email)
		assert.Equal(t, "access", access)
	})

	t.Run("not a guest", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil)

		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsGuest: false}, nil)

		_, _, _, err := svc.ConvertGuest(ctx, guestID, "new@example.com", "password123", "Test", "User")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGuestService_CreateGuestForIdentity_UsesDurableQuota(t *testing.T) {
	ctx := context.Background()
	userRepo := new(mocks.MockUserRepo)
	authRepo := new(mocks.MockAuthRepo)
	svc := NewGuestServiceWithAuth(userRepo, nil, nil, authRepo, nil)

	authRepo.On("ReserveLoginAttempt", ctx, guestQuotaKey("install", "device-1"), 3, 30*24*time.Hour).
		Return(false, nil)

	_, _, _, err := svc.CreateGuestForIdentity(ctx, "203.0.113.5", "device-1")
	require.ErrorIs(t, err, ErrGuestCreationLimit)
	userRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
}
