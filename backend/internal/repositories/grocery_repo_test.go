package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGroceryRepository_ResolveAlias_Found(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	canonicalID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	aliasText := "mehl"

	rows := pgxmock.NewRows([]string{"canonical_item_id"}).
		AddRow(canonicalID)

	mock.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, aliasText).
		WillReturnRows(rows)

	got, found, err := repo.ResolveAlias(context.Background(), groupID, aliasText)
	require.NoError(t, err)
	assert.True(t, found)
	assert.Equal(t, canonicalID, got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_ResolveAlias_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	aliasText := "unknown ingredient xyz"

	mock.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, aliasText).
		WillReturnError(pgx.ErrNoRows)

	got, found, err := repo.ResolveAlias(context.Background(), groupID, aliasText)
	require.NoError(t, err)
	assert.False(t, found)
	assert.Equal(t, uuid.Nil, got)
	assert.NoError(t, mock.ExpectationsWereMet())
}
