package mocks

import "github.com/stretchr/testify/mock"

// MockPasswordService is a mock implementation of the password service.
type MockPasswordService struct {
	mock.Mock
}

func (m *MockPasswordService) Hash(password string) (string, error) {
	args := m.Called(password)
	return args.String(0), args.Error(1)
}

func (m *MockPasswordService) Compare(hash, password string) bool {
	args := m.Called(hash, password)
	return args.Bool(0)
}
