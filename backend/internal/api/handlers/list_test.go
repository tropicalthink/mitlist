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

func TestList_CreateList(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "list@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "List Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{"group_id": group.ID.String(), "name": "Shopping", "type": "shopping"}
	rec := execRequest(t, router, "POST", "/api/v1/lists", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Shopping", resp["name"])
}

func TestList_CreateList_Unauthorized(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)

	body := map[string]any{"name": "Shopping", "type": "shopping"}
	rec := execRequest(t, router, "POST", "/api/v1/lists", body, "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestList_GetList(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "getlist@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))

	rec := execRequest(t, router, "GET", "/api/v1/lists/"+list.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "My List", resp["name"])
}

func TestList_GetList_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "nflist@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/lists/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestList_UpdateList(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "updatelist@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Old",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))

	body := map[string]any{"name": "New Name", "type": "todo"}
	rec := execRequest(t, router, "PATCH", "/api/v1/lists/"+list.ID.String(), body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "New Name", resp["name"])
}

func TestList_DeleteList(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "dellist@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "ToDelete",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))

	rec := execRequest(t, router, "DELETE", "/api/v1/lists/"+list.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)

	rec = execRequest(t, router, "GET", "/api/v1/lists/"+list.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestList_CreateItem(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "item@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))

	body := map[string]any{"name": "Milk", "quantity": 2, "unit": "L"}
	rec := execRequest(t, router, "POST", "/api/v1/lists/"+list.ID.String()+"/items", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Milk", resp["name"])
}

func TestList_ListItems(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "listitems@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))
	item := &models.ListItem{
		ID:        uuid.New(),
		ListID:    list.ID,
		Name:      "Eggs",
		Quantity:  12,
		Unit:      "pcs",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateItem(context.Background(), item))

	rec := execRequest(t, router, "GET", "/api/v1/lists/"+list.ID.String()+"/items", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestList_UpdateItem(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "upditem@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))
	item := &models.ListItem{
		ID:        uuid.New(),
		ListID:    list.ID,
		Name:      "Bread",
		Quantity:  1,
		Unit:      "loaf",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateItem(context.Background(), item))

	body := map[string]any{"name": "Sourdough", "quantity": 2, "unit": "loaf", "checked": true, "position": 1}
	rec := execRequest(t, router, "PATCH", "/api/v1/lists/"+list.ID.String()+"/items/"+item.ID.String(), body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Sourdough", resp["name"])
}

func TestList_DeleteItem(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "delitem@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))
	item := &models.ListItem{
		ID:        uuid.New(),
		ListID:    list.ID,
		Name:      "Butter",
		Quantity:  1,
		Unit:      "pack",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateItem(context.Background(), item))

	rec := execRequest(t, router, "DELETE", "/api/v1/lists/"+list.ID.String()+"/items/"+item.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestList_ReorderItems(t *testing.T) {
	clearTables(t)
	router, _ := newListRouter(t)
	user := createTestUser(t, "reorder@example.com", "password123")
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
	listRepo := newTestListRepo()
	list := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "My List",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), list))
	item1 := &models.ListItem{
		ID:        uuid.New(),
		ListID:    list.ID,
		Name:      "A",
		Quantity:  1,
		Unit:      "u",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateItem(context.Background(), item1))
	item2 := &models.ListItem{
		ID:        uuid.New(),
		ListID:    list.ID,
		Name:      "B",
		Quantity:  1,
		Unit:      "u",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateItem(context.Background(), item2))

	body := map[string]any{"item_ids": []string{item2.ID.String(), item1.ID.String()}}
	rec := execRequest(t, router, "POST", "/api/v1/lists/"+list.ID.String()+"/reorder", body, token)
	requireStatus(t, rec, http.StatusNoContent)
}
