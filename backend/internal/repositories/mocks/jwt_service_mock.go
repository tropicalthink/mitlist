package mocks

import (
	"github.com/stretchr/testify/mock"
	"github.com/mitlist-app/mitlist/internal/services/jwt"
)

// MockJWTService is a mock implementation of the JWT service.
type MockJWTService struct {
	mock.Mock
}

func (m *MockJWTService) GenerateTokenPair(userID string, roles []string) (string, string, error) {
	args := m.Called(userID, roles)
	return args.String(0), args.String(1), args.Error(2)
}

func (m *MockJWTService) ValidateAccessToken(token string) (*jwt.Claims, error) {
	args := m.Called(token)
	if c := args.Get(0); c != nil {
		return c.(*jwt.Claims), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockJWTService) ValidateRefreshToken(token string) (*jwt.Claims, error) {
	args := m.Called(token)
	if c := args.Get(0); c != nil {
		return c.(*jwt.Claims), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockJWTService) RevokeRefreshToken(jti string) error {
	args := m.Called(jti)
	return args.Error(0)
}
