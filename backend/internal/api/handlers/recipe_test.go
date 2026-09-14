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
	user := createTestUser(t, "recipe@example.com", "Password123!")
	token := generateTestToken(user.ID)

	body := map[string]any{
		"title":       "Pasta",
		"description": "Italian dish",
		"prep_time":   10,
		"cook_time":   20,
		"servings":    2,
		"visibility":  models.RecipeVisibilityPrivate,
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
	user := createTestUser(t, "lsrecipe@example.com", "Password123!")
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
	user := createTestUser(t, "nfrecipe@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/recipes/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestRecipe_UpdateRecipe(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "uprecipe@example.com", "Password123!")
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
	user := createTestUser(t, "delrecipe@example.com", "Password123!")
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
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	rec := execRequest(t, router, "DELETE", "/api/v1/recipes/"+rcp.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

func TestRecipe_GetRecipeIngredients(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "ingredients@example.com", "Password123!")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Test Recipe",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	ing := &models.RecipeIngredient{
		ID:       uuid.New(),
		RecipeID: rcp.ID,
		Name:     "flour",
		Quantity: "2 cups",
		Unit:     "cups",
		Position: 1,
	}
	require.NoError(t, recipeRepo.CreateIngredient(context.Background(), ing))

	rec := execRequest(t, router, "GET", "/api/v1/recipes/"+rcp.ID.String()+"/ingredients", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
	assert.Equal(t, "flour", resp[0]["name"])
}

func TestRecipe_GetRecipeIngredients_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "nfingredients@example.com", "Password123!")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/recipes/"+uuid.New().String()+"/ingredients", nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestRecipe_GetRecipeSteps(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "steps@example.com", "Password123!")
	token := generateTestToken(user.ID)

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Test Recipe",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	step := &models.RecipeStep{
		ID:          uuid.New(),
		RecipeID:    rcp.ID,
		Description: "Mix ingredients",
		Position:    1,
	}
	require.NoError(t, recipeRepo.CreateStep(context.Background(), step))

	rec := execRequest(t, router, "GET", "/api/v1/recipes/"+rcp.ID.String()+"/steps", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
	assert.Equal(t, "Mix ingredients", resp[0]["description"])
}

func TestRecipe_AddToList(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "addtolist@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Recipe Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		ID:       uuid.New(),
		GroupID:  group.ID,
		UserID:   user.ID,
		Role:     "admin",
		JoinedAt: time.Now().UTC(),
	}))

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Test Recipe",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    2,
		ImageURL:    "",
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	ing := &models.RecipeIngredient{
		ID:       uuid.New(),
		RecipeID: rcp.ID,
		Name:     "sugar",
		Quantity: "1 cup",
		Unit:     "cup",
		Position: 1,
	}
	require.NoError(t, recipeRepo.CreateIngredient(context.Background(), ing))

	listRepo := newTestListRepo()
	lst := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Shopping",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), lst))

	body := map[string]any{"list_id": lst.ID.String()}
	rec := execRequest(t, router, "POST", "/api/v1/recipes/"+rcp.ID.String()+"/add-to-list", body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	added := resp["added"].([]any)
	assert.Len(t, added, 1)
}

func TestRecipe_AddMissingToList(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouter(t)
	user := createTestUser(t, "addmissing@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Recipe Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		ID:       uuid.New(),
		GroupID:  group.ID,
		UserID:   user.ID,
		Role:     "admin",
		JoinedAt: time.Now().UTC(),
	}))

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:          uuid.New(),
		UserID:      user.ID,
		Title:       "Test Recipe",
		Description: "",
		PrepTime:    0,
		CookTime:    0,
		Servings:    1,
		ImageURL:    "",
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	ing := &models.RecipeIngredient{
		ID:       uuid.New(),
		RecipeID: rcp.ID,
		Name:     "salt",
		Quantity: "1 tsp",
		Unit:     "tsp",
		Position: 1,
	}
	require.NoError(t, recipeRepo.CreateIngredient(context.Background(), ing))

	listRepo := newTestListRepo()
	lst := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Shopping",
		Type:      "shopping",
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, listRepo.CreateList(context.Background(), lst))

	body := map[string]any{"list_id": lst.ID.String()}
	rec := execRequest(t, router, "POST", "/api/v1/recipes/"+rcp.ID.String()+"/add-missing-to-list", body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	added := resp["added"].([]any)
	assert.Len(t, added, 1)
}

