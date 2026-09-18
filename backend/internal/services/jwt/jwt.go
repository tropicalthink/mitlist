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
	guestRefreshLifetime = 365 * 24 * time.Hour
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
	FamilyID  uuid.UUID
	UserID    uuid.UUID
	Roles     []string
	ExpiresAt time.Time
}

type RefreshSessionStore interface {
	Store(ctx context.Context, session RefreshSession) error
	IsActive(ctx context.Context, jti string) (bool, error)
	Revoke(ctx context.Context, jti string) error
	Rotate(ctx context.Context, oldJTI string, replacement RefreshSession) error
	RevokeUser(ctx context.Context, userID uuid.UUID) error
	RevokeAccess(ctx context.Context, jti string, expiresAt time.Time) error
	IsAccessActive(ctx context.Context, jti string, userID uuid.UUID, issuedAt time.Time) (bool, error)
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
		INSERT INTO auth_sessions (jti, family_id, user_id, roles, expires_at)
		VALUES ($1, $2, $3, $4, $5)
	`, session.JTI, session.FamilyID, session.UserID, roles, session.ExpiresAt)
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

func (s *postgresSessionStore) Rotate(ctx context.Context, oldJTI string, replacement RefreshSession) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin refresh rotation: %w", err)
	}
	defer tx.Rollback(ctx)
	var userID uuid.UUID
	var familyID uuid.UUID
	var active bool
	err = tx.QueryRow(ctx, `
		SELECT user_id, family_id, revoked_at IS NULL AND expires_at > NOW()
		FROM auth_sessions WHERE jti = $1 FOR UPDATE
	`, oldJTI).Scan(&userID, &familyID, &active)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrRevokedToken
	}
	if err != nil {
		return fmt.Errorf("lock refresh session: %w", err)
	}
	if !active {
		_, _ = tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE family_id = $1`, familyID)
		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("commit replay revocation: %w", err)
		}
		return ErrRevokedToken
	}
	if replacement.UserID != userID {
		return ErrInvalidToken
	}
	replacement.FamilyID = familyID
	roles, err := json.Marshal(replacement.Roles)
	if err != nil {
		return fmt.Errorf("marshal replacement roles: %w", err)
	}
	if _, err = tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE jti = $1 AND revoked_at IS NULL`, oldJTI); err != nil {
		return fmt.Errorf("consume refresh session: %w", err)
	}
	if _, err = tx.Exec(ctx, `
		INSERT INTO auth_sessions (jti, family_id, user_id, roles, expires_at)
		VALUES ($1, $2, $3, $4, $5)
	`, replacement.JTI, familyID, replacement.UserID, roles, replacement.ExpiresAt); err != nil {
		return fmt.Errorf("store rotated refresh session: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit refresh rotation: %w", err)
	}
	return nil
}

func (s *postgresSessionStore) RevokeUser(ctx context.Context, userID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `UPDATE users SET auth_valid_after = NOW() WHERE id = $1`, userID); err != nil {
		return fmt.Errorf("advance user auth cutoff: %w", err)
	}
	if _, err = tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID); err != nil {
		return fmt.Errorf("revoke user sessions: %w", err)
	}
	return tx.Commit(ctx)
}

func (s *postgresSessionStore) RevokeAccess(ctx context.Context, jti string, expiresAt time.Time) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO auth_access_revocations (jti, expires_at) VALUES ($1,$2)
		ON CONFLICT (jti) DO UPDATE SET expires_at = GREATEST(auth_access_revocations.expires_at, EXCLUDED.expires_at)
	`, jti, expiresAt)
	return err
}

func (s *postgresSessionStore) IsAccessActive(ctx context.Context, jti string, userID uuid.UUID, issuedAt time.Time) (bool, error) {
	var active bool
	err := s.db.QueryRow(ctx, `
		SELECT u.auth_valid_after <= $3
		AND NOT EXISTS (SELECT 1 FROM auth_access_revocations r WHERE r.jti = $1 AND r.expires_at > NOW())
		FROM users u WHERE u.id = $2 AND u.deleted_at IS NULL AND u.is_active
	`, jti, userID, issuedAt).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return active, err
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
	refreshClaims := s.newClaims(userID, roles, TokenTypeRefresh, now, now.Add(refreshLifetime(roles)))

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

// RotateRefreshToken atomically consumes a refresh session and creates its
// replacement. Exactly one concurrent caller can win.
func (s *Service) RotateRefreshToken(token string) (access, refresh string, err error) {
	claims, err := s.parse(token, TokenTypeRefresh)
	if err != nil || s.sessions == nil {
		return "", "", ErrInvalidToken
	}
	now := time.Now().UTC()
	accessClaims := s.newClaims(claims.Subject, claims.Roles, TokenTypeAccess, now, now.Add(s.accessTokenLifetime()))
	refreshClaims := s.newClaims(claims.Subject, claims.Roles, TokenTypeRefresh, now, now.Add(refreshLifetime(claims.Roles)))
	access, err = s.sign(accessClaims)
	if err != nil {
		return "", "", err
	}
	refresh, err = s.sign(refreshClaims)
	if err != nil {
		return "", "", err
	}
	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return "", "", ErrInvalidToken
	}
	expiresAt, err := refreshClaims.GetExpirationTime()
	if err != nil || expiresAt == nil {
		return "", "", ErrInvalidToken
	}
	ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
	defer cancel()
	err = s.sessions.Rotate(ctx, claims.ID, RefreshSession{
		JTI: refreshClaims.ID, UserID: userID, Roles: claims.Roles, ExpiresAt: expiresAt.Time,
	})
	if err != nil {
		return "", "", err
	}
	return access, refresh, nil
}

