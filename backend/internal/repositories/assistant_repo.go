package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

var (
	ErrSessionNotFound = errors.New("chat session not found")
	ErrMessageNotFound = errors.New("chat message not found")
)

// AssistantRepository provides data access for AI assistant chat sessions
// and messages.
type AssistantRepository struct {
	pool DBTX
}

// NewAssistantRepository creates a new AssistantRepository.
func NewAssistantRepository(pool DBTX) *AssistantRepository {
	return &AssistantRepository{pool: pool}
}

// ---------------------------------------------------------------------------
// ChatSession
// ---------------------------------------------------------------------------

// CreateSession inserts a new chat session and returns the created record.
func (r *AssistantRepository) CreateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error) {
	query := `
		INSERT INTO chat_sessions (id, user_id, title, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, user_id, title, created_at, updated_at
	`

	now := time.Now().UTC()
	s.ID = uuid.New()
	s.CreatedAt = now
	s.UpdatedAt = now

	row := r.pool.QueryRow(ctx, query, s.ID, s.UserID, s.Title, s.CreatedAt, s.UpdatedAt)

	var created models.ChatSession
	if err := row.Scan(&created.ID, &created.UserID, &created.Title, &created.CreatedAt, &created.UpdatedAt); err != nil {
		return nil, fmt.Errorf("create session: %w", err)
	}
	return &created, nil
}

// GetSessionByID retrieves a chat session by its ID.
func (r *AssistantRepository) GetSessionByID(ctx context.Context, id uuid.UUID) (*models.ChatSession, error) {
	query := `
		SELECT id, user_id, title, created_at, updated_at
		FROM chat_sessions
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var s models.ChatSession
	if err := row.Scan(&s.ID, &s.UserID, &s.Title, &s.CreatedAt, &s.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionNotFound
		}
		return nil, fmt.Errorf("get session: %w", err)
	}
	return &s, nil
}

// ListSessionsByUser returns paginated chat sessions for a user.
func (r *AssistantRepository) ListSessionsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.ChatSession, error) {
	if limit <= 0 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, user_id, title, created_at, updated_at
		FROM chat_sessions
		WHERE user_id = $1
		ORDER BY updated_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list sessions: %w", err)
	}
	defer rows.Close()

	return scanChatSessions(rows)
}

// UpdateSession updates an existing chat session.
func (r *AssistantRepository) UpdateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error) {
	query := `
		UPDATE chat_sessions
		SET title = $1, updated_at = $2
		WHERE id = $3
		RETURNING id, user_id, title, created_at, updated_at
	`

	s.UpdatedAt = time.Now().UTC()

	row := r.pool.QueryRow(ctx, query, s.Title, s.UpdatedAt, s.ID)

	var updated models.ChatSession
	if err := row.Scan(&updated.ID, &updated.UserID, &updated.Title, &updated.CreatedAt, &updated.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionNotFound
		}
		return nil, fmt.Errorf("update session: %w", err)
	}
	return &updated, nil
}

// DeleteSession hard-deletes a chat session and its messages by ID.
func (r *AssistantRepository) DeleteSession(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM chat_sessions WHERE id = $1`

	cmd, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("delete session: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return ErrSessionNotFound
	}
	return nil
}

// ---------------------------------------------------------------------------
// ChatMessage
// ---------------------------------------------------------------------------

// CreateMessage inserts a new chat message and returns the created record.
func (r *AssistantRepository) CreateMessage(ctx context.Context, m *models.ChatMessage) (*models.ChatMessage, error) {
	query := `
		INSERT INTO chat_messages (id, session_id, role, content, created_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, session_id, role, content, created_at
	`

	m.ID = uuid.New()
	m.CreatedAt = time.Now().UTC()

	row := r.pool.QueryRow(ctx, query, m.ID, m.SessionID, m.Role, m.Content, m.CreatedAt)

	var created models.ChatMessage
	if err := row.Scan(&created.ID, &created.SessionID, &created.Role, &created.Content, &created.CreatedAt); err != nil {
		return nil, fmt.Errorf("create message: %w", err)
	}
	return &created, nil
}

// ListMessagesBySession returns paginated messages for a chat session.
func (r *AssistantRepository) ListMessagesBySession(ctx context.Context, sessionID uuid.UUID, limit, offset int) ([]models.ChatMessage, error) {
	if limit <= 0 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, session_id, role, content, created_at
		FROM chat_messages
		WHERE session_id = $1
		ORDER BY created_at ASC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, sessionID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list messages: %w", err)
	}
	defer rows.Close()

	return scanChatMessages(rows)
}

// ---------------------------------------------------------------------------
// Scanners
// ---------------------------------------------------------------------------

func scanChatSessions(rows pgx.Rows) ([]models.ChatSession, error) {
	var items []models.ChatSession
	for rows.Next() {
		var s models.ChatSession
		if err := rows.Scan(&s.ID, &s.UserID, &s.Title, &s.CreatedAt, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan session: %w", err)
		}
		items = append(items, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate sessions: %w", err)
	}
	return items, nil
}

func scanChatMessages(rows pgx.Rows) ([]models.ChatMessage, error) {
	var items []models.ChatMessage
	for rows.Next() {
		var m models.ChatMessage
		if err := rows.Scan(&m.ID, &m.SessionID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan message: %w", err)
		}
		items = append(items, m)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate messages: %w", err)
	}
	return items, nil
}
