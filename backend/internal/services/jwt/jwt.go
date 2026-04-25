package jwt

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	golangjwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/redis"
)

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"

	refreshTokenLifetime = 7 * 24 * time.Hour
	redisTimeout         = 5 * time.Second
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrRevokedToken = errors.New("revoked token")
)

// Claims is the JWT payload used for access and refresh tokens.
type Claims struct {
	Roles     []string `json:"roles,omitempty"`
	TokenType string   `json:"typ"`
	golangjwt.RegisteredClaims
}

// Service signs, validates, and revokes JWTs.
type Service struct {
	cfg   *config.Config
	redis *redis.RedisClient
}

// New creates a JWT service backed by Redis for refresh-token metadata.
func New(cfg *config.Config, redisClient *redis.RedisClient) *Service {
	return &Service{
		cfg:   cfg,
		redis: redisClient,
	}
}

// GenerateTokenPair creates signed access and refresh tokens for a user.
func (s *Service) GenerateTokenPair(userID string, roles []string) (access, refresh string, err error) {
	now := time.Now().UTC()
	accessTTL := time.Duration(s.cfg.AccessTokenExpireMinutes) * time.Minute
	if accessTTL <= 0 {
		accessTTL = time.Hour
	}

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

	if err := s.storeRefreshToken(refreshClaims); err != nil {
		return "", "", err
	}

	return access, refresh, nil
}

// ValidateAccessToken validates an access token and returns its claims.
func (s *Service) ValidateAccessToken(token string) (*Claims, error) {
	claims, err := s.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeAccess {
		return nil, ErrInvalidToken
	}
	if revoked, err := s.isRevoked(TokenTypeAccess, claims.ID); err != nil {
		return nil, err
	} else if revoked {
		return nil, ErrRevokedToken
	}
	return claims, nil
}

// ValidateRefreshToken validates a refresh token and verifies its Redis metadata.
func (s *Service) ValidateRefreshToken(token string) (*Claims, error) {
	claims, err := s.parse(token)
	if err != nil {
		return nil, err
	}
	if claims.TokenType != TokenTypeRefresh {
		return nil, ErrInvalidToken
	}
	if revoked, err := s.isRevoked(TokenTypeRefresh, claims.ID); err != nil {
		return nil, err
	} else if revoked {
		return nil, ErrRevokedToken
	}

	ctx, cancel := context.WithTimeout(context.Background(), redisTimeout)
	defer cancel()

	exists, err := s.redis.Client().Exists(ctx, refreshTokenKey(claims.ID)).Result()
	if err != nil {
		return nil, fmt.Errorf("check refresh token metadata: %w", err)
	}
	if exists == 0 {
		return nil, ErrRevokedToken
	}

	return claims, nil
}

// RevokeRefreshToken revokes a refresh token by JTI.
func (s *Service) RevokeRefreshToken(jti string) error {
	ctx, cancel := context.WithTimeout(context.Background(), redisTimeout)
	defer cancel()

	pipe := s.redis.Client().Pipeline()
	pipe.Del(ctx, refreshTokenKey(jti))
	pipe.Set(ctx, revokedTokenKey(TokenTypeRefresh, jti), "1", refreshTokenLifetime)
	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("revoke refresh token: %w", err)
	}
	return nil
}

// RevokeAccessToken revokes an access token by JTI so that it can no longer be used.
func (s *Service) RevokeAccessToken(jti string) error {
	ctx, cancel := context.WithTimeout(context.Background(), redisTimeout)
	defer cancel()
	// Keep revoked access token at least as long as the remaining token lifetime (max 1 hour).
	return s.redis.Client().Set(ctx, revokedTokenKey(TokenTypeAccess, jti), "1", time.Hour).Err()
}

// ParseAccessToken parses and validates an access token without checking Redis revocation.
// Returns the raw claims so the caller can extract the JTI for revocation.
func (s *Service) ParseAccessToken(token string) (*Claims, error) {
	return s.parse(token)
}

func (s *Service) newClaims(userID string, roles []string, tokenType string, issuedAt, expiresAt time.Time) *Claims {
	return &Claims{
		Roles:     append([]string(nil), roles...),
		TokenType: tokenType,
		RegisteredClaims: golangjwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Subject:   userID,
			IssuedAt:  golangjwt.NewNumericDate(issuedAt),
			NotBefore: golangjwt.NewNumericDate(issuedAt),
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

func (s *Service) storeRefreshToken(claims *Claims) error {
	expiresAt, err := claims.GetExpirationTime()
	if err != nil {
		return fmt.Errorf("read refresh token expiration: %w", err)
	}
	if expiresAt == nil {
		return ErrInvalidToken
	}

	ttl := time.Until(expiresAt.Time)
	if ttl <= 0 {
		return ErrInvalidToken
	}

	metadata := map[string]any{
		"user_id":    claims.Subject,
		"roles":      claims.Roles,
		"issued_at":  claims.IssuedAt.Time,
		"expires_at": expiresAt.Time,
	}
	data, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("marshal refresh token metadata: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), redisTimeout)
	defer cancel()

	if err := s.redis.Client().Set(ctx, refreshTokenKey(claims.ID), data, ttl).Err(); err != nil {
		return fmt.Errorf("store refresh token metadata: %w", err)
	}
	return nil
}

func (s *Service) isRevoked(tokenType, jti string) (bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), redisTimeout)
	defer cancel()

	exists, err := s.redis.Client().Exists(ctx, revokedTokenKey(tokenType, jti)).Result()
	if err != nil {
		return false, fmt.Errorf("check revoked token: %w", err)
	}
	return exists > 0, nil
}

func refreshTokenKey(jti string) string {
	return "jwt:refresh:" + jti
}

func revokedTokenKey(tokenType, jti string) string {
	return "jwt:revoked:" + tokenType + ":" + jti
}
