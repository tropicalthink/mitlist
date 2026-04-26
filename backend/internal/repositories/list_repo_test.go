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

func TestListRepository_CreateList(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)

	list := &models.List{
		GroupID: fixedUUID(),
		Name:    "Groceries",
		Type:    "shopping",
	}

	mock.ExpectExec("INSERT INTO lists").
		WithArgs(pgxmock.AnyArg(), list.GroupID, list.Name, list.Type, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateList(context.Background(), list)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, list.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_GetListByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "type", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Groceries", "shopping", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM lists WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	list, err := repo.GetListByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, list.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_GetListByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM lists WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	list, err := repo.GetListByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, list)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_ListListsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "type", "created_at", "updated_at"}).
		AddRow(fixedUUID(), gid, "Groceries", "shopping", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM lists WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	lists, err := repo.ListListsByGroup(context.Background(), gid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, lists, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_ListItemPreviewLinesByListIDs(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	lid := fixedUUID()
	ids := []uuid.UUID{lid}

	rows := pgxmock.NewRows([]string{"list_id", "preview"}).
		AddRow(lid, []string{"milk", "bread"})

	mock.ExpectQuery("SELECT list_id, COALESCE").
		WithArgs(ids, 4).
		WillReturnRows(rows)

	m, err := repo.ListItemPreviewLinesByListIDs(context.Background(), ids, 4)
	require.NoError(t, err)
	require.Len(t, m, 1)
	assert.Equal(t, []string{"milk", "bread"}, m[lid])
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_UpdateList(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE lists SET").
		WithArgs("New Name", "todo", pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	list := &models.List{ID: id, Name: "New Name", Type: "todo"}
	err := repo.UpdateList(context.Background(), list)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_HardDeleteList(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM lists WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.HardDeleteList(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_CreateItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)

	item := &models.ListItem{
		ListID:   fixedUUID(),
		Name:     "Milk",
		Quantity: 2,
		Unit:     "liters",
		Checked:  false,
		Position: 1,
	}

	mock.ExpectExec("INSERT INTO list_items").
		WithArgs(pgxmock.AnyArg(), item.ListID, item.Name, item.Quantity, item.Unit, item.Checked, item.Position, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateItem(context.Background(), item)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, item.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_GetItemByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "list_id", "name", "quantity", "unit", "checked", "position", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Milk", 2, "liters", false, 1, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM list_items WHERE id = .* AND deleted_at IS NULL").
		WithArgs(id).
		WillReturnRows(rows)

	item, err := repo.GetItemByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, item.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_GetItemByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM list_items WHERE id = .* AND deleted_at IS NULL").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	item, err := repo.GetItemByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, item)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_ListItemsByList(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	listID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "list_id", "name", "quantity", "unit", "checked", "position", "created_at", "updated_at"}).
		AddRow(fixedUUID(), listID, "Milk", 2, "liters", false, 1, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM list_items WHERE list_id = .* AND deleted_at IS NULL").
		WithArgs(listID, 50, 0).
		WillReturnRows(rows)

	items, err := repo.ListItemsByList(context.Background(), listID, 0, 0)
	require.NoError(t, err)
	assert.Len(t, items, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_UpdateItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE list_items SET").
		WithArgs("Eggs", 12, "pcs", true, 2, pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	item := &models.ListItem{ID: id, Name: "Eggs", Quantity: 12, Unit: "pcs", Checked: true, Position: 2}
	err := repo.UpdateItem(context.Background(), item)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_HardDeleteItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM list_items WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.HardDeleteItem(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestListRepository_SoftDeleteItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewListRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE list_items SET deleted_at = .* WHERE id = .*").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.SoftDeleteItem(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}
