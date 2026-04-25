package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockAssistantRepo is a mock implementation of repositories.AssistantRepo.
type MockAssistantRepo struct {
	mock.Mock
}

func (m *MockAssistantRepo) CreateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error) {
	args := m.Called(ctx, s)
	if ss := args.Get(0); ss != nil {
		return ss.(*models.ChatSession), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAssistantRepo) GetSessionByID(ctx context.Context, id uuid.UUID) (*models.ChatSession, error) {
	args := m.Called(ctx, id)
	if s := args.Get(0); s != nil {
		return s.(*models.ChatSession), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAssistantRepo) ListSessionsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.ChatSession, error) {
	args := m.Called(ctx, userID, limit, offset)
	if s := args.Get(0); s != nil {
		return s.([]models.ChatSession), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAssistantRepo) UpdateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error) {
	args := m.Called(ctx, s)
	if ss := args.Get(0); ss != nil {
		return ss.(*models.ChatSession), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAssistantRepo) DeleteSession(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockAssistantRepo) CreateMessage(ctx context.Context, msg *models.ChatMessage) (*models.ChatMessage, error) {
	args := m.Called(ctx, msg)
	if mm := args.Get(0); mm != nil {
		return mm.(*models.ChatMessage), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAssistantRepo) ListMessagesBySession(ctx context.Context, sessionID uuid.UUID, limit, offset int) ([]models.ChatMessage, error) {
	args := m.Called(ctx, sessionID, limit, offset)
	if mm := args.Get(0); mm != nil {
		return mm.([]models.ChatMessage), args.Error(1)
	}
	return nil, args.Error(1)
}
