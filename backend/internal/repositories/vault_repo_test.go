package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/models"
)

func TestVaultRepository_CreateVaultItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)

	item := &models.VaultItem{
		GroupID:   fixedUUID(),
		Type:      "note",
		Title:     "WiFi",
		Content:   "password123",
		CreatedBy: fixedUUID(),
		CreatedAt: fixedTime(),
		UpdatedAt: fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "group_id", "type", "title", "content", "reminder_date", "created_by", "created_at", "updated_at"}).
		AddRow(fixedUUID(), item.GroupID, item.Type, item.Title, item.Content, nil, item.CreatedBy, fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO vault_items").
		WithArgs(pgxmock.AnyArg(), item.GroupID, item.Type, item.Title, item.Content, pgxmock.AnyArg(), item.CreatedBy, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	err := repo.CreateVaultItem(context.Background(), item)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, item.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_GetVaultItemByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "type", "title", "content", "reminder_date", "created_by", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "note", "WiFi", "pass", nil, fixedUUID(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM vault_items WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	item, err := repo.GetVaultItemByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, item.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_GetVaultItemByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM vault_items WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	item, err := repo.GetVaultItemByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, item)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_ListVaultItemsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "type", "title", "content", "reminder_date", "created_by", "created_at", "updated_at"}).
		AddRow(fixedUUID(), gid, "note", "WiFi", "pass", nil, fixedUUID(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM vault_items WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	items, err := repo.ListVaultItemsByGroup(context.Background(), gid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, items, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_UpdateVaultItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE vault_items SET").
		WithArgs("note", "New Title", "new content", pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	item := &models.VaultItem{ID: id, Type: "note", Title: "New Title", Content: "new content"}
	err := repo.UpdateVaultItem(context.Background(), item)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_UpdateVaultItem_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE vault_items SET").
		WithArgs("note", "New Title", "new content", pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	item := &models.VaultItem{ID: id, Type: "note", Title: "New Title", Content: "new content"}
	err := repo.UpdateVaultItem(context.Background(), item)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_DeleteVaultItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM vault_items WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteVaultItem(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_DeleteVaultItem_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM vault_items WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteVaultItem(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_CreateShare(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)

	share := &models.VaultShare{
		VaultItemID:      fixedUUID(),
		SharedWithUserID: fixedUUID(),
		Permission:       "read",
		CreatedAt:        fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "vault_item_id", "shared_with_user_id", "permission", "created_at"}).
		AddRow(fixedUUID(), share.VaultItemID, share.SharedWithUserID, share.Permission, fixedTime())

	mock.ExpectQuery("INSERT INTO vault_shares").
		WithArgs(pgxmock.AnyArg(), share.VaultItemID, share.SharedWithUserID, share.Permission, pgxmock.AnyArg()).
		WillReturnRows(rows)

	err := repo.CreateShare(context.Background(), share)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, share.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_ListShares(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	vid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "vault_item_id", "shared_with_user_id", "permission", "created_at"}).
		AddRow(fixedUUID(), vid, fixedUUID(), "read", fixedTime())

	mock.ExpectQuery("SELECT .* FROM vault_shares WHERE vault_item_id = .*").
		WithArgs(vid).
		WillReturnRows(rows)

	shares, err := repo.ListShares(context.Background(), vid)
	require.NoError(t, err)
	assert.Len(t, shares, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_DeleteShare(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM vault_shares WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteShare(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestVaultRepository_DeleteShare_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewVaultRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM vault_shares WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteShare(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}
