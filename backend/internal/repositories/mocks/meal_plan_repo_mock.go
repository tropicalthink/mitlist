package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
)

// MockMealPlanRepo is a mock implementation of repositories.MealPlanRepoIface.
type MockMealPlanRepo struct {
	mock.Mock
}

func (m *MockMealPlanRepo) CreateMealPlan(ctx context.Context, mp *models.MealPlan) error {
	args := m.Called(ctx, mp)
	return args.Error(0)
}

func (m *MockMealPlanRepo) GetMealPlanByID(ctx context.Context, id uuid.UUID) (*models.MealPlan, error) {
	args := m.Called(ctx, id)
	if v := args.Get(0); v != nil {
		return v.(*models.MealPlan), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockMealPlanRepo) ListMealPlansByGroup(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	args := m.Called(ctx, groupID, from, to)
	if v := args.Get(0); v != nil {
		return v.([]models.MealPlan), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockMealPlanRepo) UpdateMealPlan(ctx context.Context, mp *models.MealPlan) error {
	args := m.Called(ctx, mp)
	return args.Error(0)
}

func (m *MockMealPlanRepo) DeleteMealPlan(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
