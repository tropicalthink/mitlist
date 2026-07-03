package repositories

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestChoreRepository_CreateChore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	chore := &models.Chore{
		GroupID:      fixedUUID(),
		Name:         "Vacuum",
		Description:  strPtr("Living room"),
		RotationType: "schedule",
		Frequency:    "weekly",
		IsActive:     true,
	}

	rows := pgxmock.NewRows([]string{"created_at", "updated_at"}).
		AddRow(fixedTime(), fixedTime())

	mock.ExpectQuery("INSERT INTO chores").
		WithArgs(
			pgxmock.AnyArg(), chore.GroupID, chore.Name, chore.Description,
			chore.RotationType, chore.Frequency, chore.PeriodInterval, []string{},
			chore.StartDate, chore.TrackDateOnly, chore.Rollover, chore.AssignmentType,
			[]uuid.UUID{}, chore.IsActive, chore.Supplies, chore.Category,
		).
		WillReturnRows(rows)

	err := repo.CreateChore(context.Background(), chore)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, chore.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetChoreByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows(choreColumns()).
		AddRow(choreRowValues(id, fixedUUID(), "Vacuum", nil, "schedule", "weekly", true)...)

	mock.ExpectQuery("SELECT .* FROM chores WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	chore, err := repo.GetChoreByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, chore.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetChoreByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM chores WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	chore, err := repo.GetChoreByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, chore)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_ListChoresByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows(choreColumns()).
		AddRow(choreRowValues(fixedUUID(), gid, "Vacuum", nil, "schedule", "weekly", true)...)

	mock.ExpectQuery("SELECT .* FROM chores WHERE group_id = .*").
		WithArgs(gid, 50, 0).
		WillReturnRows(rows)

	chores, err := repo.ListChoresByGroup(context.Background(), gid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, chores, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateChore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"updated_at"}).AddRow(fixedTime())

	mock.ExpectQuery("UPDATE chores SET").
		WithArgs(
			"Mop", pgxmock.AnyArg(), "schedule", "daily", 0, []string(nil),
			pgxmock.AnyArg(), false, false, "", []uuid.UUID(nil), false, []string(nil), pgxmock.AnyArg(), id,
		).
		WillReturnRows(rows)

	chore := &models.Chore{ID: id, Name: "Mop", RotationType: "schedule", Frequency: "daily", IsActive: false}
	err := repo.UpdateChore(context.Background(), chore)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateChore_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("UPDATE chores SET").
		WithArgs(
			"Mop", pgxmock.AnyArg(), "schedule", "daily", 0, []string(nil),
			pgxmock.AnyArg(), false, false, "", []uuid.UUID(nil), false, []string(nil), pgxmock.AnyArg(), id,
		).
		WillReturnError(pgx.ErrNoRows)

	chore := &models.Chore{ID: id, Name: "Mop", RotationType: "schedule", Frequency: "daily", IsActive: false}
	err := repo.UpdateChore(context.Background(), chore)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_DeleteChore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chores WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteChore(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_DeleteChore_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chores WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteChore(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CreateRotationState(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	state := &models.ChoreRotationState{
		ChoreID:      fixedUUID(),
		MemberOrder:  []uuid.UUID{fixedUUID(), fixedUUID()},
		CurrentIndex: 0,
	}

	mock.ExpectExec("INSERT INTO chore_rotation_states").
		WithArgs(pgxmock.AnyArg(), state.ChoreID, state.MemberOrder, state.CurrentIndex).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateRotationState(context.Background(), state)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, state.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetRotationState(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "chore_id", "member_order", "current_index"}).
		AddRow(fixedUUID(), choreID, []uuid.UUID{fixedUUID()}, 0)

	mock.ExpectQuery("SELECT .* FROM chore_rotation_states WHERE chore_id = .*").
		WithArgs(choreID).
		WillReturnRows(rows)

	state, err := repo.GetRotationState(context.Background(), choreID)
	require.NoError(t, err)
	assert.Equal(t, choreID, state.ChoreID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetRotationState_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM chore_rotation_states WHERE chore_id = .*").
		WithArgs(choreID).
		WillReturnError(pgx.ErrNoRows)

	state, err := repo.GetRotationState(context.Background(), choreID)
	require.Error(t, err)
	assert.Nil(t, state)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateRotationState(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE chore_rotation_states SET").
		WithArgs(pgxmock.AnyArg(), 1, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	state := &models.ChoreRotationState{ID: id, MemberOrder: []uuid.UUID{fixedUUID()}, CurrentIndex: 1}
	err := repo.UpdateRotationState(context.Background(), state)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateRotationState_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE chore_rotation_states SET").
		WithArgs(pgxmock.AnyArg(), 1, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	state := &models.ChoreRotationState{ID: id, MemberOrder: []uuid.UUID{fixedUUID()}, CurrentIndex: 1}
	err := repo.UpdateRotationState(context.Background(), state)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CreateAssignment(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	assignment := &models.ChoreAssignment{
		ChoreID:    fixedUUID(),
		UserID:     fixedUUID(),
		Status:     "pending",
		AssignedAt: fixedTime(),
	}

	mock.ExpectExec("INSERT INTO chore_assignments").
		WithArgs(pgxmock.AnyArg(), assignment.ChoreID, assignment.UserID, assignment.Status, pgxmock.AnyArg(), assignment.AssignedAt, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateAssignment(context.Background(), assignment)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, assignment.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_ListAssignments(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "chore_id", "user_id", "status", "due_date", "assigned_at", "completed_at", "skip_reason"}).
		AddRow(fixedUUID(), choreID, fixedUUID(), "pending", nil, fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM chore_assignments WHERE chore_id = .*").
		WithArgs(choreID, 50, 0).
		WillReturnRows(rows)

	assignments, err := repo.ListAssignments(context.Background(), choreID, 50, 0)
	require.NoError(t, err)
	assert.Len(t, assignments, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateAssignment(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE chore_assignments SET").
		WithArgs(fixedUUID(), "completed", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	assignment := &models.ChoreAssignment{ID: id, UserID: fixedUUID(), Status: "completed"}
	err := repo.UpdateAssignment(context.Background(), assignment)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_UpdateAssignment_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE chore_assignments SET").
		WithArgs(fixedUUID(), "completed", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	assignment := &models.ChoreAssignment{ID: id, UserID: fixedUUID(), Status: "completed"}
	err := repo.UpdateAssignment(context.Background(), assignment)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_DeleteAssignment(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM chore_assignments WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteAssignment(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CreateCompletion(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	completion := &models.ChoreCompletion{
		AssignmentID: fixedUUID(),
		CompletedBy:  fixedUUID(),
		CompletedAt:  fixedTime(),
		Notes:        strPtr("Done"),
	}

	mock.ExpectExec("INSERT INTO chore_completions").
		WithArgs(pgxmock.AnyArg(), completion.AssignmentID, completion.CompletedBy, completion.CompletedAt, completion.Notes).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateCompletion(context.Background(), completion)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, completion.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetPendingAssignmentByChore(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "chore_id", "user_id", "status", "due_date", "assigned_at", "completed_at", "skip_reason"}).
		AddRow(fixedUUID(), choreID, fixedUUID(), "pending", nil, fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM chore_assignments WHERE chore_id = .* AND status = 'pending'").
		WithArgs(choreID).
		WillReturnRows(rows)

	assignment, err := repo.GetPendingAssignmentByChore(context.Background(), choreID)
	require.NoError(t, err)
	assert.Equal(t, "pending", assignment.Status)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetPendingAssignmentByChore_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM chore_assignments WHERE chore_id = .* AND status = 'pending'").
		WithArgs(choreID).
		WillReturnError(pgx.ErrNoRows)

	assignment, err := repo.GetPendingAssignmentByChore(context.Background(), choreID)
	require.Error(t, err)
	assert.Nil(t, assignment)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_ListDueAssignmentsByGroup_IncludesChoreName(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	groupID := fixedUUID()
	from := fixedTime()
	to := from.Add(24 * time.Hour)

	rows := pgxmock.NewRows([]string{"id", "chore_id", "user_id", "status", "due_date", "assigned_at", "completed_at", "skip_reason", "name"}).
		AddRow(fixedUUID(), fixedUUID(), fixedUUID(), "pending", &from, fixedTime(), nil, nil, "Dishes")

	mock.ExpectQuery("SELECT .* FROM chore_assignments a").
		WithArgs(groupID, from, to).
		WillReturnRows(rows)

	assignments, err := repo.ListDueAssignmentsByGroup(context.Background(), groupID, from, to)
	require.NoError(t, err)
	require.Len(t, assignments, 1)
	assert.Equal(t, "Dishes", assignments[0].ChoreName)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_BulkUpdateRotationStates(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	stateID := fixedUUID()
	memberID := fixedUUID()

	mock.ExpectExec("UPDATE chore_rotation_states AS crs").
		WithArgs([]uuid.UUID{stateID}, [][]uuid.UUID{{memberID}}, []int32{0}).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.BulkUpdateRotationStates(context.Background(), []models.ChoreRotationState{{
		ID: stateID, MemberOrder: []uuid.UUID{memberID}, CurrentIndex: 0,
	}})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_GetRotationStatesByChoreIDs(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)
	choreID := fixedUUID()
	missingID := uuid.New()
	stateID := uuid.New()
	memberID := uuid.New()

	rows := pgxmock.NewRows([]string{"id", "chore_id", "member_order", "current_index"}).
		AddRow(stateID, choreID, []uuid.UUID{memberID}, 0)
	mock.ExpectQuery("SELECT id, chore_id, member_order, current_index").
		WithArgs([]uuid.UUID{choreID, missingID}).
		WillReturnRows(rows)

	states, err := repo.GetRotationStatesByChoreIDs(context.Background(), []uuid.UUID{choreID, missingID})
	require.NoError(t, err)
	require.Len(t, states, 1)
	assert.Equal(t, choreID, states[0].ChoreID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CompleteAssignmentAndAdvance_FullAdvance(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	assignID := uuid.New()
	completion := &models.ChoreCompletion{
		AssignmentID: assignID,
		CompletedBy:  fixedUUID(),
		CompletedAt:  fixedTime(),
	}
	nextState := &models.ChoreRotationState{
		ID:           uuid.New(),
		MemberOrder:  []uuid.UUID{fixedUUID()},
		CurrentIndex: 1,
	}
	nextAssignment := &models.ChoreAssignment{
		ChoreID:    fixedUUID(),
		UserID:     fixedUUID(),
		Status:     "pending",
		AssignedAt: fixedTime(),
	}

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE chore_assignments").
		WithArgs("completed", fixedTime(), (*string)(nil), assignID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO chore_completions").
		WithArgs(pgxmock.AnyArg(), assignID, completion.CompletedBy, completion.CompletedAt, completion.Notes).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectExec("UPDATE chore_rotation_states").
		WithArgs(nextState.MemberOrder, nextState.CurrentIndex, nextState.ID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO chore_assignments").
		WithArgs(pgxmock.AnyArg(), nextAssignment.ChoreID, nextAssignment.UserID,
			nextAssignment.Status, nextAssignment.DueDate, nextAssignment.AssignedAt,
			nextAssignment.CompletedAt, nextAssignment.SkipReason).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	processed, err := repo.CompleteAssignmentAndAdvance(context.Background(), assignID, "completed", fixedTime(), nil, completion, nextState, nextAssignment)
	require.NoError(t, err)
	assert.True(t, processed)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CompleteAssignmentAndAdvance_AlreadyProcessed(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	assignID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE chore_assignments").
		WithArgs("completed", fixedTime(), (*string)(nil), assignID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	mock.ExpectRollback()

	completion := &models.ChoreCompletion{AssignmentID: assignID}
	nextState := &models.ChoreRotationState{ID: uuid.New()}
	nextAssignment := &models.ChoreAssignment{ChoreID: fixedUUID()}

	processed, err := repo.CompleteAssignmentAndAdvance(context.Background(), assignID, "completed", fixedTime(), nil, completion, nextState, nextAssignment)
	require.NoError(t, err)
	assert.False(t, processed)
	// No completion insert and no rotation update/insert should have happened.
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestChoreRepository_CompleteAssignmentAndAdvance_NoAdvance(t *testing.T) {
	mock := newMockDB(t)
	repo := NewChoreRepository(mock)

	assignID := uuid.New()
	completion := &models.ChoreCompletion{AssignmentID: assignID, CompletedBy: fixedUUID(), CompletedAt: fixedTime()}

	mock.ExpectBegin()
	mock.ExpectExec("UPDATE chore_assignments").
		WithArgs("completed", fixedTime(), (*string)(nil), assignID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO chore_completions").
		WithArgs(pgxmock.AnyArg(), assignID, completion.CompletedBy, completion.CompletedAt, completion.Notes).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	// nil nextState/nextAssignment => no rotation advance (e.g. no-assignment chore).
	processed, err := repo.CompleteAssignmentAndAdvance(context.Background(), assignID, "completed", fixedTime(), nil, completion, nil, nil)
	require.NoError(t, err)
	assert.True(t, processed)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func choreColumns() []string {
	return []string{
		"id", "group_id", "name", "description", "rotation_type", "frequency",
		"period_interval", "period_config", "start_date", "track_date_only", "rollover",
		"assignment_type", "assignment_config", "is_active", "supplies", "category", "created_at", "updated_at",
	}
}

func choreRowValues(id, groupID uuid.UUID, name string, description any, rotationType, frequency string, isActive bool) []any {
	return []any{
		id, groupID, name, description, rotationType, frequency,
		1, []string{}, nil, false, false,
		"round-robin", []uuid.UUID{}, isActive, []string(nil), (*string)(nil), fixedTime(), fixedTime(),
	}
}
