package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// AssistantService provides business logic for AI assistant chat sessions.
type AssistantService struct {
	assistantRepo repositories.AssistantRepo
	aiClient      AIClient
}

// NewAssistantService creates a new AssistantService.
func NewAssistantService(assistantRepo repositories.AssistantRepo, aiClient AIClient) *AssistantService {
	return &AssistantService{
		assistantRepo: assistantRepo,
		aiClient:      aiClient,
	}
}

// CreateSession creates a new chat session for a user.
func (s *AssistantService) CreateSession(ctx context.Context, userID uuid.UUID, title string) (*models.ChatSession, error) {
	session := &models.ChatSession{
		UserID: userID,
		Title:  title,
	}
	return s.assistantRepo.CreateSession(ctx, session)
}

// GetSession retrieves a session by ID, enforcing ownership.
func (s *AssistantService) GetSession(ctx context.Context, userID, sessionID uuid.UUID) (*models.ChatSession, error) {
	session, err := s.assistantRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		if err == repositories.ErrSessionNotFound {
			return nil, &api.NotFoundError{Resource: "chat session", ID: sessionID.String()}
		}
		return nil, err
	}
	if session.UserID != userID {
		return nil, &api.PermissionDeniedError{Action: "view session"}
	}
	return session, nil
}

// ListSessions returns paginated sessions for a user.
func (s *AssistantService) ListSessions(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.ChatSession, error) {
	return s.assistantRepo.ListSessionsByUser(ctx, userID, limit, offset)
}

// UpdateSession updates a session title, enforcing ownership.
func (s *AssistantService) UpdateSession(ctx context.Context, userID, sessionID uuid.UUID, title string) (*models.ChatSession, error) {
	session, err := s.assistantRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		if err == repositories.ErrSessionNotFound {
			return nil, &api.NotFoundError{Resource: "chat session", ID: sessionID.String()}
		}
		return nil, err
	}
	if session.UserID != userID {
		return nil, &api.PermissionDeniedError{Action: "update session"}
	}
	session.Title = title
	return s.assistantRepo.UpdateSession(ctx, session)
}

// DeleteSession deletes a session and its messages, enforcing ownership.
func (s *AssistantService) DeleteSession(ctx context.Context, userID, sessionID uuid.UUID) error {
	session, err := s.assistantRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		if err == repositories.ErrSessionNotFound {
			return &api.NotFoundError{Resource: "chat session", ID: sessionID.String()}
		}
		return err
	}
	if session.UserID != userID {
		return &api.PermissionDeniedError{Action: "delete session"}
	}
	return s.assistantRepo.DeleteSession(ctx, sessionID)
}

// SendMessage sends a user message, gets an AI response, and stores both.
func (s *AssistantService) SendMessage(ctx context.Context, userID, sessionID uuid.UUID, content string) (*models.ChatMessage, error) {
	session, err := s.assistantRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		if err == repositories.ErrSessionNotFound {
			return nil, &api.NotFoundError{Resource: "chat session", ID: sessionID.String()}
		}
		return nil, err
	}
	if session.UserID != userID {
		return nil, &api.PermissionDeniedError{Action: "send message to session"}
	}

	// Store user message.
	userMsg := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "user",
		Content:   content,
	}
	if _, err := s.assistantRepo.CreateMessage(ctx, userMsg); err != nil {
		return nil, fmt.Errorf("create user message: %w", err)
	}

	// Generate AI response.
	aiContent, err := s.aiClient.Generate(content, "gemini-1.5-flash")
	if err != nil {
		return nil, fmt.Errorf("ai generation: %w", err)
	}

	// Store AI message.
	aiMsg := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "assistant",
		Content:   aiContent,
	}
	return s.assistantRepo.CreateMessage(ctx, aiMsg)
}

// ListMessages returns paginated messages for a session, enforcing ownership.
func (s *AssistantService) ListMessages(ctx context.Context, userID, sessionID uuid.UUID, limit, offset int) ([]models.ChatMessage, error) {
	session, err := s.assistantRepo.GetSessionByID(ctx, sessionID)
	if err != nil {
		if err == repositories.ErrSessionNotFound {
			return nil, &api.NotFoundError{Resource: "chat session", ID: sessionID.String()}
		}
		return nil, err
	}
	if session.UserID != userID {
		return nil, &api.PermissionDeniedError{Action: "list messages"}
	}
	return s.assistantRepo.ListMessagesBySession(ctx, sessionID, limit, offset)
}
