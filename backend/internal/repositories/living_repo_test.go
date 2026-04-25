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

func TestLivingRepository_CreateLivingThing(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)

	lt := &models.LivingThing{
		GroupID:  fixedUUID(),
		Name:     "Ficus",
		Species:  "Ficus benjamina",
		Location: "Living room",
		ImageURL: "https://example.com/ficus.jpg",
	}

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "species", "location", "image_url", "created_at", "updated_at"}).
		AddRow(fixedUUID(), lt.GroupID, lt.Name, lt.Species, lt.Location, lt.ImageURL, fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO living_things").
		WithArgs(pgxmock.AnyArg(), lt.GroupID, lt.Name, lt.Species, lt.Location, lt.ImageURL, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateLivingThing(context.Background(), lt)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NotEqual(t, uuid.Nil, created.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetLivingThingByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "species", "location", "image_url", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Ficus", "Ficus benjamina", "Living room", "url", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM living_things WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	lt, err := repo.GetLivingThingByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, lt.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetLivingThingByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM living_things WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	lt, err := repo.GetLivingThingByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, lt)
	assert.ErrorIs(t, err, ErrLivingThingNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_ListLivingThingsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "species", "location", "image_url", "created_at", "updated_at"}).
		AddRow(fixedUUID(), gid, "Ficus", "Ficus benjamina", "Living room", "url", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM living_things WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	items, err := repo.ListLivingThingsByGroup(context.Background(), gid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, items, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_UpdateLivingThing(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "name", "species", "location", "image_url", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "New Name", "Species", "Office", "url", fixedTime(), fixedTime())

	mock.ExpectQuery("UPDATE living_things SET").
		WithArgs("New Name", "Species", "Office", "url", pgxmock.AnyArg(), id).
		WillReturnRows(rows)

	lt := &models.LivingThing{ID: id, Name: "New Name", Species: "Species", Location: "Office", ImageURL: "url"}
	updated, err := repo.UpdateLivingThing(context.Background(), lt)
	require.NoError(t, err)
	assert.Equal(t, "New Name", updated.Name)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_UpdateLivingThing_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE living_things SET").
		WithArgs("New Name", "Species", "Office", "url", pgxmock.AnyArg(), id).
		WillReturnError(pgx.ErrNoRows)

	lt := &models.LivingThing{ID: id, Name: "New Name", Species: "Species", Location: "Office", ImageURL: "url"}
	updated, err := repo.UpdateLivingThing(context.Background(), lt)
	require.Error(t, err)
	assert.Nil(t, updated)
	assert.ErrorIs(t, err, ErrLivingThingNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_DeleteLivingThing(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM living_things WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteLivingThing(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_DeleteLivingThing_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM living_things WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteLivingThing(context.Background(), id)
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrLivingThingNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_CreateCareSchedule(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)

	cs := &models.CareSchedule{
		LivingThingID:  fixedUUID(),
		FrequencyValue: 7,
		FrequencyUnit:  "days",
		NextDue:        fixedTime(),
	}

	rows := pgxmock.NewRows([]string{"id", "living_thing_id", "frequency_value", "frequency_unit", "next_due", "created_at", "updated_at"}).
		AddRow(fixedUUID(), cs.LivingThingID, cs.FrequencyValue, cs.FrequencyUnit, cs.NextDue, fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO care_schedules").
		WithArgs(pgxmock.AnyArg(), cs.LivingThingID, cs.FrequencyValue, cs.FrequencyUnit, cs.NextDue, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateCareSchedule(context.Background(), cs)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetCareSchedule(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "living_thing_id", "frequency_value", "frequency_unit", "next_due", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), 7, "days", fixedTime(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM care_schedules WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	cs, err := repo.GetCareSchedule(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, cs.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetCareSchedule_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM care_schedules WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	cs, err := repo.GetCareSchedule(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, cs)
	assert.ErrorIs(t, err, ErrCareScheduleNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetCareScheduleByLivingThingID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	ltid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "living_thing_id", "frequency_value", "frequency_unit", "next_due", "created_at", "updated_at"}).
		AddRow(fixedUUID(), ltid, 7, "days", fixedTime(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM care_schedules WHERE living_thing_id = .*").
		WithArgs(ltid).
		WillReturnRows(rows)

	cs, err := repo.GetCareScheduleByLivingThingID(context.Background(), ltid)
	require.NoError(t, err)
	assert.NotNil(t, cs)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetCareScheduleByLivingThingID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	ltid := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM care_schedules WHERE living_thing_id = .*").
		WithArgs(ltid).
		WillReturnError(pgx.ErrNoRows)

	cs, err := repo.GetCareScheduleByLivingThingID(context.Background(), ltid)
	require.Error(t, err)
	assert.Nil(t, cs)
	assert.ErrorIs(t, err, ErrCareScheduleNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_UpdateCareSchedule(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "living_thing_id", "frequency_value", "frequency_unit", "next_due", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), 3, "days", fixedTime(), fixedTime(), fixedTime())

	mock.ExpectQuery("UPDATE care_schedules SET").
		WithArgs(3, "days", pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnRows(rows)

	cs := &models.CareSchedule{ID: id, FrequencyValue: 3, FrequencyUnit: "days"}
	updated, err := repo.UpdateCareSchedule(context.Background(), cs)
	require.NoError(t, err)
	assert.Equal(t, 3, updated.FrequencyValue)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_UpdateCareSchedule_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE care_schedules SET").
		WithArgs(3, "days", pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnError(pgx.ErrNoRows)

	cs := &models.CareSchedule{ID: id, FrequencyValue: 3, FrequencyUnit: "days"}
	updated, err := repo.UpdateCareSchedule(context.Background(), cs)
	require.Error(t, err)
	assert.Nil(t, updated)
	assert.ErrorIs(t, err, ErrCareScheduleNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_CreateCareLog(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)

	cl := &models.CareLog{
		CareScheduleID: fixedUUID(),
		UserID:         fixedUUID(),
		Notes:          "Watered",
	}

	rows := pgxmock.NewRows([]string{"id", "care_schedule_id", "user_id", "notes", "created_at"}).
		AddRow(fixedUUID(), cl.CareScheduleID, cl.UserID, cl.Notes, fixedTime())

	mock.ExpectQuery("INSERT INTO care_logs").
		WithArgs(pgxmock.AnyArg(), cl.CareScheduleID, cl.UserID, cl.Notes, pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateCareLog(context.Background(), cl)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_ListCareLogs(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	csid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "care_schedule_id", "user_id", "notes", "created_at"}).
		AddRow(fixedUUID(), csid, fixedUUID(), "Watered", fixedTime())

	mock.ExpectQuery("SELECT .* FROM care_logs WHERE care_schedule_id = .*").
		WithArgs(csid, 50, 0).
		WillReturnRows(rows)

	logs, err := repo.ListCareLogs(context.Background(), csid, 0, 0)
	require.NoError(t, err)
	assert.Len(t, logs, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_CreateSpeciesWiki(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)

	sw := &models.SpeciesWiki{
		CommonName:       "Weeping Fig",
		ScientificName:   "Ficus benjamina",
		CareInstructions: "Water weekly",
	}

	rows := pgxmock.NewRows([]string{"id", "common_name", "scientific_name", "care_instructions", "created_at", "updated_at"}).
		AddRow(fixedUUID(), sw.CommonName, sw.ScientificName, sw.CareInstructions, fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO species_wikis").
		WithArgs(pgxmock.AnyArg(), sw.CommonName, sw.ScientificName, sw.CareInstructions, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(rows)

	created, err := repo.CreateSpeciesWiki(context.Background(), sw)
	require.NoError(t, err)
	assert.NotNil(t, created)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetSpeciesWiki(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "common_name", "scientific_name", "care_instructions", "created_at", "updated_at"}).
		AddRow(id, "Weeping Fig", "Ficus benjamina", "Water weekly", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM species_wikis WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	sw, err := repo.GetSpeciesWiki(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, sw.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestLivingRepository_GetSpeciesWiki_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewLivingRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM species_wikis WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	sw, err := repo.GetSpeciesWiki(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, sw)
	assert.ErrorIs(t, err, ErrSpeciesWikiNotFound)
	assert.NoError(t, mock.ExpectationsWereMet())
}
