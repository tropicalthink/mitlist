package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/stretchr/testify/mock"
)

// MockTemplateRepo is a mock implementation of repositories.TemplateRepo.
type MockTemplateRepo struct {
	mock.Mock
}

func (m *MockTemplateRepo) CreateTemplate(ctx context.Context, template *models.Template) error {
	args := m.Called(ctx, template)
	return args.Error(0)
}

func (m *MockTemplateRepo) GetTemplateByID(ctx context.Context, id uuid.UUID) (*models.Template, error) {
	args := m.Called(ctx, id)
	if t := args.Get(0); t != nil {
		return t.(*models.Template), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockTemplateRepo) ListTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Template, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if t := args.Get(0); t != nil {
		return t.([]models.Template), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockTemplateRepo) UpdateTemplate(ctx context.Context, template *models.Template) error {
	args := m.Called(ctx, template)
	return args.Error(0)
}

func (m *MockTemplateRepo) DeleteTemplate(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockTemplateRepo) CreateTemplateItem(ctx context.Context, item *models.TemplateItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockTemplateRepo) ListTemplateItems(ctx context.Context, templateID uuid.UUID) ([]models.TemplateItem, error) {
	args := m.Called(ctx, templateID)
	if i := args.Get(0); i != nil {
		return i.([]models.TemplateItem), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockTemplateRepo) UpdateTemplateItem(ctx context.Context, item *models.TemplateItem) error {
	args := m.Called(ctx, item)
	return args.Error(0)
}

func (m *MockTemplateRepo) DeleteTemplateItem(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockTemplateRepo) CreateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error {
	args := m.Called(ctx, ct)
	return args.Error(0)
}

func (m *MockTemplateRepo) GetChoreTemplateByID(ctx context.Context, id uuid.UUID) (*models.ChoreTemplate, error) {
	args := m.Called(ctx, id)
	if ct := args.Get(0); ct != nil {
		return ct.(*models.ChoreTemplate), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockTemplateRepo) ListChoreTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ChoreTemplate, error) {
	args := m.Called(ctx, groupID, limit, offset)
	if ct := args.Get(0); ct != nil {
		return ct.([]models.ChoreTemplate), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockTemplateRepo) UpdateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error {
	args := m.Called(ctx, ct)
	return args.Error(0)
}

func (m *MockTemplateRepo) DeleteChoreTemplate(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
