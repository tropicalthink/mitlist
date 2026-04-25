package mocks

import "github.com/stretchr/testify/mock"

// MockAIClient is a mock implementation of the AI client.
type MockAIClient struct {
	mock.Mock
}

func (m *MockAIClient) Generate(prompt string, model string) (string, error) {
	args := m.Called(prompt, model)
	return args.String(0), args.Error(1)
}

func (m *MockAIClient) GenerateStructured(prompt string, model string, schema map[string]any) (map[string]any, error) {
	args := m.Called(prompt, model, schema)
	if r := args.Get(0); r != nil {
		return r.(map[string]any), args.Error(1)
	}
	return nil, args.Error(1)
}
