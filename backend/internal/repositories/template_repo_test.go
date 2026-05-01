package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestTemplateRepository_CreateTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)

	template := &models.Template{
		GroupID: fixedUUID(),
		Name:    "Weekly Groceries",
	}

	rows := pgxmock.NewRows([]string{"created_at", "updated_at"}).
		AddRow(fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO templates").
		WithArgs(pgxmock.AnyArg(), template.GroupID, template.Name).
		WillReturnRows(rows)

	err := repo.CreateTemplate(context.Background(), template)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, template.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_GetTemplateByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Weekly", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM templates WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	template, err := repo.GetTemplateByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, template.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_GetTemplateByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM templates WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	template, err := repo.GetTemplateByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, template)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_ListTemplates(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "created_at", "updated_at"}).
		AddRow(fixedUUID(), gid, "Weekly", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM templates WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	templates, err := repo.ListTemplates(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, templates, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"updated_at"}).AddRow(fixedTime())

	mock.ExpectQuery("UPDATE templates SET").
		WithArgs("New Name", id).
		WillReturnRows(rows)

	template := &models.Template{ID: id, Name: "New Name"}
	err := repo.UpdateTemplate(context.Background(), template)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateTemplate_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE templates SET").
		WithArgs("New Name", id).
		WillReturnError(pgx.ErrNoRows)

	template := &models.Template{ID: id, Name: "New Name"}
	err := repo.UpdateTemplate(context.Background(), template)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM templates WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteTemplate(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteTemplate_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM templates WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteTemplate(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_CreateTemplateItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)

	item := &models.TemplateItem{
		TemplateID: fixedUUID(),
		Name:       "Milk",
		Quantity:   2,
		Unit:       "liters",
	}

	mock.ExpectExec("INSERT INTO template_items").
		WithArgs(pgxmock.AnyArg(), item.TemplateID, item.Name, item.Quantity, item.Unit).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateTemplateItem(context.Background(), item)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, item.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_ListTemplateItems(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	tid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "template_id", "name", "quantity", "unit"}).
		AddRow(fixedUUID(), tid, "Milk", 2, "liters")

	mock.ExpectQuery("SELECT .* FROM template_items WHERE template_id = .*").
		WithArgs(tid).
		WillReturnRows(rows)

	items, err := repo.ListTemplateItems(context.Background(), tid)
	require.NoError(t, err)
	assert.Len(t, items, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateTemplateItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE template_items SET").
		WithArgs("Eggs", 12, "pcs", id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	item := &models.TemplateItem{ID: id, Name: "Eggs", Quantity: 12, Unit: "pcs"}
	err := repo.UpdateTemplateItem(context.Background(), item)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateTemplateItem_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE template_items SET").
		WithArgs("Eggs", 12, "pcs", id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	item := &models.TemplateItem{ID: id, Name: "Eggs", Quantity: 12, Unit: "pcs"}
	err := repo.UpdateTemplateItem(context.Background(), item)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteTemplateItem(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM template_items WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteTemplateItem(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteTemplateItem_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM template_items WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteTemplateItem(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_CreateChoreTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)

	ct := &models.ChoreTemplate{
		GroupID:      fixedUUID(),
		Name:         "Weekly Cleaning",
		RotationType: "schedule",
		Frequency:    "weekly",
	}

	rows := pgxmock.NewRows([]string{"created_at", "updated_at"}).
		AddRow(fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO chore_templates").
		WithArgs(pgxmock.AnyArg(), ct.GroupID, ct.Name, ct.RotationType, ct.Frequency).
		WillReturnRows(rows)

	err := repo.CreateChoreTemplate(context.Background(), ct)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, ct.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_GetChoreTemplateByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "rotation_type", "frequency", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Weekly", "schedule", "weekly", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM chore_templates WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	ct, err := repo.GetChoreTemplateByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, ct.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_GetChoreTemplateByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM chore_templates WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	ct, err := repo.GetChoreTemplateByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, ct)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_ListChoreTemplates(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "rotation_type", "frequency", "created_at", "updated_at"}).
		AddRow(fixedUUID(), gid, "Weekly", "schedule", "weekly", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM chore_templates WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	templates, err := repo.ListChoreTemplates(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, templates, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateChoreTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"updated_at"}).AddRow(fixedTime())

	mock.ExpectQuery("UPDATE chore_templates SET").
		WithArgs("New Name", "schedule", "daily", id).
		WillReturnRows(rows)

	ct := &models.ChoreTemplate{ID: id, Name: "New Name", RotationType: "schedule", Frequency: "daily"}
	err := repo.UpdateChoreTemplate(context.Background(), ct)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_UpdateChoreTemplate_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE chore_templates SET").
		WithArgs("New Name", "schedule", "daily", id).
		WillReturnError(pgx.ErrNoRows)

	ct := &models.ChoreTemplate{ID: id, Name: "New Name", RotationType: "schedule", Frequency: "daily"}
	err := repo.UpdateChoreTemplate(context.Background(), ct)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteChoreTemplate(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chore_templates WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteChoreTemplate(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestTemplateRepository_DeleteChoreTemplate_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewTemplateRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chore_templates WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteChoreTemplate(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}
