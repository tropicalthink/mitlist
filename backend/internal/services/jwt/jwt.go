package jwt

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	golangjwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/config"
)

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"

	refreshTokenLifetime = 7 * 24 * time.Hour
	sessionTimeout       = 5 * time.Second
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrRevokedToken = errors.New("revoked token")
)

type Claims struct {
	Roles     []string `json:"roles,omitempty"`
	TokenType string   `json:"typ"`
	golangjwt.RegisteredClaims
}

type RefreshSession struct {
	JTI       string
	UserID    uuid.UUID
	Roles     []string
	ExpiresAt time.Time
}

type RefreshSessionStore interface {
	Store(ctx context.Context, session RefreshSession) error
	IsActive(ctx context.Context, jti string) (bool, error)
	Revoke(ctx context.Context, jti string) error
}

type postgresSessionStore struct{ db *pgxpool.Pool }

func (s *postgresSessionStore) Store(ctx context.Context, session RefreshSession) error {
	roles, err := json.Marshal(session.Roles)
	if err != nil {
		return fmt.Errorf("marshal refresh session roles: %w", err)
	}
	// Opportunistic cleanup keeps the table bounded without another service.
	_, _ = s.db.Exec(ctx, `DELETE FROM auth_sessions WHERE expires_at <= NOW()`)
	_, err = s.db.Exec(ctx, `
		INSERT INTO auth_sessions (jti, user_id, roles, expires_at)
		VALUES ($1, $2, $3, $4)
	`, session.JTI, session.UserID, roles, session.ExpiresAt)
	if err != nil {
		return fmt.Errorf("store refresh session: %w", err)
	}
	return nil
}

func (s *postgresSessionStore) IsActive(ctx context.Context, jti string) (bool, error) {
	var active bool
	err := s.db.QueryRow(ctx, `
		SELECT revoked_at IS NULL AND expires_at > NOW()
		FROM auth_sessions WHERE jti = $1
	`, jti).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("check refresh session: %w", err)
	}
	return active, nil
}

func (s *postgresSessionStore) Revoke(ctx context.Context, jti string) error {
	_, err := s.db.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE jti = $1`, jti)
	if err != nil {
		return fmt.Errorf("revoke refresh session: %w", err)
	}
	return nil
}

type Service struct {
	cfg      *config.Config
	sessions RefreshSessionStore

	revokedMu     sync.Mutex
	revokedAccess map[string]time.Time
}

func New(cfg *config.Config, db *pgxpool.Pool) *Service {
	var store RefreshSessionStore
	if db != nil {
		store = &postgresSessionStore{db: db}
	}
	return NewWithStore(cfg, store)
}

func NewWithStore(cfg *config.Config, store RefreshSessionStore) *Service {
	return &Service{cfg: cfg, sessions: store, revokedAccess: make(map[string]time.Time)}
}

func (s *Service) GenerateTokenPair(userID string, roles []string) (access, refresh string, err error) {
	now := time.Now().UTC()
	accessTTL := s.accessTokenLifetime()
	accessClaims := s.newClaims(userID, roles, TokenTypeAccess, now, now.Add(accessTTL))
	refreshClaims := s.newClaims(userID, roles, TokenTypeRefresh, now, now.Add(refreshTokenLifetime))

	access, err = s.sign(accessClaims)
	if err != nil {
		return "", "", err
	}
	refresh, err = s.sign(refreshClaims)
	if err != nil {
		return "", "", err
	}
	if err := s.storeRefreshSession(refreshClaims); err != nil {
		return "", "", err
	}
	return access, refresh, nil
}

func (s *Service) ValidateAccessToken(token string) (*Claims, error) {
	claims, err := s.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeAccess {
		return nil, ErrInvalidToken
	}
	if s.isAccessRevoked(claims.ID) {
		return nil, ErrRevokedToken
	}
	return claims, nil
}

func (s *Service) ValidateRefreshToken(token string) (*Claims, error) {
	claims, err := s.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeRefresh || s.sessions == nil {
		return nil, ErrInvalidToken
	}
	ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
	defer cancel()
	active, err := s.sessions.IsActive(ctx, claims.ID)
	if err != nil {
		return nil, fmt.Errorf("check refresh session: %w", err)
	}
	if !active {
		return nil, ErrRevokedToken
	}
	return claims, nil
}

func (s *Service) RevokeRefreshToken(jti string) error {
	if s.sessions == nil {
		return ErrInvalidToken
	}
	ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
	defer cancel()
	return s.sessions.Revoke(ctx, jti)
}

func (s *Service) RevokeAccessToken(jti string) error {
	s.revokedMu.Lock()
	defer s.revokedMu.Unlock()
	s.revokedAccess[jti] = time.Now().Add(s.accessTokenLifetime())
	return nil
}

func (s *Service) ParseAccessToken(token string) (*Claims, error) { return s.parse(token) }

func (s *Service) accessTokenLifetime() time.Duration {
	ttl := time.Duration(s.cfg.AccessTokenExpireMinutes) * time.Minute
	if ttl <= 0 {
		return 15 * time.Minute
	}
	return ttl
}

func (s *Service) isAccessRevoked(jti string) bool {
	s.revokedMu.Lock()
	defer s.revokedMu.Unlock()
	now := time.Now()
	for id, expiresAt := range s.revokedAccess {
		if !expiresAt.After(now) {
			delete(s.revokedAccess, id)
		}
	}
	_, revoked := s.revokedAccess[jti]
	return revoked
}

func (s *Service) newClaims(userID string, roles []string, tokenType string, issuedAt, expiresAt time.Time) *Claims {
	return &Claims{
		Roles: roles, TokenType: tokenType,
		RegisteredClaims: golangjwt.RegisteredClaims{
			ID: uuid.NewString(), Subject: userID,
			IssuedAt: golangjwt.NewNumericDate(issuedAt), NotBefore: golangjwt.NewNumericDate(issuedAt),
			ExpiresAt: golangjwt.NewNumericDate(expiresAt),
		},
	}
}

func (s *Service) sign(claims *Claims) (string, error) {
	token := golangjwt.NewWithClaims(golangjwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(s.cfg.SecretKey))
	if err != nil {
		return "", fmt.Errorf("sign token: %w", err)
	}
	return signed, nil
}

func (s *Service) parse(token string) (*Claims, error) {
	claims := &Claims{}
	parsed, err := golangjwt.ParseWithClaims(token, claims, func(token *golangjwt.Token) (interface{}, error) {
		if token.Method != golangjwt.SigningMethodHS256 {
			return nil, ErrInvalidToken
		}
		return []byte(s.cfg.SecretKey), nil
	})
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalidToken, err)
	}
	if !parsed.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

func (s *Service) storeRefreshSession(claims *Claims) error {
	if s.sessions == nil {
		return errors.New("refresh session store is not configured")
	}
	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return ErrInvalidToken
	}
	expiresAt, err := claims.GetExpirationTime()
	if err != nil || expiresAt == nil {
		return ErrInvalidToken
	}
	ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
	defer cancel()
	return s.sessions.Store(ctx, RefreshSession{
		JTI: claims.ID, UserID: userID, Roles: claims.Roles, ExpiresAt: expiresAt.Time,
	})
}
