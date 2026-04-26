package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
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

func (m *MockListRepo) GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error) {
	args := m.Called(ctx, id)
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

func (m *MockListRepo) BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error {
	args := m.Called(ctx, items)
	return args.Error(0)
}
