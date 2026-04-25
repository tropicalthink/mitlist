package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func TestVaultService_CreateVaultItem(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		vaultRepo.On("CreateVaultItem", ctx, mock.AnythingOfType("*models.VaultItem")).Return(nil)

		item := &models.VaultItem{GroupID: groupID, Title: "Password"}
		err := svc.CreateVaultItem(ctx, userID, item)
		require.NoError(t, err)
		assert.Equal(t, userID, item.CreatedBy)
	})

	t.Run("not a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		err := svc.CreateVaultItem(ctx, userID, &models.VaultItem{GroupID: groupID})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestVaultService_GetVaultItem(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	itemID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(&models.VaultItem{ID: itemID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)

		item, err := svc.GetVaultItem(ctx, userID, itemID)
		require.NoError(t, err)
		assert.Equal(t, itemID, item.ID)
	})

	t.Run("not found", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		svc := NewVaultService(vaultRepo, nil)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetVaultItem(ctx, userID, itemID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}

func TestVaultService_ShareVaultItem(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	itemID := uuid.New()
	groupID := uuid.New()
	sharedWith := uuid.New()

	t.Run("success", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(&models.VaultItem{ID: itemID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		groupRepo.On("GetMembership", ctx, groupID, sharedWith).Return(&models.GroupMembership{}, nil)
		vaultRepo.On("CreateShare", ctx, mock.AnythingOfType("*models.VaultShare")).Return(nil)

		share, err := svc.ShareVaultItem(ctx, userID, itemID, sharedWith, "view")
		require.NoError(t, err)
		assert.Equal(t, itemID, share.VaultItemID)
	})

	t.Run("shared user not in group", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(&models.VaultItem{ID: itemID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		groupRepo.On("GetMembership", ctx, groupID, sharedWith).Return(nil, pgx.ErrNoRows)

		_, err := svc.ShareVaultItem(ctx, userID, itemID, sharedWith, "view")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestVaultService_RevokeShare(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	itemID := uuid.New()
	groupID := uuid.New()
	shareID := uuid.New()

	t.Run("success", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(&models.VaultItem{ID: itemID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		vaultRepo.On("ListShares", ctx, itemID).Return([]models.VaultShare{{ID: shareID}}, nil)
		vaultRepo.On("DeleteShare", ctx, shareID).Return(nil)

		err := svc.RevokeShare(ctx, userID, itemID, shareID)
		require.NoError(t, err)
	})

	t.Run("share not found", func(t *testing.T) {
		vaultRepo := new(mocks.MockVaultRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewVaultService(vaultRepo, groupRepo)

		vaultRepo.On("GetVaultItemByID", ctx, itemID).Return(&models.VaultItem{ID: itemID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		vaultRepo.On("ListShares", ctx, itemID).Return([]models.VaultShare{}, nil)

		err := svc.RevokeShare(ctx, userID, itemID, shareID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}
