package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockLivingRepo is a mock implementation of repositories.LivingRepo.
type MockLivingRepo struct {
	mock.Mock
}

func (m *MockLivingRepo) CreateLivingThing(ctx context.Context, lt *models.LivingThing) (*models.LivingThing, error) {
	args := m.Called(ctx, lt)
	if l := args.Get(0); l != nil {
		return l.(*models.LivingThing), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) GetLivingThingByID(ctx context.Context, id uuid.UUID) (*models.LivingThing, error) {
	args := m.Called(ctx, id)
	if l := args.Get(0); l != nil {
		return l.(*models.LivingThing), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) ListLivingThingsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.LivingThing, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if l := args.Get(0); l != nil {
		return l.([]models.LivingThing), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) UpdateLivingThing(ctx context.Context, lt *models.LivingThing) (*models.LivingThing, error) {
	args := m.Called(ctx, lt)
	if l := args.Get(0); l != nil {
		return l.(*models.LivingThing), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) DeleteLivingThing(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockLivingRepo) CreateCareSchedule(ctx context.Context, cs *models.CareSchedule) (*models.CareSchedule, error) {
	args := m.Called(ctx, cs)
	if c := args.Get(0); c != nil {
		return c.(*models.CareSchedule), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) GetCareSchedule(ctx context.Context, id uuid.UUID) (*models.CareSchedule, error) {
	args := m.Called(ctx, id)
	if c := args.Get(0); c != nil {
		return c.(*models.CareSchedule), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) GetCareScheduleByLivingThingID(ctx context.Context, livingThingID uuid.UUID) (*models.CareSchedule, error) {
	args := m.Called(ctx, livingThingID)
	if c := args.Get(0); c != nil {
		return c.(*models.CareSchedule), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) UpdateCareSchedule(ctx context.Context, cs *models.CareSchedule) (*models.CareSchedule, error) {
	args := m.Called(ctx, cs)
	if c := args.Get(0); c != nil {
		return c.(*models.CareSchedule), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) CreateCareLog(ctx context.Context, cl *models.CareLog) (*models.CareLog, error) {
	args := m.Called(ctx, cl)
	if c := args.Get(0); c != nil {
		return c.(*models.CareLog), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) ListCareLogs(ctx context.Context, careScheduleID uuid.UUID, limit, offset int) ([]models.CareLog, error) {
	args := m.Called(ctx, careScheduleID, limit, offset)
	if c := args.Get(0); c != nil {
		return c.([]models.CareLog), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) CreateSpeciesWiki(ctx context.Context, sw *models.SpeciesWiki) (*models.SpeciesWiki, error) {
	args := m.Called(ctx, sw)
	if s := args.Get(0); s != nil {
		return s.(*models.SpeciesWiki), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockLivingRepo) GetSpeciesWiki(ctx context.Context, id uuid.UUID) (*models.SpeciesWiki, error) {
	args := m.Called(ctx, id)
	if s := args.Get(0); s != nil {
		return s.(*models.SpeciesWiki), args.Error(1)
	}
	return nil, args.Error(1)
}
