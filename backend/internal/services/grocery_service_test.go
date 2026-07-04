package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
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

func TestGroceryService_RecordCorrectionUsesTransaction(t *testing.T) {
	ctx := context.Background()
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { pool.Close() })

	groupRepo := new(mocks.MockGroupRepo)
	repo := repositories.NewGroceryRepository(pool)
	svc := NewGroceryService(repo, groupRepo)

	userID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	groupID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	canonicalID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	groupRepo.On("GetMembership", ctx, groupID, userID).
		Return(&models.GroupMembership{GroupID: groupID, UserID: userID, Role: "member"}, nil).
		Once()

	pool.ExpectBegin()
	pool.ExpectQuery("INSERT INTO grocery_versions \\(group_id, current_version\\)").
		WithArgs(groupID).
		WillReturnRows(pgxmock.NewRows([]string{"current_version"}).AddRow(int64(4)))
	pool.ExpectExec("INSERT INTO canonical_items").
		WithArgs(canonicalID, groupID, "Milch", "milk", "dairy", "l", int64(4), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	pool.ExpectExec("INSERT INTO corrections").
		WithArgs(
			pgxmock.AnyArg(),
			groupID,
			&userID,
			"household",
			"alias",
			"Melk",
			&canonicalID,
			pgxmock.AnyArg(),
			"manual_review",
			int64(4),
			pgxmock.AnyArg(),
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	pool.ExpectExec("INSERT INTO item_aliases").
		WithArgs(pgxmock.AnyArg(), groupID, canonicalID, "melk", "de", "correction", int64(4), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	pool.ExpectCommit()

	version, err := svc.RecordCorrection(ctx, userID, groupID, RecordCorrectionRequest{
		RawText:             "Melk",
		Kind:                "alias",
		Scope:               "household",
		ResolvedCanonicalID: &canonicalID,
		CanonicalItem: &CanonicalItemStub{
			ID:          canonicalID,
			NameDe:      "Milch",
			NameEn:      "milk",
			Category:    "dairy",
			DefaultUnit: "l",
		},
		Lang: "de",
	})
	require.NoError(t, err)
	assert.Equal(t, int64(4), version)
	assert.NoError(t, pool.ExpectationsWereMet())
	groupRepo.AssertExpectations(t)
}

func TestGroceryService_UpdateAislesUsesTransaction(t *testing.T) {
	ctx := context.Background()
	pool, err := pgxmock.NewPool()
	require.NoError(t, err)
	t.Cleanup(func() { pool.Close() })

	groupRepo := new(mocks.MockGroupRepo)
	repo := repositories.NewGroceryRepository(pool)
	svc := NewGroceryService(repo, groupRepo)

	userID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	groupID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	canonicalID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	groupRepo.On("GetMembership", ctx, groupID, userID).
		Return(&models.GroupMembership{GroupID: groupID, UserID: userID, Role: "admin"}, nil).
		Once()

	pool.ExpectBegin()
	pool.ExpectQuery("INSERT INTO grocery_versions \\(group_id, current_version\\)").
		WithArgs(groupID).
		WillReturnRows(pgxmock.NewRows([]string{"current_version"}).AddRow(int64(7)))
	pool.ExpectExec("INSERT INTO store_aisles").
		WithArgs(
			groupID,
			int64(7),
			pgxmock.AnyArg(),
			pgxmock.AnyArg(),
			[]*uuid.UUID{nil},
			[]uuid.UUID{canonicalID},
			[]string{"dairy"},
			[]int32{3},
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	pool.ExpectCommit()

	version, err := svc.UpdateAisles(ctx, userID, groupID, AisleFeedbackRequest{
		Aisles: []repositories.AisleFeedbackItem{{
			CanonicalItemID: canonicalID,
			Aisle:           "dairy",
			SortOrder:       3,
		}},
	})
	require.NoError(t, err)
	assert.Equal(t, int64(7), version)
	assert.NoError(t, pool.ExpectationsWereMet())
	groupRepo.AssertExpectations(t)
}
