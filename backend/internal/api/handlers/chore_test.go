package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestChore_CreateChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "chore@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Chore Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{
		"group_id":      group.ID.String(),
		"name":          "Vacuum",
		"rotation_type": "round_robin",
		"frequency":     "weekly",
		"is_active":     true,
	}
	rec := execRequest(t, router, "POST", "/api/v1/chores", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Vacuum", resp["name"])
}

func TestChore_ListChores(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "lschore@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	require.NoError(t, choreRepo.CreateChore(context.Background(), &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Dust",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/chores?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestChore_ListCurrentChores(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "currentchore@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Dust",
		RotationType: "schedule",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))
	due := time.Now().UTC().Add(24 * time.Hour)
	require.NoError(t, choreRepo.CreateAssignment(context.Background(), &models.ChoreAssignment{
		ID:         uuid.New(),
		ChoreID:    chore.ID,
		UserID:     user.ID,
		Status:     "pending",
		DueDate:    &due,
		AssignedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/chores/current?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	require.Len(t, resp, 1)
	assert.Equal(t, true, resp[0]["assigned_to_me"])
	assert.NotEmpty(t, resp[0]["due_status"])
	assert.NotNil(t, resp[0]["pending_assignment"])
}

func TestChore_GetChore_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "nfchore@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/chores/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestChore_UpdateChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "upchore@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Old",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))

	body := map[string]any{"name": "New", "rotation_type": "round_robin", "frequency": "daily", "is_active": true}
	rec := execRequest(t, router, "PATCH", "/api/v1/chores/"+chore.ID.String(), body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "New", resp["name"])
}

func TestChore_DeleteChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "delchore@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "ToDelete",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))

	rec := execRequest(t, router, "DELETE", "/api/v1/chores/"+chore.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestChore_RotateChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "rot@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Rotate",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))
	require.NoError(t, choreRepo.CreateRotationState(context.Background(), &models.ChoreRotationState{
		ID:           uuid.New(),
		ChoreID:      chore.ID,
		MemberOrder:  []uuid.UUID{user.ID},
		CurrentIndex: 0,
	}))

	rec := execRequest(t, router, "POST", "/api/v1/chores/"+chore.ID.String()+"/rotate", nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestChore_CompleteChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "comp@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Complete",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))
	require.NoError(t, choreRepo.CreateAssignment(context.Background(), &models.ChoreAssignment{
		ID:         uuid.New(),
		ChoreID:    chore.ID,
		UserID:     user.ID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}))

	body := map[string]any{"notes": "Done"}
	rec := execRequest(t, router, "POST", "/api/v1/chores/"+chore.ID.String()+"/complete", body, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestChore_RescheduleChore(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "reschedule@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "Reschedule",
		RotationType: "schedule",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))
	require.NoError(t, choreRepo.CreateAssignment(context.Background(), &models.ChoreAssignment{
		ID:         uuid.New(),
		ChoreID:    chore.ID,
		UserID:     user.ID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}))

	newDue := time.Now().UTC().Add(72 * time.Hour)
	body := map[string]any{"due_date": newDue.Format(time.RFC3339)}
	rec := execRequest(t, router, "PATCH", "/api/v1/chores/"+chore.ID.String()+"/pending", body, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestChore_GetAssignments(t *testing.T) {
	clearTables(t)
	router, _ := newChoreRouter(t)
	user := createTestUser(t, "ass@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	choreRepo := newTestChoreRepo()
	chore := &models.Chore{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "A",
		RotationType: "round_robin",
		Frequency:    "weekly",
		IsActive:     true,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	require.NoError(t, choreRepo.CreateChore(context.Background(), chore))
	require.NoError(t, choreRepo.CreateAssignment(context.Background(), &models.ChoreAssignment{
		ID:         uuid.New(),
		ChoreID:    chore.ID,
		UserID:     user.ID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/chores/"+chore.ID.String()+"/assignments", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
