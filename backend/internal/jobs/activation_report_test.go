package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/pkg/logger"
)

type fakeActivationRepo struct {
	from, to time.Time
	counts   activationCounts
	err      error
}

func (f *fakeActivationRepo) CountActivation(_ context.Context, from, to time.Time) (activationCounts, error) {
	f.from, f.to = from, to
	return f.counts, f.err
}

func TestActivationReport_MeasuresTheWeekWhoseWindowJustClosed(t *testing.T) {
	now := time.Date(2026, 10, 12, 8, 0, 0, 0, time.UTC)
	repo := &fakeActivationRepo{counts: activationCounts{Households: 10, Activated: 4, Precursor: 6}}
	job := &ActivationReport{repo: repo, log: logger.New("test"), now: func() time.Time { return now }}

	counts, ok := job.run(context.Background())

	require.True(t, ok)
	assert.Equal(t, 4, counts.Activated)
	assert.Equal(t, now.Add(-14*24*time.Hour), repo.from)
	assert.Equal(t, now.Add(-7*24*time.Hour), repo.to)
}

func TestActivationReport_CountFailureIsReported(t *testing.T) {
	repo := &fakeActivationRepo{err: errors.New("down")}
	job := &ActivationReport{repo: repo, log: logger.New("test"), now: time.Now}
	_, ok := job.run(context.Background())
	assert.False(t, ok)
}

func TestActivationRepo_CountActivationScansTheCohort(t *testing.T) {
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer pool.Close()
	from := time.Date(2026, 9, 28, 0, 0, 0, 0, time.UTC)
	to := from.Add(7 * 24 * time.Hour)

	pool.ExpectQuery(`WITH cohort AS`).
		WithArgs(from, to).
		WillReturnRows(pgxmock.NewRows([]string{"households", "activated", "precursor"}).AddRow(5, 2, 3))

	counts, err := (&activationRepoImpl{db: pool}).CountActivation(context.Background(), from, to)
	require.NoError(t, err)
	assert.Equal(t, activationCounts{Households: 5, Activated: 2, Precursor: 3}, counts)
	require.NoError(t, pool.ExpectationsWereMet())
}
