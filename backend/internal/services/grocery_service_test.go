package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func newTestGroceryService(t *testing.T) (*GroceryService, pgxmock.PgxPoolIface) {
	t.Helper()
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { pool.Close() })
	repo := repositories.NewGroceryRepository(pool)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewGroceryService(repo, groupRepo)
	return svc, pool
}

func TestGroceryService_ResolveIngredientName_Found(t *testing.T) {
	svc, pool := newTestGroceryService(t)
	groupID := uuid.MustParse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
	canonicalID := uuid.MustParse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")

	// Alias "flour" normalises to "flour"
	rows := pgxmock.NewRows([]string{"canonical_item_id"}).AddRow(canonicalID)
	pool.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, "flour", "00000000-0000-0000-0000-000000000000").
		WillReturnRows(rows)

	got, err := svc.ResolveIngredientName(context.Background(), groupID, "  Flour  ")
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, canonicalID, *got)
	assert.NoError(t, pool.ExpectationsWereMet())
}

func TestGroceryService_ResolveIngredientName_NotFound(t *testing.T) {
	svc, pool := newTestGroceryService(t)
	groupID := uuid.New()

	pool.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, "unknown xyz", "00000000-0000-0000-0000-000000000000").
		WillReturnError(pgx.ErrNoRows)

	got, err := svc.ResolveIngredientName(context.Background(), groupID, "unknown xyz")
	require.NoError(t, err)
	assert.Nil(t, got)
	assert.NoError(t, pool.ExpectationsWereMet())
}

func TestGroceryService_ResolveIngredientName_EmptyName(t *testing.T) {
	svc, _ := newTestGroceryService(t)
	groupID := uuid.New()

	got, err := svc.ResolveIngredientName(context.Background(), groupID, "")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestGroceryService_ResolveIngredientName_NormalisesWhitespace(t *testing.T) {
	svc, pool := newTestGroceryService(t)
	groupID := uuid.New()
	canonicalID := uuid.New()

	// "  all  purpose  flour  " should normalise to "all purpose flour"
	rows := pgxmock.NewRows([]string{"canonical_item_id"}).AddRow(canonicalID)
	pool.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, "all purpose flour", "00000000-0000-0000-0000-000000000000").
		WillReturnRows(rows)

	got, err := svc.ResolveIngredientName(context.Background(), groupID, "  all  purpose  flour  ")
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, canonicalID, *got)
	assert.NoError(t, pool.ExpectationsWereMet())
}
