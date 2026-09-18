package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
)

// MockCalendarListRepo is a mock implementation of repositories.CalendarListRepo.
type MockCalendarListRepo struct {
	mock.Mock
}

func (m *MockCalendarListRepo) ListListsByGroupAndRemindAtRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.List, error) {
	args := m.Called(ctx, groupID, from, to)
	if v := args.Get(0); v != nil {
		return v.([]models.List), args.Error(1)
	}
	return nil, args.Error(1)
}
