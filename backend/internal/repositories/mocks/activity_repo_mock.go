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

func (m *MockActivityRepo) ListRecentActivity(ctx context.Context, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error) {
	args := m.Called(ctx, groupID, limit)
	if a := args.Get(0); a != nil {
		return a.([]models.ActivityEvent), args.Error(1)
	}
	return nil, args.Error(1)
}
