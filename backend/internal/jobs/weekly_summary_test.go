package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

type mockWeeklySummaryRepo struct {
	mock.Mock
}

func (m *mockWeeklySummaryRepo) ListWeeklyActivity(ctx context.Context, since time.Time) ([]groupActivity, error) {
	args := m.Called(ctx, since)
	return args.Get(0).([]groupActivity), args.Error(1)
}

func (m *mockWeeklySummaryRepo) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	args := m.Called(ctx, groupID)
	return args.Get(0).([]uuid.UUID), args.Error(1)
}

func (m *mockWeeklySummaryRepo) GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error) {
	args := m.Called(ctx, userID, groupID)
	if p := args.Get(0); p != nil {
		return p.(*models.NotificationPreference), args.Error(1)
	}
	return nil, args.Error(1)
}

func TestWeeklySummary_Run(t *testing.T) {
	log := logger.New("test")
	repo := new(mockWeeklySummaryRepo)
	pusher := new(mockPusher)

	groupID := uuid.New()
	userID := uuid.New()

	repo.On("ListWeeklyActivity", mock.Anything, mock.AnythingOfType("time.Time")).Return([]groupActivity{
		{GroupID: groupID, Count: 5},
	}, nil)
	repo.On("ListGroupMembers", mock.Anything, groupID).Return([]uuid.UUID{userID}, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:       userID,
		GroupID:      groupID,
		WeeklyDigest: true,
		PushEnabled:  true,
	}, nil)
	pusher.On("SendToUser", userID, mock.AnythingOfType("string")).Return(nil)

	summary := newWeeklySummary(repo, pusher, log)
	summary.Run()

	repo.AssertExpectations(t)
	pusher.AssertExpectations(t)
}

func TestWeeklySummary_Run_ListError(t *testing.T) {
	log := logger.New("test")
	repo := new(mockWeeklySummaryRepo)
	pusher := new(mockPusher)

	repo.On("ListWeeklyActivity", mock.Anything, mock.AnythingOfType("time.Time")).Return([]groupActivity{}, assert.AnError)

	summary := newWeeklySummary(repo, pusher, log)
	summary.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}

func TestWeeklySummary_Run_RespectsWeeklyDigestOptOut(t *testing.T) {
	log := logger.New("test")
	repo := new(mockWeeklySummaryRepo)
	pusher := new(mockPusher)

	groupID := uuid.New()
	userID := uuid.New()

	repo.On("ListWeeklyActivity", mock.Anything, mock.AnythingOfType("time.Time")).Return([]groupActivity{
		{GroupID: groupID, Count: 3},
	}, nil)
	repo.On("ListGroupMembers", mock.Anything, groupID).Return([]uuid.UUID{userID}, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:       userID,
		GroupID:      groupID,
		WeeklyDigest: false,
		PushEnabled:  true,
	}, nil)

	summary := newWeeklySummary(repo, pusher, log)
	summary.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}

func TestWeeklySummary_Run_RespectsPushDisabled(t *testing.T) {
	log := logger.New("test")
	repo := new(mockWeeklySummaryRepo)
	pusher := new(mockPusher)

	groupID := uuid.New()
	userID := uuid.New()

	repo.On("ListWeeklyActivity", mock.Anything, mock.AnythingOfType("time.Time")).Return([]groupActivity{
		{GroupID: groupID, Count: 7},
	}, nil)
	repo.On("ListGroupMembers", mock.Anything, groupID).Return([]uuid.UUID{userID}, nil)
	repo.On("GetUserPreference", mock.Anything, userID, groupID).Return(&models.NotificationPreference{
		UserID:       userID,
		GroupID:      groupID,
		WeeklyDigest: true,
		PushEnabled:  false,
	}, nil)

	summary := newWeeklySummary(repo, pusher, log)
	summary.Run()

	repo.AssertExpectations(t)
	pusher.AssertNotCalled(t, "SendToUser")
}

func TestWeeklySummaryRepoTryClaim(t *testing.T) {
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(pool.Close)

	pool.ExpectBegin()
	pool.ExpectQuery(`SELECT pg_try_advisory_xact_lock\(\$1\)`).
		WithArgs(weeklySummaryAdvisoryLockKey).
		WillReturnRows(pgxmock.NewRows([]string{"acquired"}).AddRow(true))
	pool.ExpectRollback()

	release, acquired, err := (&weeklySummaryRepoImpl{db: pool}).TryClaim(context.Background())
	require.NoError(t, err)
	require.True(t, acquired)
	require.NoError(t, release())
	require.NoError(t, pool.ExpectationsWereMet())
}

func TestWeeklySummaryRepoTryClaimSkipsAnotherReplica(t *testing.T) {
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(pool.Close)

	pool.ExpectBegin()
	pool.ExpectQuery(`SELECT pg_try_advisory_xact_lock\(\$1\)`).
		WithArgs(weeklySummaryAdvisoryLockKey).
		WillReturnRows(pgxmock.NewRows([]string{"acquired"}).AddRow(false))
	pool.ExpectRollback()

	_, acquired, err := (&weeklySummaryRepoImpl{db: pool}).TryClaim(context.Background())
	require.NoError(t, err)
	require.False(t, acquired)
	require.NoError(t, pool.ExpectationsWereMet())
}