// TestRecipe_AddToList_CanonicalResolution verifies that when a recipe ingredient
// matches a seeded alias, the created list item carries canonical_item_id.
func TestRecipe_AddToList_CanonicalResolution(t *testing.T) {
	clearTables(t)
	router, _ := newRecipeRouterWithGrocery(t)
	user := createTestUser(t, "canonicallist@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Recipe Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		ID:       uuid.New(),
		GroupID:  group.ID,
		UserID:   user.ID,
		Role:     "admin",
		JoinedAt: time.Now().UTC(),
	}))

	// The global grocery rows reference the all-zero "global" group id via a FK,
	// so that group must exist before seeding canonical_items / item_aliases.
	now := time.Now().UTC()
	_, err := testDB.Exec(context.Background(), `
		INSERT INTO groups (id, name, created_by, created_at, updated_at)
		VALUES ('00000000-0000-0000-0000-000000000000', 'Global', $1, $2, $2)
		ON CONFLICT (id) DO NOTHING`,
		user.ID, now)
	require.NoError(t, err)

	// Seed a canonical item and a global alias ("sugar" → canonicalID).
	canonicalID := uuid.New()
	_, err = testDB.Exec(context.Background(), `
		INSERT INTO canonical_items (id, group_id, name_de, name_en, category, default_unit, is_global, version, created_at, updated_at)
		VALUES ($1, '00000000-0000-0000-0000-000000000000', 'Zucker', 'sugar', 'pantry', 'g', true, 1, $2, $2)`,
		canonicalID, now)
	require.NoError(t, err)

	_, err = testDB.Exec(context.Background(), `
		INSERT INTO item_aliases (id, group_id, canonical_item_id, alias_text, lang, source, weight, version, created_at, updated_at)
		VALUES ($1, '00000000-0000-0000-0000-000000000000', $2, 'sugar', 'en', 'seed', 1, 1, $3, $3)`,
		uuid.New(), canonicalID, now)
	require.NoError(t, err)

	recipeRepo := newTestRecipeRepo()
	rcp := &models.Recipe{
		ID:        uuid.New(),
		UserID:    user.ID,
		Title:     "Sweet Recipe",
		Servings:  2,
		CreatedAt: now,
		UpdatedAt: now,
	}
	require.NoError(t, recipeRepo.CreateRecipe(context.Background(), rcp))

	ing := &models.RecipeIngredient{
		ID:       uuid.New(),
		RecipeID: rcp.ID,
		Name:     "sugar",
		Quantity: "1 cup",
		Unit:     "cup",
		Position: 1,
	}
	require.NoError(t, recipeRepo.CreateIngredient(context.Background(), ing))

	listRepo := newTestListRepo()
	lst := &models.List{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Name:      "Shopping",
		Type:      "shopping",
		CreatedAt: now,
		UpdatedAt: now,
	}
	require.NoError(t, listRepo.CreateList(context.Background(), lst))

	body := map[string]any{"list_id": lst.ID.String()}
	rec := execRequest(t, router, "POST", "/api/v1/recipes/"+rcp.ID.String()+"/add-to-list", body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	added := resp["added"].([]any)
	require.Len(t, added, 1)

	item := added[0].(map[string]any)
	assert.Equal(t, canonicalID.String(), item["canonical_item_id"],
		"list item should carry the resolved canonical_item_id")
}
