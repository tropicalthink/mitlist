package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
)

// MockPinwallRepo is a mock implementation of repositories.PinwallRepo.
type MockPinwallRepo struct {
	mock.Mock
}

func (m *MockPinwallRepo) CreatePost(ctx context.Context, p *models.PinwallPost) error {
	args := m.Called(ctx, p)
	return args.Error(0)
}

func (m *MockPinwallRepo) ListPostsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if v := args.Get(0); v != nil {
		return v.([]models.PinwallPost), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockPinwallRepo) GetPostByID(ctx context.Context, id uuid.UUID) (*models.PinwallPost, error) {
	args := m.Called(ctx, id)
	if v := args.Get(0); v != nil {
		return v.(*models.PinwallPost), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockPinwallRepo) DeletePost(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockPinwallRepo) UpdatePostPosition(ctx context.Context, id uuid.UUID, x, y float64) error {
	args := m.Called(ctx, id, x, y)
	return args.Error(0)
}

func (m *MockPinwallRepo) UpdatePost(ctx context.Context, id uuid.UUID, content string, color, size *string) error {
	args := m.Called(ctx, id, content, color, size)
	return args.Error(0)
}
