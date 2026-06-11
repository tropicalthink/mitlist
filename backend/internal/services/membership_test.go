package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestRequireGroupMember(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()

	t.Run("member ok", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		err := requireGroupMember(ctx, groupRepo, groupID, userID)
		require.NoError(t, err)
		groupRepo.AssertExpectations(t)
	})

	t.Run("admin ok", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		err := requireGroupMember(ctx, groupRepo, groupID, userID)
		require.NoError(t, err)
		groupRepo.AssertExpectations(t)
	})

	t.Run("unknown role denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "viewer"}, nil)
		err := requireGroupMember(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertExpectations(t)
	})

	t.Run("no row denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		err := requireGroupMember(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertExpectations(t)
	})

	t.Run("repo error propagated", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		dbErr := errors.New("connection refused")
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, dbErr)
		err := requireGroupMember(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, dbErr)
		groupRepo.AssertExpectations(t)
	})
}

func TestRequireGroupAdmin(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()

	t.Run("admin ok", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		err := requireGroupAdmin(ctx, groupRepo, groupID, userID)
		require.NoError(t, err)
		groupRepo.AssertExpectations(t)
	})

	t.Run("member denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		err := requireGroupAdmin(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertExpectations(t)
	})

	t.Run("unknown role denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "viewer"}, nil)
		err := requireGroupAdmin(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertExpectations(t)
	})

	t.Run("no row denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		err := requireGroupAdmin(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertExpectations(t)
	})

	t.Run("repo error propagated", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		dbErr := errors.New("connection refused")
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, dbErr)
		err := requireGroupAdmin(ctx, groupRepo, groupID, userID)
		assert.ErrorIs(t, err, dbErr)
		groupRepo.AssertExpectations(t)
	})
}
