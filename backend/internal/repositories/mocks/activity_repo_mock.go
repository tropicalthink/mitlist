package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockActivityRepo is a mock implementation of repositories.ActivityRepo.
type MockActivityRepo struct {
	mock.Mock
}

func (m *MockActivityRepo) LogActivity(ctx context.Context, a *models.ActivityLog) error {
	args := m.Called(ctx, a)
	return args.Error(0)
}

func (m *MockActivityRepo) GetActivityLogByID(ctx context.Context, id uuid.UUID) (*models.ActivityLog, error) {
	args := m.Called(ctx, id)
	if a := args.Get(0); a != nil {
		return a.(*models.ActivityLog), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockActivityRepo) ListActivityLogsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ActivityLog, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if a := args.Get(0); a != nil {
		return a.([]models.ActivityLog), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockActivityRepo) DeleteActivityLog(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
