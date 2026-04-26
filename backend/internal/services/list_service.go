package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// ListService provides business logic for lists and list items.
type ListService struct {
	listRepo  repositories.ListRepo
	groupRepo repositories.GroupRepo
}

// NewListService creates a new ListService.
func NewListService(listRepo repositories.ListRepo, groupRepo repositories.GroupRepo) *ListService {
	return &ListService{
		listRepo:  listRepo,
		groupRepo: groupRepo,
	}
}

func (s *ListService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("failed to check membership: %w", err)
	}
	return nil
}

func (s *ListService) requireActiveVerifiedUser(u *models.User) error {
	if !u.IsActive || !u.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	return nil
}

// CreateList creates a new list within a group.
func (s *ListService) CreateList(ctx context.Context, user *models.User, list *models.List) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	if list.Name == "" {
		return &api.ValidationError{Field: "name", Message: "name is required"}
	}
	return s.listRepo.CreateList(ctx, list)
}

// GetList retrieves a single list by ID, enforcing group membership.
func (s *ListService) GetList(ctx context.Context, user *models.User, listID uuid.UUID) (*models.List, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return nil, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return nil, err
	}
	return list, nil
}

const listHubPreviewLines = 4

// ListLists returns all lists for a group the user belongs to.
func (s *ListService) ListLists(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.List, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	lists, err := s.listRepo.ListListsByGroup(ctx, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	if len(lists) == 0 {
		return lists, nil
	}
	ids := make([]uuid.UUID, len(lists))
	for i := range lists {
		ids[i] = lists[i].ID
	}
	previews, err := s.listRepo.ListItemPreviewLinesByListIDs(ctx, ids, listHubPreviewLines)
	if err != nil {
		return lists, nil
	}
	for i := range lists {
		if p, ok := previews[lists[i].ID]; ok && len(p) > 0 {
			lists[i].ItemPreview = p
		}
	}
	return lists, nil
}

// UpdateList updates a list's name and type.
func (s *ListService) UpdateList(ctx context.Context, user *models.User, listID uuid.UUID, name, listType string) (*models.List, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return nil, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return nil, err
	}
	if name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "name is required"}
	}
	list.Name = name
	list.Type = listType
	if err := s.listRepo.UpdateList(ctx, list); err != nil {
		return nil, fmt.Errorf("failed to update list: %w", err)
	}
	return list, nil
}

// DeleteList hard-deletes a list and all its items.
func (s *ListService) DeleteList(ctx context.Context, user *models.User, listID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	return s.listRepo.HardDeleteList(ctx, listID)
}

// CreateItem adds a new item to a list.
func (s *ListService) CreateItem(ctx context.Context, user *models.User, item *models.ListItem) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list", ID: item.ListID.String()}
		}
		return fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	if item.Name == "" {
		return &api.ValidationError{Field: "name", Message: "item name is required"}
	}
	return s.listRepo.CreateItem(ctx, item)
}

// GetItem retrieves a single list item by ID.
func (s *ListService) GetItem(ctx context.Context, user *models.User, itemID uuid.UUID) (*models.ListItem, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	item, err := s.listRepo.GetItemByID(ctx, itemID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list item", ID: itemID.String()}
		}
		return nil, fmt.Errorf("failed to get item: %w", err)
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		return nil, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return nil, err
	}
	return item, nil
}

// UpdateItem updates an existing list item.
func (s *ListService) UpdateItem(ctx context.Context, user *models.User, item *models.ListItem) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	existing, err := s.listRepo.GetItemByID(ctx, item.ID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list item", ID: item.ID.String()}
		}
		return fmt.Errorf("failed to get item: %w", err)
	}
	list, err := s.listRepo.GetListByID(ctx, existing.ListID)
	if err != nil {
		return fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	if item.Name == "" {
		return &api.ValidationError{Field: "name", Message: "item name is required"}
	}
	// Preserve list_id from existing record to prevent moving between lists.
	item.ListID = existing.ListID
	return s.listRepo.UpdateItem(ctx, item)
}

// DeleteItem soft-deletes a list item.
func (s *ListService) DeleteItem(ctx context.Context, user *models.User, itemID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	item, err := s.listRepo.GetItemByID(ctx, itemID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list item", ID: itemID.String()}
		}
		return fmt.Errorf("failed to get item: %w", err)
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		return fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	return s.listRepo.SoftDeleteItem(ctx, itemID)
}

// ListItems returns all items in a list, enforcing group membership.
func (s *ListService) ListItems(ctx context.Context, user *models.User, listID uuid.UUID, limit, offset int) ([]models.ListItem, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return nil, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return nil, err
	}
	return s.listRepo.ListItemsByList(ctx, listID, limit, offset)
}

// ReorderItems updates the position of items within a list to match the provided order.
func (s *ListService) ReorderItems(ctx context.Context, user *models.User, listID uuid.UUID, itemIDs []uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return err
	}
	if len(itemIDs) == 0 {
		return nil
	}
	// Verify all items belong to the list.
	items, err := s.listRepo.ListItemsByList(ctx, listID, 0, 0)
	if err != nil {
		return fmt.Errorf("failed to list items: %w", err)
	}
	itemSet := make(map[uuid.UUID]struct{}, len(items))
	for _, it := range items {
		itemSet[it.ID] = struct{}{}
	}
	for _, id := range itemIDs {
		if _, ok := itemSet[id]; !ok {
			return &api.ValidationError{Field: "item_ids", Message: fmt.Sprintf("item %s does not belong to this list", id)}
		}
	}
	batch := make([]models.ListItem, len(itemIDs))
	for pos, id := range itemIDs {
		batch[pos] = models.ListItem{ID: id, Position: pos}
	}
	return s.listRepo.BatchUpdateItemPositions(ctx, batch)
}
