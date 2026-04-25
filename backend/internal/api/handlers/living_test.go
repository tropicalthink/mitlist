package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/models"
)

func TestLiving_CreateLivingThing(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "living@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Living Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{
		"group_id": group.ID.String(),
		"name":     "Fern",
		"species":  "Nephrolepis",
	}
	rec := execRequest(t, router, "POST", "/living-things", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Fern", resp["name"])
}

func TestLiving_ListLivingThings(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "lsliving@example.com", "password123")
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
	livingRepo := newTestLivingRepo()
	_, err := livingRepo.CreateLivingThing(context.Background(), &models.LivingThing{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Cactus",
		Species:   "Cactaceae",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/living-things?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestLiving_GetLivingThing(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "getliving@example.com", "password123")
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
	livingRepo := newTestLivingRepo()
	lt, err := livingRepo.CreateLivingThing(context.Background(), &models.LivingThing{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Rose",
		Species:   "Rosa",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/living-things/"+lt.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Rose", resp["name"])
}

func TestLiving_DeleteLivingThing(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "delliving@example.com", "password123")
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
	livingRepo := newTestLivingRepo()
	lt, err := livingRepo.CreateLivingThing(context.Background(), &models.LivingThing{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "ToDelete",
		Species:   "Unknown",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "DELETE", "/living-things/"+lt.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestLiving_CreateCareSchedule(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "care@example.com", "password123")
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
	livingRepo := newTestLivingRepo()
	lt, err := livingRepo.CreateLivingThing(context.Background(), &models.LivingThing{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Fern",
		Species:   "Nephrolepis",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)

	body := map[string]any{
		"frequency_value": 7,
		"frequency_unit":  "days",
		"next_due":        time.Now().Add(24 * time.Hour).Format(time.RFC3339),
	}
	rec := execRequest(t, router, "POST", "/living-things/"+lt.ID.String()+"/care-schedule", body, token)
	requireStatus(t, rec, http.StatusCreated)
}

func TestLiving_ListCareLogs(t *testing.T) {
	clearTables(t)
	router, _ := newLivingRouter(t)
	user := createTestUser(t, "carelog@example.com", "password123")
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
	livingRepo := newTestLivingRepo()
	lt, err := livingRepo.CreateLivingThing(context.Background(), &models.LivingThing{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Fern",
		Species:   "Nephrolepis",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	})
	require.NoError(t, err)
	cs, err := livingRepo.CreateCareSchedule(context.Background(), &models.CareSchedule{
		ID:             uuid.New(),
		LivingThingID:  lt.ID,
		FrequencyValue: 7,
		FrequencyUnit:  "days",
		NextDue:        time.Now().Add(24 * time.Hour),
		CreatedAt:      time.Now().UTC(),
		UpdatedAt:      time.Now().UTC(),
	})
	require.NoError(t, err)
	_, err = livingRepo.CreateCareLog(context.Background(), &models.CareLog{
		ID:             uuid.New(),
		CareScheduleID: cs.ID,
		UserID:         user.ID,
		Notes:          "Watered",
		CreatedAt:      time.Now().UTC(),
	})
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/living-things/"+lt.ID.String()+"/care-logs", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
