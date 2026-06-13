package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/mitlist-app/mitlist/internal/models"
)

// MockListRepo is a mock implementation of repositories.ListRepo.
type MockListRepo struct {
	mock.Mock
}

func (m *MockListRepo) CreateList(ctx context.Context, list *models.List) error {
	args := m.Called(ctx, list)
	return args.Error(0)
}

func (m *MockListRepo) GetListByID(ctx context.Context, id uuid.UUID) (*models.List, error) {
	args := m.Called(ctx, id)
	if l := args.Get(0); l != nil {
		return l.(*models.List), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) GetListsByIDs(ctx context.Context, ids []uuid.UUID) ([]models.List, error) {
	args := m.Called(ctx, ids)
	if l := args.Get(0); l != nil {
		return l.([]models.List), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) ListListsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.List, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if l := args.Get(0); l != nil {
		return l.([]models.List), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) ListItemPreviewLinesByListIDs(ctx context.Context, listIDs []uuid.UUID, perList int) (map[uuid.UUID][]string, error) {
	args := m.Called(ctx, listIDs, perList)
	if v := args.Get(0); v != nil {
		return v.(map[uuid.UUID][]string), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) UpdateList(ctx context.Context, list *models.List) error {
	args := m.Called(ctx, list)
	return args.Error(0)
}

func (m *MockListRepo) HardDeleteList(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockListRepo) CreateItem(ctx context.Context, item *models.ListItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockListRepo) CreateItems(ctx context.Context, items []models.ListItem) error {
	args := m.Called(ctx, items)
	return args.Error(0)
}

func (m *MockListRepo) BulkMarkItemsChecked(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int64, error) {
	args := m.Called(ctx, userID, itemIDs)
	return args.Get(0).(int64), args.Error(1)
}

func (m *MockListRepo) GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error) {
	args := m.Called(ctx, id)
	if i := args.Get(0); i != nil {
		return i.(*models.ListItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) GetItemByListNameUnit(ctx context.Context, listID uuid.UUID, name, unit string) (*models.ListItem, error) {
	args := m.Called(ctx, listID, name, unit)
	if i := args.Get(0); i != nil {
		return i.(*models.ListItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) ListItemsByList(ctx context.Context, listID uuid.UUID, limit, offset int) ([]models.ListItem, error) {
	args := m.Called(ctx, listID, limit, offset)
	if i := args.Get(0); i != nil {
		return i.([]models.ListItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) ListItemsByListIDs(ctx context.Context, listIDs []uuid.UUID) (map[uuid.UUID][]models.ListItem, error) {
	args := m.Called(ctx, listIDs)
	if i := args.Get(0); i != nil {
		return i.(map[uuid.UUID][]models.ListItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) UpdateItem(ctx context.Context, item *models.ListItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockListRepo) HardDeleteItem(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockListRepo) SoftDeleteItem(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockListRepo) SoftDeleteItemsByList(ctx context.Context, listID uuid.UUID, onlyChecked bool) (int64, error) {
	args := m.Called(ctx, listID, onlyChecked)
	return int64(args.Int(0)), args.Error(1)
}

func (m *MockListRepo) BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error {
	args := m.Called(ctx, items)
	return args.Error(0)
}

func (m *MockListRepo) CreateShoppingLocation(ctx context.Context, location *models.ShoppingLocation) error {
	args := m.Called(ctx, location)
	return args.Error(0)
}

func (m *MockListRepo) ListShoppingLocationsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.ShoppingLocation, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.([]models.ShoppingLocation), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) CreateProduct(ctx context.Context, product *models.Product) error {
	args := m.Called(ctx, product)
	return args.Error(0)
}

func (m *MockListRepo) ListProductsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Product, error) {
	args := m.Called(ctx, groupID)
	if v := args.Get(0); v != nil {
		return v.([]models.Product), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) SearchProducts(ctx context.Context, groupID uuid.UUID, query string, limit int) ([]models.Product, error) {
	args := m.Called(ctx, groupID, query, limit)
	if v := args.Get(0); v != nil {
		return v.([]models.Product), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockListRepo) ClaimItem(ctx context.Context, itemID uuid.UUID, userID uuid.UUID) error {
	args := m.Called(ctx, itemID, userID)
	return args.Error(0)
}

func (m *MockListRepo) SetListArchived(ctx context.Context, id uuid.UUID, archived bool) error {
	args := m.Called(ctx, id, archived)
	return args.Error(0)
}

func (m *MockListRepo) UnclaimItem(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockListRepo) CostSummary(ctx context.Context, listID uuid.UUID) (int, int, map[uuid.UUID]int, error) {
	args := m.Called(ctx, listID)
	return args.Int(0), args.Int(1), args.Get(2).(map[uuid.UUID]int), args.Error(3)
}