func refreshLifetime(roles []string) time.Duration {
	for _, role := range roles {
		if role == "guest" {
			return guestRefreshLifetime
		}
	}
	return refreshTokenLifetime
}

func (s *Service) ValidateAccessToken(token string) (*Claims, error) {
	claims, err := s.ValidateAccessTokenClaims(token)
	if err != nil {
		return nil, err
	}
	if s.sessions != nil {
		userID, parseErr := uuid.Parse(claims.Subject)
		issuedAt, issuedErr := claims.GetIssuedAt()
		if parseErr != nil || issuedErr != nil || issuedAt == nil {
			return nil, ErrInvalidToken
		}
		ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
		defer cancel()
		active, checkErr := s.sessions.IsAccessActive(ctx, claims.ID, userID, issuedAt.Time)
		if checkErr != nil {
			return nil, fmt.Errorf("check access session: %w", checkErr)
		}
		if !active {
			return nil, ErrRevokedToken
		}
	}
	return claims, nil
}

// ValidateAccessTokenClaims validates the signed access token and the local
// revocation set without querying the persistent session store. Callers must
// apply the persistent auth_valid_after and access-revocation predicates.
func (s *Service) ValidateAccessTokenClaims(token string) (*Claims, error) {
	claims, err := s.parse(token, TokenTypeAccess)
	if err != nil {
		return nil, err
	}
	if s.isAccessRevoked(claims.ID) {
		return nil, ErrRevokedToken
	}
	return claims, nil
}

func (s *Service) ValidateRefreshToken(token string) (*Claims, error) {
	claims, err := s.parse(token, TokenTypeRefresh)
	if err != nil {
		return nil, err
	}
	if s.sessions == nil {
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
	if s.sessions != nil {
		ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
		defer cancel()
		if err := s.sessions.RevokeAccess(ctx, jti, s.revokedAccess[jti]); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) RevokeUserSessions(userID uuid.UUID) error {
	if s.sessions == nil {
		return ErrInvalidToken
	}
	ctx, cancel := context.WithTimeout(context.Background(), sessionTimeout)
	defer cancel()
	return s.sessions.RevokeUser(ctx, userID)
}

func (s *Service) ParseAccessToken(token string) (*Claims, error) {
	return s.parse(token, TokenTypeAccess)
}

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
			Issuer: s.tokenIssuer(), Audience: golangjwt.ClaimStrings{s.tokenAudience()},
			IssuedAt: golangjwt.NewNumericDate(issuedAt), NotBefore: golangjwt.NewNumericDate(issuedAt),
			ExpiresAt: golangjwt.NewNumericDate(expiresAt),
		},
	}
}

func (s *Service) sign(claims *Claims) (string, error) {
	token := golangjwt.NewWithClaims(golangjwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(s.signingKey(claims.TokenType))
	if err != nil {
		return "", fmt.Errorf("sign token: %w", err)
	}
	return signed, nil
}

func (s *Service) parse(token, expectedType string) (*Claims, error) {
	claims := &Claims{}
	parsed, err := golangjwt.ParseWithClaims(token, claims, func(token *golangjwt.Token) (interface{}, error) {
		if token.Method != golangjwt.SigningMethodHS256 {
			return nil, ErrInvalidToken
		}
		return s.signingKey(expectedType), nil
	}, golangjwt.WithIssuer(s.tokenIssuer()), golangjwt.WithAudience(s.tokenAudience()))
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalidToken, err)
	}
	if !parsed.Valid {
		return nil, ErrInvalidToken
	}
	if claims.TokenType != expectedType {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

func (s *Service) signingKey(tokenType string) []byte {
	if tokenType == TokenTypeRefresh && s.cfg.SessionSecretKey != "" {
		return []byte(s.cfg.SessionSecretKey)
	}
	return []byte(s.cfg.SecretKey)
}

func (s *Service) tokenIssuer() string {
	if s.cfg.TokenIssuer == "" {
		return "mitlist"
	}
	return s.cfg.TokenIssuer
}

func (s *Service) tokenAudience() string {
	if s.cfg.TokenAudience == "" {
		return "mitlist-api"
	}
	return s.cfg.TokenAudience
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
		JTI: claims.ID, FamilyID: uuid.New(), UserID: userID, Roles: claims.Roles, ExpiresAt: expiresAt.Time,
	})
}
