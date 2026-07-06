package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/stretchr/testify/mock"
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

func (m *MockAuthRepo) ListPushSubscriptionsByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.PushSubscription, error) {
	args := m.Called(ctx, userIDs)
	if s := args.Get(0); s != nil {
		return s.(map[uuid.UUID][]models.PushSubscription), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) DeletePushSubscription(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockAuthRepo) SaveDeviceToken(ctx context.Context, userID uuid.UUID, platform, token string) (*models.DeviceToken, error) {
	args := m.Called(ctx, userID, platform, token)
	if dt := args.Get(0); dt != nil {
		return dt.(*models.DeviceToken), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) ListDeviceTokensByUser(ctx context.Context, userID uuid.UUID) ([]models.DeviceToken, error) {
	args := m.Called(ctx, userID)
	if tokens := args.Get(0); tokens != nil {
		return tokens.([]models.DeviceToken), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) ListDeviceTokensByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.DeviceToken, error) {
	args := m.Called(ctx, userIDs)
	if tokens := args.Get(0); tokens != nil {
		return tokens.(map[uuid.UUID][]models.DeviceToken), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockAuthRepo) DeleteDeviceToken(ctx context.Context, userID, id uuid.UUID) error {
	args := m.Called(ctx, userID, id)
	return args.Error(0)
}
