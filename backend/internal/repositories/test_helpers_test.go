package repositories

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newMockDB(t *testing.T) pgxmock.PgxPoolIface {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() {
		mock.Close()
	})
	return mock
}

func fixedUUID() uuid.UUID {
	return uuid.MustParse("11111111-1111-1111-1111-111111111111")
}

func fixedTime() time.Time {
	return time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
}

func assertUUID(t *testing.T, id uuid.UUID) {
	assert.NotEqual(t, uuid.Nil, id)
}
