package repositories

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestGroceryRepository_NextVersion_FirstInsert(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()

	rows := pgxmock.NewRows([]string{"current_version"}).AddRow(int64(1))

	mock.ExpectQuery("INSERT INTO grocery_versions \\(group_id, current_version\\)").
		WithArgs(groupID).
		WillReturnRows(rows)

	got, err := repo.NextVersion(context.Background(), groupID)
	require.NoError(t, err)
	assert.Equal(t, int64(1), got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_NextVersion_Increment(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()

	rows := pgxmock.NewRows([]string{"current_version"}).AddRow(int64(8))

	mock.ExpectQuery("INSERT INTO grocery_versions \\(group_id, current_version\\)").
		WithArgs(groupID).
		WillReturnRows(rows)

	got, err := repo.NextVersion(context.Background(), groupID)
	require.NoError(t, err)
	assert.Equal(t, int64(8), got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_CurrentVersion_Found(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()

	rows := pgxmock.NewRows([]string{"current_version"}).AddRow(int64(7))

	mock.ExpectQuery("SELECT current_version").
		WithArgs(groupID).
		WillReturnRows(rows)

	got, err := repo.CurrentVersion(context.Background(), groupID)
	require.NoError(t, err)
	assert.Equal(t, int64(7), got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_CurrentVersion_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()

	mock.ExpectQuery("SELECT current_version").
		WithArgs(groupID).
		WillReturnError(pgx.ErrNoRows)

	got, err := repo.CurrentVersion(context.Background(), groupID)
	require.NoError(t, err)
	assert.Equal(t, int64(0), got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_CurrentVersion_DBError(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()

	mock.ExpectQuery("SELECT current_version").
		WithArgs(groupID).
		WillReturnError(assert.AnError)

	got, err := repo.CurrentVersion(context.Background(), groupID)
	require.ErrorIs(t, err, assert.AnError)
	assert.Equal(t, int64(0), got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_WithTxCommits(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	rows := pgxmock.NewRows([]string{"current_version"}).AddRow(int64(1))
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO grocery_versions \\(group_id, current_version\\)").
		WithArgs(groupID).
		WillReturnRows(rows)
	mock.ExpectCommit()

	err := repo.WithTx(context.Background(), func(txRepo *GroceryRepository) error {
		got, err := txRepo.NextVersion(context.Background(), groupID)
		assert.Equal(t, int64(1), got)
		return err
	})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_InsertCorrection_NormalizesClientSource(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	userID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	canonicalID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	correctionID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	correctedValue := json.RawMessage(`{"alias_text":"vollmilch"}`)

	mock.ExpectExec("INSERT INTO corrections").
		WithArgs(
			correctionID,
			groupID,
			&userID,
			"household",
			"alias",
			"Vollmilch",
			&canonicalID,
			[]byte(correctedValue),
			"manual_review",
			int64(4),
			pgxmock.AnyArg(),
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.InsertCorrection(context.Background(), &models.Correction{
		ID:                      correctionID,
		GroupID:                 groupID,
		UserID:                  &userID,
		Scope:                   "household",
		Kind:                    "alias",
		RawText:                 "Vollmilch",
		ResolvedCanonicalItemID: &canonicalID,
		CorrectedValue:          correctedValue,
		Source:                  "client",
		CreatedAt:               time.Now().UTC(),
	}, 4)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_UpsertAliasUpdatesCanonicalOnConflict(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	canonicalID := uuid.MustParse("22222222-2222-2222-2222-222222222222")

	mock.ExpectExec("canonical_item_id = EXCLUDED.canonical_item_id").
		WithArgs(
			pgxmock.AnyArg(),
			groupID,
			canonicalID,
			"melk",
			"de",
			"correction",
			int64(2),
			pgxmock.AnyArg(),
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.UpsertAlias(context.Background(), groupID, canonicalID, "melk", "de", "correction", 2)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_ResolveAlias_Found(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	canonicalID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	aliasText := "mehl"

	rows := pgxmock.NewRows([]string{"canonical_item_id"}).
		AddRow(canonicalID)

	mock.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, aliasText, "00000000-0000-0000-0000-000000000000").
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
		WithArgs(groupID, aliasText, "00000000-0000-0000-0000-000000000000").
		WillReturnError(pgx.ErrNoRows)

	got, found, err := repo.ResolveAlias(context.Background(), groupID, aliasText)
	require.NoError(t, err)
	assert.False(t, found)
	assert.Equal(t, uuid.Nil, got)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroceryRepository_ResolveAlias_HouseholdBeatsGlobal(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroceryRepository(mock)

	groupID := fixedUUID()
	householdCanonicalID := uuid.MustParse("44444444-4444-4444-4444-444444444444")
	aliasText := "mehl"

	// The query's ORDER BY sorts household-scoped rows (group_id = $1) before
	// global ones and LIMIT 1 returns the winner. Stage the household row as
	// the single returned result to document that household aliases win.
	rows := pgxmock.NewRows([]string{"canonical_item_id"}).
		AddRow(householdCanonicalID)

	mock.ExpectQuery("SELECT canonical_item_id").
		WithArgs(groupID, aliasText, "00000000-0000-0000-0000-000000000000").
		WillReturnRows(rows)

	got, found, err := repo.ResolveAlias(context.Background(), groupID, aliasText)
	require.NoError(t, err)
	assert.True(t, found)
	assert.Equal(t, householdCanonicalID, got)
	assert.NoError(t, mock.ExpectationsWereMet())
}
