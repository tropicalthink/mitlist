package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
)

// MockCalendarPinwallRepo is a mock implementation of repositories.CalendarPinwallRepo.
type MockCalendarPinwallRepo struct {
	mock.Mock
}

func (m *MockCalendarPinwallRepo) ListPostsByGroupAndRemindAtRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.PinwallPost, error) {
	args := m.Called(ctx, groupID, from, to)
	if v := args.Get(0); v != nil {
		return v.([]models.PinwallPost), args.Error(1)
	}
	return nil, args.Error(1)
}
