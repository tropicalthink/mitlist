package jwt

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	golangjwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
)

const testSecret = "test-secret-key-min-32-chars-long!!!"

func newService() *Service {
	return New(&config.Config{SecretKey: testSecret, AccessTokenExpireMinutes: 60}, nil)
}

// makeToken signs an HS256 token with the given secret, token type, subject, and expiry.
func makeToken(t *testing.T, secret, tokenType, subject string, exp time.Time) string {
	t.Helper()
	now := time.Now().UTC()
	claims := &Claims{
		TokenType: tokenType,
		RegisteredClaims: golangjwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Subject:   subject,
			IssuedAt:  golangjwt.NewNumericDate(now.Add(-time.Minute)),
			NotBefore: golangjwt.NewNumericDate(now.Add(-time.Minute)),
			ExpiresAt: golangjwt.NewNumericDate(exp),
		},
	}
	token := golangjwt.NewWithClaims(golangjwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return signed
}

func TestValidateAccessToken_Rejects(t *testing.T) {
	svc := newService()
	future := time.Now().UTC().Add(time.Hour)
	past := time.Now().UTC().Add(-time.Hour)

	cases := []struct {
		name        string
		token       string
		wantInvalid bool // expect errors.Is(err, ErrInvalidToken)
	}{
		{
			name:  "garbage string",
			token: "not.a.jwt",
		},
		{
			name:  "wrong signing secret",
			token: makeToken(t, "a-completely-different-secret-key-here", TokenTypeAccess, "user-1", future),
		},
		{
			name:  "expired access token",
			token: makeToken(t, testSecret, TokenTypeAccess, "user-1", past),
		},
		{
			name:        "refresh-type token rejected as access",
			token:       makeToken(t, testSecret, TokenTypeRefresh, "user-1", future),
			wantInvalid: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			claims, err := svc.ValidateAccessToken(tc.token)
			if err == nil {
				t.Fatalf("expected error, got nil (claims=%+v)", claims)
			}
			if tc.wantInvalid && !errors.Is(err, ErrInvalidToken) {
				t.Fatalf("expected ErrInvalidToken, got %v", err)
			}
		})
	}
}

func TestParse_AcceptsValidAccessToken(t *testing.T) {
	svc := newService()
	tok := makeToken(t, testSecret, TokenTypeAccess, "user-1", time.Now().UTC().Add(time.Hour))

	claims, err := svc.parse(tok)
	if err != nil {
		t.Fatalf("parse returned error: %v", err)
	}
	if claims.TokenType != TokenTypeAccess {
		t.Fatalf("expected token type %q, got %q", TokenTypeAccess, claims.TokenType)
	}
}

type memorySessionStore struct {
	mu       sync.Mutex
	sessions map[string]RefreshSession
	revoked  map[string]bool
}

func newMemorySessionStore() *memorySessionStore {
	return &memorySessionStore{
		sessions: make(map[string]RefreshSession),
		revoked:  make(map[string]bool),
	}
}

func (s *memorySessionStore) Store(_ context.Context, session RefreshSession) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessions[session.JTI] = session
	return nil
}

func (s *memorySessionStore) IsActive(_ context.Context, jti string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	session, exists := s.sessions[jti]
	return exists && !s.revoked[jti] && session.ExpiresAt.After(time.Now()), nil
}

func (s *memorySessionStore) Revoke(_ context.Context, jti string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.revoked[jti] = true
	return nil
}

func newServiceWithSessions() *Service {
	return NewWithStore(&config.Config{
		SecretKey:                testSecret,
		AccessTokenExpireMinutes: 60,
		Environment:              "test",
	}, newMemorySessionStore())
}

func TestGenerateAndValidate_RoundTrip(t *testing.T) {
	svc := newServiceWithSessions()
	userID := uuid.NewString()

	access, refresh, err := svc.GenerateTokenPair(userID, []string{"member"})
	if err != nil {
		t.Fatalf("GenerateTokenPair: %v", err)
	}

	accessClaims, err := svc.ValidateAccessToken(access)
	if err != nil {
		t.Fatalf("ValidateAccessToken: %v", err)
	}
	if accessClaims.TokenType != TokenTypeAccess {
		t.Fatalf("access token type = %q, want %q", accessClaims.TokenType, TokenTypeAccess)
	}

	refreshClaims, err := svc.ValidateRefreshToken(refresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken: %v", err)
	}
	if refreshClaims.TokenType != TokenTypeRefresh {
		t.Fatalf("refresh token type = %q, want %q", refreshClaims.TokenType, TokenTypeRefresh)
	}
}

func TestRevokeAccessToken(t *testing.T) {
	svc := newServiceWithSessions()

	access, _, err := svc.GenerateTokenPair(uuid.NewString(), []string{"member"})
	if err != nil {
		t.Fatalf("GenerateTokenPair: %v", err)
	}

	claims, err := svc.ValidateAccessToken(access)
	if err != nil {
		t.Fatalf("ValidateAccessToken before revoke: %v", err)
	}

	if err := svc.RevokeAccessToken(claims.ID); err != nil {
		t.Fatalf("RevokeAccessToken: %v", err)
	}

	if _, err := svc.ValidateAccessToken(access); !errors.Is(err, ErrRevokedToken) {
		t.Fatalf("expected ErrRevokedToken after revoke, got %v", err)
	}
}

func TestRevokeRefreshToken(t *testing.T) {
	svc := newServiceWithSessions()
	_, refresh, err := svc.GenerateTokenPair(uuid.NewString(), []string{"member"})
	if err != nil {
		t.Fatalf("GenerateTokenPair: %v", err)
	}

	claims, err := svc.ValidateRefreshToken(refresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken before revoke: %v", err)
	}
	if err := svc.RevokeRefreshToken(claims.ID); err != nil {
		t.Fatalf("RevokeRefreshToken: %v", err)
	}
	if _, err := svc.ValidateRefreshToken(refresh); !errors.Is(err, ErrRevokedToken) {
		t.Fatalf("expected ErrRevokedToken after revoke, got %v", err)
	}
}
