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

func TestRecipe_CreateRecipe(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "recipe@example.com", "password123")
	token := generateTestToken(user.ID)

	body := map[string]any{
		"title":       "Pasta",
		"description": "Italian dish",
		"prep_time":   10,
		"cook_time":   20,
		"servings":    2,
		"is_public":   false,
	}
	rec := execRequest(t, router, "POST", "/api/v1/recipes", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Pasta", resp["title"])
}

func TestRecipe_ListRecipes(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "lsrecipe@example.com", "password123")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Soup",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		IsPublic:    false,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/recipes?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestRecipe_GetRecipe_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "nfrecipe@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/recipes/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestRecipe_UpdateRecipe(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "uprecipe@example.com", "password123")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Old",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		IsPublic:    false,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	body := map[string]any{"title": "New Title"}
	rec := execRequest(t, router, "PATCH", "/api/v1/recipes/"+rcp.ID.String(), body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "New Title", resp["title"])
}

func TestRecipe_DeleteRecipe(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "delrecipe@example.com", "password123")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Del",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		IsPublic:    false,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	rec := execRequest(t, router, "DELETE", "/api/v1/recipes/"+rcp.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestRecipe_CreateCollection(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "col@example.com", "password123")
	token := generateTestToken(user.ID)

	body := map[string]any{"name": "Favorites"}
	rec := execRequest(t, router, "POST", "/api/v1/collections", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Favorites", resp["name"])
}

func TestRecipe_ListCollections(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "lscol@example.com", "password123")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	require.NoError(t, recipeRepo.CreateCollection(context.Background(), &models.Collection{
		ID:        uuid.New(),
		UserID:    user.ID,
		Name:      "My Collection",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/collections?limit=10", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
