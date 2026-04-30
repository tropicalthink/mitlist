package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockChoreRepo is a mock implementation of repositories.ChoreRepo.
type MockChoreRepo struct {
	mock.Mock
}

func (m *MockChoreRepo) CreateChore(ctx context.Context, chore *models.Chore) error {
	args := m.Called(ctx, chore)
	return args.Error(0)
}

func (m *MockChoreRepo) GetChoreByID(ctx context.Context, id uuid.UUID) (*models.Chore, error) {
	args := m.Called(ctx, id)
	if c := args.Get(0); c != nil {
		return c.(*models.Chore), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) ListChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Chore, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if c := args.Get(0); c != nil {
		return c.([]models.Chore), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) ListCurrentChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.CurrentChore, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if c := args.Get(0); c != nil {
		return c.([]models.CurrentChore), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) GetChoreStats(ctx context.Context, choreID uuid.UUID) (*models.ChoreStats, error) {
	args := m.Called(ctx, choreID)
	if s := args.Get(0); s != nil {
		return s.(*models.ChoreStats), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) UpdateChore(ctx context.Context, chore *models.Chore) error {
	args := m.Called(ctx, chore)
	return args.Error(0)
}

func (m *MockChoreRepo) DeleteChore(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockChoreRepo) CreateRotationState(ctx context.Context, state *models.ChoreRotationState) error {
	args := m.Called(ctx, state)
	return args.Error(0)
}

func (m *MockChoreRepo) GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error) {
	args := m.Called(ctx, choreID)
	if s := args.Get(0); s != nil {
		return s.(*models.ChoreRotationState), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) UpdateRotationState(ctx context.Context, state *models.ChoreRotationState) error {
	args := m.Called(ctx, state)
	return args.Error(0)
}

func (m *MockChoreRepo) BulkUpdateRotationStates(ctx context.Context, states []models.ChoreRotationState) error {
	args := m.Called(ctx, states)
	return args.Error(0)
}

func (m *MockChoreRepo) CreateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error {
	args := m.Called(ctx, assignment)
	return args.Error(0)
}

func (m *MockChoreRepo) ListAssignments(ctx context.Context, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error) {
	args := m.Called(ctx, choreID, limit, offset)
	if a := args.Get(0); a != nil {
		return a.([]models.ChoreAssignment), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) UpdateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error {
	args := m.Called(ctx, assignment)
	return args.Error(0)
}

func (m *MockChoreRepo) DeleteAssignment(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockChoreRepo) CreateCompletion(ctx context.Context, completion *models.ChoreCompletion) error {
	args := m.Called(ctx, completion)
	return args.Error(0)
}

func (m *MockChoreRepo) GetPendingAssignmentByChore(ctx context.Context, choreID uuid.UUID) (*models.ChoreAssignment, error) {
	args := m.Called(ctx, choreID)
	if a := args.Get(0); a != nil {
		return a.(*models.ChoreAssignment), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) ListDueAssignments(ctx context.Context, from, to time.Time) ([]models.ChoreAssignment, error) {
	args := m.Called(ctx, from, to)
	if a := args.Get(0); a != nil {
		return a.([]models.ChoreAssignment), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) CreateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error {
	args := m.Called(ctx, subtask)
	return args.Error(0)
}

func (m *MockChoreRepo) GetSubtaskByID(ctx context.Context, id uuid.UUID) (*models.ChoreSubtask, error) {
	args := m.Called(ctx, id)
	if s := args.Get(0); s != nil {
		return s.(*models.ChoreSubtask), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) ListSubtasksByChore(ctx context.Context, choreID uuid.UUID) ([]models.ChoreSubtask, error) {
	args := m.Called(ctx, choreID)
	if s := args.Get(0); s != nil {
		return s.([]models.ChoreSubtask), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockChoreRepo) UpdateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error {
	args := m.Called(ctx, subtask)
	return args.Error(0)
}

func (m *MockChoreRepo) DeleteSubtask(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockChoreRepo) DeleteSubtasksByChore(ctx context.Context, choreID uuid.UUID) error {
	args := m.Called(ctx, choreID)
	return args.Error(0)
}
