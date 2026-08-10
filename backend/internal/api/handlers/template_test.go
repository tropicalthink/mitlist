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

func TestTemplate_CreateTemplate(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "tpl@example.com", "password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "TPL Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{"group_id": group.ID.String(), "name": "Weekly Shop"}
	rec := execRequest(t, router, "POST", "/api/v1/templates", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Weekly Shop", resp["name"])
}

func TestTemplate_ListTemplates(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "lstpl@example.com", "password123!")
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
	addTestMembership(t, group.ID, user.ID, "admin")
	templateRepo := newTestTemplateRepo()
	require.NoError(t, templateRepo.CreateTemplate(context.Background(), &models.Template{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "T1",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/templates?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestTemplate_GetTemplate_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "nftpl@example.com", "password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/templates/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestTemplate_DeleteTemplate(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "deltpl@example.com", "password123!")
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
	addTestMembership(t, group.ID, user.ID, "admin")
	templateRepo := newTestTemplateRepo()
	tpl := &models.Template{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "ToDelete",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, templateRepo.CreateTemplate(context.Background(), tpl))

	rec := execRequest(t, router, "DELETE", "/api/v1/templates/"+tpl.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestTemplate_CreateChoreTemplate(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "ctpl@example.com", "password123!")
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
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id":      group.ID.String(),
		"name":          "Clean",
		"rotation_type": "round_robin",
		"frequency":     "weekly",
	}
	rec := execRequest(t, router, "POST", "/api/v1/chore-templates", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Clean", resp["name"])
}

func TestTemplate_ListChoreTemplates(t *testing.T) {
	clearTables(t)
	router, _ := newTemplateRouter(t)
	user := createTestUser(t, "lctpl@example.com", "password123!")
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
	addTestMembership(t, group.ID, user.ID, "admin")
	templateRepo := newTestTemplateRepo()
	require.NoError(t, templateRepo.CreateChoreTemplate(context.Background(), &models.ChoreTemplate{
		ID:           uuid.New(),
		GroupID:      group.ID,
		Name:         "CT1",
		RotationType: "round_robin",
		Frequency:    "weekly",
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/chore-templates?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
