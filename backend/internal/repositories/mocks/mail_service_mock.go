package mocks

import "github.com/stretchr/testify/mock"

// MockMailService is a mock implementation of the mail service.
type MockMailService struct {
	mock.Mock
}

func (m *MockMailService) Send(to, subject, body string, isHTML bool) error {
	args := m.Called(to, subject, body, isHTML)
	return args.Error(0)
}

func (m *MockMailService) SendHTML(to, subject, html, text string) error {
	args := m.Called(to, subject, html, text)
	return args.Error(0)
}

func (m *MockMailService) SendTemplate(to, subject, tmplStr string, data any) error {
	args := m.Called(to, subject, tmplStr, data)
	return args.Error(0)
}
