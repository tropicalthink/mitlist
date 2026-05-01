package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestAssistantService_CreateSession(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		svc := NewAssistantService(assistantRepo, nil)

		assistantRepo.On("CreateSession", ctx, mock.AnythingOfType("*models.ChatSession")).Return(&models.ChatSession{ID: uuid.New(), UserID: userID, Title: "Test"}, nil)

		session, err := svc.CreateSession(ctx, userID, "Test")
		require.NoError(t, err)
		assert.Equal(t, userID, session.UserID)
	})
}

func TestAssistantService_GetSession(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	sessionID := uuid.New()

	t.Run("success owner", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		svc := NewAssistantService(assistantRepo, nil)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: userID}, nil)

		session, err := svc.GetSession(ctx, userID, sessionID)
		require.NoError(t, err)
		assert.Equal(t, sessionID, session.ID)
	})

	t.Run("wrong owner", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		svc := NewAssistantService(assistantRepo, nil)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: uuid.New()}, nil)

		_, err := svc.GetSession(ctx, userID, sessionID)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestAssistantService_DeleteSession(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	sessionID := uuid.New()

	t.Run("success", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		svc := NewAssistantService(assistantRepo, nil)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: userID}, nil)
		assistantRepo.On("DeleteSession", ctx, sessionID).Return(nil)

		err := svc.DeleteSession(ctx, userID, sessionID)
		require.NoError(t, err)
	})
}

func TestAssistantService_SendMessage(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	sessionID := uuid.New()

	t.Run("success", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		aiClient := new(mocks.MockAIClient)
		svc := NewAssistantService(assistantRepo, aiClient)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: userID}, nil)
		assistantRepo.On("CreateMessage", ctx, mock.MatchedBy(func(m *models.ChatMessage) bool { return m.Role == "user" })).Return(&models.ChatMessage{ID: uuid.New()}, nil)
		aiClient.On("Generate", "hello", "gemini-1.5-flash").Return("hi there", nil)
		assistantRepo.On("CreateMessage", ctx, mock.MatchedBy(func(m *models.ChatMessage) bool { return m.Role == "assistant" })).Return(&models.ChatMessage{ID: uuid.New(), Role: "assistant", Content: "hi there"}, nil)

		msg, err := svc.SendMessage(ctx, userID, sessionID, "hello")
		require.NoError(t, err)
		assert.Equal(t, "assistant", msg.Role)
		assert.Equal(t, "hi there", msg.Content)
	})

	t.Run("ai error", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		aiClient := new(mocks.MockAIClient)
		svc := NewAssistantService(assistantRepo, aiClient)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: userID}, nil)
		assistantRepo.On("CreateMessage", ctx, mock.AnythingOfType("*models.ChatMessage")).Return(&models.ChatMessage{ID: uuid.New()}, nil)
		aiClient.On("Generate", "hello", "gemini-1.5-flash").Return("", errors.New("ai failed"))

		_, err := svc.SendMessage(ctx, userID, sessionID, "hello")
		require.Error(t, err)
	})
}

func TestAssistantService_ListMessages(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	sessionID := uuid.New()

	t.Run("success", func(t *testing.T) {
		assistantRepo := new(mocks.MockAssistantRepo)
		svc := NewAssistantService(assistantRepo, nil)

		assistantRepo.On("GetSessionByID", ctx, sessionID).Return(&models.ChatSession{ID: sessionID, UserID: userID}, nil)
		assistantRepo.On("ListMessagesBySession", ctx, sessionID, 10, 0).Return([]models.ChatMessage{{ID: uuid.New()}}, nil)

		msgs, err := svc.ListMessages(ctx, userID, sessionID, 10, 0)
		require.NoError(t, err)
		assert.Len(t, msgs, 1)
	})
}
