package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/yourorg/mitlist/internal/models"
)

// MockAuthRepo is a mock implementation of repositories.AuthRepo.
type MockAuthRepo struct {
	mock.Mock
}

func (m *MockAuthRepo) CreateOAuthAccount(ctx context.Context, account *models.OAuthAccount) error {
	args := m.Called(ctx, account)
	return args.Error(0)
}

func (m *MockAuthRepo) GetOAuthByProviderID(ctx context.Context, provider, providerUserID string) (*models.OAuthAccount, error) {
	args := m.Called(ctx, provider, providerUserID)
	if a := args.Get(0); a != nil {
		return a.(*models.OAuthAccount), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) CreatePasswordResetToken(ctx context.Context, token *models.PasswordResetToken) error {
	args := m.Called(ctx, token)
	return args.Error(0)
}

func (m *MockAuthRepo) GetPasswordResetToken(ctx context.Context, token string) (*models.PasswordResetToken, error) {
	args := m.Called(ctx, token)
	if t := args.Get(0); t != nil {
		return t.(*models.PasswordResetToken), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) ConsumeToken(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockAuthRepo) CreatePushSubscription(ctx context.Context, sub *models.PushSubscription) error {
	args := m.Called(ctx, sub)
	return args.Error(0)
}

func (m *MockAuthRepo) ListPushSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.PushSubscription, error) {
	args := m.Called(ctx, userID)
	if s := args.Get(0); s != nil {
		return s.([]models.PushSubscription), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) DeletePushSubscription(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
