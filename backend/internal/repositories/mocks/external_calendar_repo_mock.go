package mocks

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

// MockExternalCalendarRepo is a mock implementation of repositories.ExternalCalendarRepo.
type MockExternalCalendarRepo struct {
	mock.Mock
}

var _ repositories.ExternalCalendarRepo = (*MockExternalCalendarRepo)(nil)

func (m *MockExternalCalendarRepo) CountConnections(ctx context.Context, userID uuid.UUID) (int, error) {
	args := m.Called(ctx, userID)
	return args.Int(0), args.Error(1)
}

func (m *MockExternalCalendarRepo) GetConnection(ctx context.Context, id, userID uuid.UUID) (*models.CalendarConnection, error) {
	args := m.Called(ctx, id, userID)
	if v := args.Get(0); v != nil {
		return v.(*models.CalendarConnection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) GetDeviceConnection(ctx context.Context, userID uuid.UUID, deviceID string) (*models.CalendarConnection, error) {
	args := m.Called(ctx, userID, deviceID)
	if v := args.Get(0); v != nil {
		return v.(*models.CalendarConnection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListConnections(ctx context.Context, userID uuid.UUID) ([]models.CalendarConnection, error) {
	args := m.Called(ctx, userID)
	if v := args.Get(0); v != nil {
		return v.([]models.CalendarConnection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) CreateICSConnection(ctx context.Context, c *models.CalendarConnection, cal *models.ExternalCalendar, events []models.ExternalEvent) error {
	return m.Called(ctx, c, cal, events).Error(0)
}

func (m *MockExternalCalendarRepo) CreateDeviceConnection(ctx context.Context, c *models.CalendarConnection) error {
	return m.Called(ctx, c).Error(0)
}

func (m *MockExternalCalendarRepo) UpdateConnectionName(ctx context.Context, id, userID uuid.UUID, name string) (bool, error) {
	args := m.Called(ctx, id, userID, name)
	return args.Bool(0), args.Error(1)
}

func (m *MockExternalCalendarRepo) DeleteConnection(ctx context.Context, id, userID uuid.UUID) (bool, error) {
	args := m.Called(ctx, id, userID)
	return args.Bool(0), args.Error(1)
}

func (m *MockExternalCalendarRepo) GetCalendar(ctx context.Context, id, userID uuid.UUID) (*models.ExternalCalendar, error) {
	args := m.Called(ctx, id, userID)
	if v := args.Get(0); v != nil {
		return v.(*models.ExternalCalendar), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListCalendarIDs(ctx context.Context, connID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, connID)
	if v := args.Get(0); v != nil {
		return v.([]uuid.UUID), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListShareGroupsForConnection(ctx context.Context, connID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, connID)
	if v := args.Get(0); v != nil {
		return v.([]uuid.UUID), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListShareGroupsForCalendar(ctx context.Context, calendarID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, calendarID)
	if v := args.Get(0); v != nil {
		return v.([]uuid.UUID), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ReplaceShares(ctx context.Context, calendarID uuid.UUID, shares []models.CalendarShare) error {
	return m.Called(ctx, calendarID, shares).Error(0)
}

func (m *MockExternalCalendarRepo) SetOverride(ctx context.Context, userID, calendarID uuid.UUID, externalUID string, visibility *string) error {
	return m.Called(ctx, userID, calendarID, externalUID, visibility).Error(0)
}

func (m *MockExternalCalendarRepo) ListOverrides(ctx context.Context, userID uuid.UUID) ([]models.EventOverride, error) {
	args := m.Called(ctx, userID)
	if v := args.Get(0); v != nil {
		return v.([]models.EventOverride), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ReplaceCalendarEvents(ctx context.Context, connID, calendarID uuid.UUID, events []models.ExternalEvent, hash *string) error {
	return m.Called(ctx, connID, calendarID, events, hash).Error(0)
}

func (m *MockExternalCalendarRepo) DeviceSync(ctx context.Context, connID, userID uuid.UUID, calendars []models.ExternalCalendar, events []repositories.DeviceSyncEvent, hash string, syncedAt time.Time) error {
	return m.Called(ctx, connID, userID, calendars, events, hash, syncedAt).Error(0)
}

func (m *MockExternalCalendarRepo) RecordSyncResult(ctx context.Context, id uuid.UUID, rec repositories.ICSSyncRecord) error {
	return m.Called(ctx, id, rec).Error(0)
}

func (m *MockExternalCalendarRepo) ClaimAttempt(ctx context.Context, id uuid.UUID, now time.Time, minGap time.Duration) (bool, error) {
	args := m.Called(ctx, id, now, minGap)
	return args.Bool(0), args.Error(1)
}

func (m *MockExternalCalendarRepo) ListDueICSConnections(ctx context.Context, now time.Time, limit int) ([]models.CalendarConnection, error) {
	args := m.Called(ctx, now, limit)
	if v := args.Get(0); v != nil {
		return v.([]models.CalendarConnection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListOwnEvents(ctx context.Context, userID uuid.UUID, from, to time.Time) ([]models.OwnEvent, error) {
	args := m.Called(ctx, userID, from, to)
	if v := args.Get(0); v != nil {
		return v.([]models.OwnEvent), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) ListHouseholdEvents(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.HouseholdExternalEvent, error) {
	args := m.Called(ctx, groupID, from, to)
	if v := args.Get(0); v != nil {
		return v.([]models.HouseholdExternalEvent), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockExternalCalendarRepo) TrimEvents(ctx context.Context, before, after time.Time) (int64, error) {
	args := m.Called(ctx, before, after)
	return args.Get(0).(int64), args.Error(1)
}
