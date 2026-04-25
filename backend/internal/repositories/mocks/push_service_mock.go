package mocks

import (
	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
)

// MockPushService is a mock implementation of the push service.
type MockPushService struct {
	mock.Mock
}

func (m *MockPushService) SendToUser(userID uuid.UUID, payload string) error {
	args := m.Called(userID, payload)
	return args.Error(0)
}

func (m *MockPushService) BroadcastToGroup(groupID uuid.UUID, payload string) error {
	args := m.Called(groupID, payload)
	return args.Error(0)
}
