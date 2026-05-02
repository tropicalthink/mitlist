package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/validation"
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
	if u == nil {
		return api.ErrUnauthorized
	}
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
	if err := validation.RequiredString(list.Name, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(list.Name, validation.MaxListNameLength, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
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
	if err := validation.RequiredString(name, "name"); err != nil {
		return nil, &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(name, validation.MaxListNameLength, "name"); err != nil {
		return nil, &api.ValidationError{Field: "name", Message: err.Error()}
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
	if err := validation.RequiredString(item.Name, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(item.Name, validation.MaxItemNameLength, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if item.Note != "" {
		if err := validation.MaxLength(item.Note, validation.MaxDescriptionLength, "note"); err != nil {
			return &api.ValidationError{Field: "note", Message: err.Error()}
		}
	}
	if item.Quantity <= 0 {
		item.Quantity = 1
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
	if err := validation.RequiredString(item.Name, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(item.Name, validation.MaxItemNameLength, "name"); err != nil {
		return &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if item.Note != "" {
		if err := validation.MaxLength(item.Note, validation.MaxDescriptionLength, "note"); err != nil {
			return &api.ValidationError{Field: "note", Message: err.Error()}
		}
	}
	if item.Quantity <= 0 {
		return &api.ValidationError{Field: "quantity", Message: "quantity must be greater than zero"}
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

// ClearItems removes all active items, or only checked items, from a list.
func (s *ListService) ClearItems(ctx context.Context, user *models.User, listID uuid.UUID, onlyChecked bool) (int64, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return 0, err
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return 0, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return 0, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return 0, err
	}
	return s.listRepo.SoftDeleteItemsByList(ctx, listID, onlyChecked)
}

// AddItemAmount adds an amount to an existing matching item or creates it.
func (s *ListService) AddItemAmount(ctx context.Context, user *models.User, listID uuid.UUID, name string, amount float64, unit, note string) (*models.ListItem, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	name = strings.TrimSpace(name)
	unit = strings.TrimSpace(unit)
	note = strings.TrimSpace(note)
	if name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "item name is required"}
	}
	if amount <= 0 {
		return nil, &api.ValidationError{Field: "amount", Message: "amount must be greater than zero"}
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

	item, err := s.listRepo.GetItemByListNameUnit(ctx, listID, name, unit)
	if err != nil && err != pgx.ErrNoRows {
		return nil, fmt.Errorf("failed to find item: %w", err)
	}
	if err == nil {
		item.Quantity += amount
		item.Checked = false
		if note != "" {
			item.Note = note
		}
		if err := s.listRepo.UpdateItem(ctx, item); err != nil {
			return nil, fmt.Errorf("failed to update item: %w", err)
		}
		return item, nil
	}

	item = &models.ListItem{
		ListID:   listID,
		Name:     name,
		Quantity: amount,
		Unit:     unit,
		Note:     note,
	}
	if err := s.listRepo.CreateItem(ctx, item); err != nil {
		return nil, fmt.Errorf("failed to create item: %w", err)
	}
	return item, nil
}

// RemoveItemAmount removes an amount from a matching item, deleting it at zero.
func (s *ListService) RemoveItemAmount(ctx context.Context, user *models.User, listID uuid.UUID, name string, amount float64, unit string) (*models.ListItem, bool, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, false, err
	}
	name = strings.TrimSpace(name)
	unit = strings.TrimSpace(unit)
	if name == "" {
		return nil, false, &api.ValidationError{Field: "name", Message: "item name is required"}
	}
	if amount <= 0 {
		return nil, false, &api.ValidationError{Field: "amount", Message: "amount must be greater than zero"}
	}
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, false, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return nil, false, fmt.Errorf("failed to get list: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
		return nil, false, err
	}

	item, err := s.listRepo.GetItemByListNameUnit(ctx, listID, name, unit)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("failed to find item: %w", err)
	}
	if item.Quantity <= amount {
		if err := s.listRepo.SoftDeleteItem(ctx, item.ID); err != nil {
			return nil, false, fmt.Errorf("failed to remove item: %w", err)
		}
		return item, true, nil
	}
	item.Quantity -= amount
	if err := s.listRepo.UpdateItem(ctx, item); err != nil {
		return nil, false, fmt.Errorf("failed to update item: %w", err)
	}
	return item, false, nil
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

func (s *ListService) CreateShoppingLocation(ctx context.Context, user *models.User, location *models.ShoppingLocation) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	location.Name = strings.TrimSpace(location.Name)
	if location.Name == "" {
		return &api.ValidationError{Field: "name", Message: "location name is required"}
	}
	if err := s.requireMembership(ctx, user.ID, location.GroupID); err != nil {
		return err
	}
	return s.listRepo.CreateShoppingLocation(ctx, location)
}

func (s *ListService) ListShoppingLocations(ctx context.Context, user *models.User, groupID uuid.UUID) ([]models.ShoppingLocation, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.listRepo.ListShoppingLocationsByGroup(ctx, groupID)
}

func (s *ListService) CreateProduct(ctx context.Context, user *models.User, product *models.Product) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	product.Name = strings.TrimSpace(product.Name)
	product.Barcode = strings.TrimSpace(product.Barcode)
	product.Unit = strings.TrimSpace(product.Unit)
	if product.Name == "" {
		return &api.ValidationError{Field: "name", Message: "product name is required"}
	}
	if product.MinStock < 0 || product.InStock < 0 {
		return &api.ValidationError{Field: "stock", Message: "stock amounts cannot be negative"}
	}
	if err := s.requireMembership(ctx, user.ID, product.GroupID); err != nil {
		return err
	}
	return s.listRepo.CreateProduct(ctx, product)
}

func (s *ListService) ListProducts(ctx context.Context, user *models.User, groupID uuid.UUID) ([]models.Product, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.listRepo.ListProductsByGroup(ctx, groupID)
}

// SearchProducts searches products by name within a group.
func (s *ListService) SearchProducts(ctx context.Context, user *models.User, groupID uuid.UUID, query string) ([]models.Product, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	query = strings.TrimSpace(query)
	if query == "" {
		return s.listRepo.ListProductsByGroup(ctx, groupID)
	}
	return s.listRepo.SearchProducts(ctx, groupID, query, 20)
}

// CostSummary represents the cost breakdown for a list.
type CostSummary struct {
	TotalCents      int `json:"total_cents"`
	EqualShareCents int `json:"equal_share_cents"`
}

// GetCostSummary returns the cost summary for a list.
func (s *ListService) GetCostSummary(ctx context.Context, user *models.User, listID uuid.UUID) (*CostSummary, error) {
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

	totalCents, _, _, err := s.listRepo.CostSummary(ctx, listID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cost summary: %w", err)
	}

	// Get group members for equal share calculation
	memberships, err := s.groupRepo.ListMembershipsByGroup(ctx, list.GroupID)
	if err != nil {
		return nil, fmt.Errorf("failed to get members: %w", err)
	}

	memberCount := len(memberships)
	if memberCount == 0 {
		memberCount = 1
	}

	equalShare := totalCents / memberCount
	if totalCents%memberCount != 0 {
		equalShare++ // round up
	}

	return &CostSummary{
		TotalCents:      totalCents,
		EqualShareCents: equalShare,
	}, nil
}

// GenerateExpenseFromList creates an expense from a list's cost summary.
func (s *ListService) GenerateExpenseFromList(ctx context.Context, user *models.User, listID uuid.UUID, description string) (*models.Expense, error) {
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

	totalCents, _, _, err := s.listRepo.CostSummary(ctx, listID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cost summary: %w", err)
	}
	if totalCents == 0 {
		return nil, &api.ValidationError{Field: "list", Message: "list has no priced items"}
	}

	expense := &models.Expense{
		GroupID:     list.GroupID,
		PayerID:     user.ID,
		Amount:      int64(totalCents),
		Currency:    "USD",
		Description: description,
		Category:    "groceries",
	}
	if expense.Description == "" {
		expense.Description = "Shopping: " + list.Name
	}

	return expense, nil
}

// ShoppingTripList groups full list items by list for a shopping trip.
type ShoppingTripList struct {
	ListID   uuid.UUID         `json:"list_id"`
	ListName string            `json:"list_name"`
	Items    []models.ListItem `json:"items"`
}

// GetShoppingTrip combines items from multiple lists into a grouped shopping trip.
func (s *ListService) GetShoppingTrip(ctx context.Context, user *models.User, listIDs []uuid.UUID) ([]ShoppingTripList, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}

	var result []ShoppingTripList
	for _, listID := range listIDs {
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

		items, err := s.listRepo.ListItemsByList(ctx, listID, 0, 0)
		if err != nil {
			return nil, fmt.Errorf("failed to list items: %w", err)
		}

		result = append(result, ShoppingTripList{
			ListID:   list.ID,
			ListName: list.Name,
			Items:    items,
		})
	}

	return result, nil
}

// BulkCompleteItems marks multiple list items as checked.
func (s *ListService) BulkCompleteItems(ctx context.Context, user *models.User, itemIDs []uuid.UUID) (int, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return 0, err
	}

	completed := 0
	for _, itemID := range itemIDs {
		item, err := s.listRepo.GetItemByID(ctx, itemID)
		if err != nil {
			if err == pgx.ErrNoRows {
				continue
			}
			return completed, fmt.Errorf("failed to get item: %w", err)
		}

		list, err := s.listRepo.GetListByID(ctx, item.ListID)
		if err != nil {
			return completed, fmt.Errorf("failed to get list: %w", err)
		}
		if err := s.requireMembership(ctx, user.ID, list.GroupID); err != nil {
			return completed, err
		}

		item.Checked = true
		if err := s.listRepo.UpdateItem(ctx, item); err != nil {
			return completed, fmt.Errorf("failed to update item: %w", err)
		}
		completed++
	}

	return completed, nil
}

// SetListArchived archives or unarchives a list.
func (s *ListService) SetListArchived(ctx context.Context, listID uuid.UUID, archived bool) error {
	return s.listRepo.SetListArchived(ctx, listID, archived)
}

func (s *ListService) ListRepo() repositories.ListRepo {
	return s.listRepo
}
