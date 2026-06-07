package services

import (
	"context"
	"testing"

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
		svc := NewGuestService(userRepo, jwtSvc, nil, nil)

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
		svc := NewGuestService(userRepo, nil, nil, nil)

		userRepo.On("GetByID", ctx, userID).Return(&models.User{ID: userID, IsGuest: true}, nil)

		user, err := svc.GetGuest(ctx, userID)
		require.NoError(t, err)
		assert.True(t, user.IsGuest)
	})

	t.Run("not a guest", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil, nil)

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
		jwtSvc := new(mocks.MockJWTService)
		passSvc := new(mocks.MockPasswordService)
		svc := NewGuestService(userRepo, jwtSvc, passSvc, nil)

		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsGuest: true}, nil)
		passSvc.On("Hash", "password123").Return("hash", nil)
		userRepo.On("Update", ctx, mock.AnythingOfType("*models.User")).Return(nil)
		jwtSvc.On("GenerateTokenPair", guestID.String(), mock.Anything).Return("access", "refresh", nil)

		user, access, _, err := svc.ConvertGuest(ctx, guestID, "new@example.com", "password123", "Test", "User")
		require.NoError(t, err)
		assert.False(t, user.IsGuest)
		assert.Equal(t, "new@example.com", user.Email)
		assert.Equal(t, "access", access)
	})

	t.Run("not a guest", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewGuestService(userRepo, nil, nil, nil)

		userRepo.On("GetByID", ctx, guestID).Return(&models.User{ID: guestID, IsGuest: false}, nil)

		_, _, _, err := svc.ConvertGuest(ctx, guestID, "new@example.com", "password123", "Test", "User")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}
