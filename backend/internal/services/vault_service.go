package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// VaultService provides business logic for vault items and shares.
type VaultService struct {
	vaultRepo repositories.VaultRepo
	groupRepo repositories.GroupRepo
}

// NewVaultService creates a new VaultService.
func NewVaultService(
	vaultRepo repositories.VaultRepo,
	groupRepo repositories.GroupRepo,
) *VaultService {
	return &VaultService{
		vaultRepo: vaultRepo,
		groupRepo: groupRepo,
	}
}

func (s *VaultService) requireGroupMember(ctx context.Context, groupID, userID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Action: "access group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

// CreateVaultItem creates a new vault item.
func (s *VaultService) CreateVaultItem(ctx context.Context, userID uuid.UUID, item *models.VaultItem) error {
	if err := s.requireGroupMember(ctx, item.GroupID, userID); err != nil {
		return err
	}
	if item.ID == uuid.Nil {
		item.ID = uuid.New()
	}
	now := time.Now().UTC()
	item.CreatedAt = now
	item.UpdatedAt = now
	item.CreatedBy = userID
	return s.vaultRepo.CreateVaultItem(ctx, item)
}

// GetVaultItem retrieves a vault item by ID.
func (s *VaultService) GetVaultItem(ctx context.Context, userID, itemID uuid.UUID) (*models.VaultItem, error) {
	item, err := s.vaultRepo.GetVaultItemByID(ctx, itemID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "vault item", ID: itemID.String()}
		}
		return nil, fmt.Errorf("get vault item: %w", err)
	}
	if err := s.requireGroupMember(ctx, item.GroupID, userID); err != nil {
		return nil, err
	}
	return item, nil
}

// ListVaultItems lists vault items for a group.
func (s *VaultService) ListVaultItems(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.VaultItem, error) {
	if err := s.requireGroupMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.vaultRepo.ListVaultItemsByGroup(ctx, groupID, limit, offset)
}

// UpdateVaultItem updates a vault item.
func (s *VaultService) UpdateVaultItem(ctx context.Context, userID uuid.UUID, item *models.VaultItem) error {
	existing, err := s.vaultRepo.GetVaultItemByID(ctx, item.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "vault item", ID: item.ID.String()}
		}
		return fmt.Errorf("get vault item: %w", err)
	}
	if err := s.requireGroupMember(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	item.UpdatedAt = time.Now().UTC()
	return s.vaultRepo.UpdateVaultItem(ctx, item)
}

// DeleteVaultItem deletes a vault item.
func (s *VaultService) DeleteVaultItem(ctx context.Context, userID, itemID uuid.UUID) error {
	item, err := s.vaultRepo.GetVaultItemByID(ctx, itemID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "vault item", ID: itemID.String()}
		}
		return fmt.Errorf("get vault item: %w", err)
	}
	if err := s.requireGroupMember(ctx, item.GroupID, userID); err != nil {
		return err
	}
	return s.vaultRepo.DeleteVaultItem(ctx, itemID)
}

// ShareVaultItem shares a vault item with another user.
func (s *VaultService) ShareVaultItem(ctx context.Context, userID, itemID, sharedWithUserID uuid.UUID, permission string) (*models.VaultShare, error) {
	item, err := s.vaultRepo.GetVaultItemByID(ctx, itemID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "vault item", ID: itemID.String()}
		}
		return nil, fmt.Errorf("get vault item: %w", err)
	}
	if err := s.requireGroupMember(ctx, item.GroupID, userID); err != nil {
		return nil, err
	}
	// Ensure the shared-with user is also a member of the group.
	if err := s.requireGroupMember(ctx, item.GroupID, sharedWithUserID); err != nil {
		return nil, &api.ValidationError{Field: "shared_with_user_id", Message: "user is not a member of the group"}
	}
	share := &models.VaultShare{
		ID:               uuid.New(),
		VaultItemID:      itemID,
		SharedWithUserID: sharedWithUserID,
		Permission:       permission,
		CreatedAt:        time.Now().UTC(),
	}
	if err := s.vaultRepo.CreateShare(ctx, share); err != nil {
		return nil, fmt.Errorf("create share: %w", err)
	}
	return share, nil
}

// RevokeShare revokes a vault share.
func (s *VaultService) RevokeShare(ctx context.Context, userID, vaultItemID, shareID uuid.UUID) error {
	item, err := s.vaultRepo.GetVaultItemByID(ctx, vaultItemID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "vault item", ID: vaultItemID.String()}
		}
		return fmt.Errorf("get vault item: %w", err)
	}
	if err := s.requireGroupMember(ctx, item.GroupID, userID); err != nil {
		return err
	}
	// Verify the share exists for this item.
	shares, err := s.vaultRepo.ListShares(ctx, vaultItemID)
	if err != nil {
		return fmt.Errorf("list shares: %w", err)
	}
	found := false
	for _, sh := range shares {
		if sh.ID == shareID {
			found = true
			break
		}
	}
	if !found {
		return &api.NotFoundError{Resource: "vault share", ID: shareID.String()}
	}
	return s.vaultRepo.DeleteShare(ctx, shareID)
}
