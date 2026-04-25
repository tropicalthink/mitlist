package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockVaultRepo is a mock implementation of repositories.VaultRepo.
type MockVaultRepo struct {
	mock.Mock
}

func (m *MockVaultRepo) CreateVaultItem(ctx context.Context, item *models.VaultItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockVaultRepo) GetVaultItemByID(ctx context.Context, id uuid.UUID) (*models.VaultItem, error) {
	args := m.Called(ctx, id)
	if i := args.Get(0); i != nil {
		return i.(*models.VaultItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockVaultRepo) ListVaultItemsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.VaultItem, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if i := args.Get(0); i != nil {
		return i.([]models.VaultItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockVaultRepo) UpdateVaultItem(ctx context.Context, item *models.VaultItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockVaultRepo) DeleteVaultItem(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockVaultRepo) CreateShare(ctx context.Context, share *models.VaultShare) error {
	args := m.Called(ctx, share)
	return args.Error(0)
}

func (m *MockVaultRepo) ListShares(ctx context.Context, vaultItemID uuid.UUID) ([]models.VaultShare, error) {
	args := m.Called(ctx, vaultItemID)
	if s := args.Get(0); s != nil {
		return s.([]models.VaultShare), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockVaultRepo) DeleteShare(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
