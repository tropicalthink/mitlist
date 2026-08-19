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
			Issuer:    "mitlist",
			Audience:  golangjwt.ClaimStrings{"mitlist-api"},
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

	claims, err := svc.parse(tok, TokenTypeAccess)
	if err != nil {
		t.Fatalf("parse returned error: %v", err)
	}
	if claims.TokenType != TokenTypeAccess {
		t.Fatalf("expected token type %q, got %q", TokenTypeAccess, claims.TokenType)
	}
}

type memorySessionStore struct {
	mu            sync.Mutex
	sessions      map[string]RefreshSession
	revoked       map[string]bool
	accessRevoked map[string]bool
}

func (m *memorySessionStore) RevokeAccess(_ context.Context, jti string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.accessRevoked == nil {
		m.accessRevoked = make(map[string]bool)
	}
	m.accessRevoked[jti] = true
	return nil
}

func (m *memorySessionStore) IsAccessActive(_ context.Context, jti string, _ uuid.UUID, _ time.Time) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return !m.accessRevoked[jti], nil
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

func (s *memorySessionStore) Rotate(_ context.Context, oldJTI string, replacement RefreshSession) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	old, exists := s.sessions[oldJTI]
	if !exists || s.revoked[oldJTI] || !old.ExpiresAt.After(time.Now()) {
		if exists {
			for jti, session := range s.sessions {
				if session.FamilyID == old.FamilyID {
					s.revoked[jti] = true
				}
			}
		}
		return ErrRevokedToken
	}
	s.revoked[oldJTI] = true
	replacement.FamilyID = old.FamilyID
	s.sessions[replacement.JTI] = replacement
	return nil
}

func (s *memorySessionStore) RevokeUser(_ context.Context, userID uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for jti, session := range s.sessions {
		if session.UserID == userID {
			s.revoked[jti] = true
		}
	}
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

func TestGuestRefreshTokenRetainsRecoveryWindow(t *testing.T) {
	svc := newServiceWithSessions()
	_, guestRefresh, err := svc.GenerateTokenPair(uuid.NewString(), []string{"guest"})
	if err != nil {
		t.Fatalf("GenerateTokenPair guest: %v", err)
	}
	guestClaims, err := svc.ValidateRefreshToken(guestRefresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken guest: %v", err)
	}
	guestExpiry, err := guestClaims.GetExpirationTime()
	if err != nil || guestExpiry == nil {
		t.Fatalf("guest refresh expiry missing: %v", err)
	}
	if remaining := time.Until(guestExpiry.Time); remaining < 364*24*time.Hour {
		t.Fatalf("guest refresh remaining = %s, want at least 364 days", remaining)
	}
	_, rotatedGuestRefresh, err := svc.RotateRefreshToken(guestRefresh)
	if err != nil {
		t.Fatalf("RotateRefreshToken guest: %v", err)
	}
	rotatedClaims, err := svc.ValidateRefreshToken(rotatedGuestRefresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken rotated guest: %v", err)
	}
	rotatedExpiry, err := rotatedClaims.GetExpirationTime()
	if err != nil || rotatedExpiry == nil {
		t.Fatalf("rotated guest refresh expiry missing: %v", err)
	}
	if remaining := time.Until(rotatedExpiry.Time); remaining < 364*24*time.Hour {
		t.Fatalf("rotated guest refresh remaining = %s, want at least 364 days", remaining)
	}

	_, regularRefresh, err := svc.GenerateTokenPair(uuid.NewString(), []string{"member"})
	if err != nil {
		t.Fatalf("GenerateTokenPair regular: %v", err)
	}
	regularClaims, err := svc.ValidateRefreshToken(regularRefresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken regular: %v", err)
	}
	regularExpiry, err := regularClaims.GetExpirationTime()
	if err != nil || regularExpiry == nil {
		t.Fatalf("regular refresh expiry missing: %v", err)
	}
	if remaining := time.Until(regularExpiry.Time); remaining > 8*24*time.Hour {
		t.Fatalf("regular refresh remaining = %s, want at most 8 days", remaining)
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

func TestRotateRefreshToken_ConcurrentReplayHasOneWinner(t *testing.T) {
	svc := newServiceWithSessions()
	_, refresh, err := svc.GenerateTokenPair(uuid.NewString(), []string{"member"})
	if err != nil {
		t.Fatalf("GenerateTokenPair: %v", err)
	}

	type result struct {
		refresh string
		err     error
	}
	start := make(chan struct{})
	results := make(chan result, 2)
	for range 2 {
		go func() {
			<-start
			_, rotated, rotateErr := svc.RotateRefreshToken(refresh)
			results <- result{refresh: rotated, err: rotateErr}
		}()
	}
	close(start)

	successes := 0
	var winner string
	for range 2 {
		got := <-results
		if got.err == nil {
			successes++
			winner = got.refresh
		}
	}
	if successes != 1 {
		t.Fatalf("successful rotations = %d, want exactly 1", successes)
	}
	// The losing replay revokes the entire family, including the token minted by
	// the winner, so a stolen token cannot establish a surviving branch.
	if _, err := svc.ValidateRefreshToken(winner); !errors.Is(err, ErrRevokedToken) {
		t.Fatalf("winner family should be revoked after replay, got %v", err)
	}
}
