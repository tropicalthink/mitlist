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

func TestRecipeRepo_CreateRecipe(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	rec := &models.Recipe{
		UserID:      fixedUUID(),
		Title:       "Pasta",
		Description: "Italian",
		PrepTime:    10,
		CookTime:    20,
		Servings:    4,
		ImageURL:    "https://example.com/pasta.jpg",
		IsPublic:    true,
	}

	mock.ExpectExec("INSERT INTO recipes").
		WithArgs(pgxmock.AnyArg(), rec.UserID, rec.Title, rec.Description, rec.DescriptionShort, rec.Author, rec.RatingValue, rec.RatingCount, rec.NutritionJSON, rec.VideoURL, rec.EquipmentJSON, rec.SourceURL, rec.ImageURL, rec.ImageOptions, rec.Tags, rec.PrepTime, rec.CookTime, rec.Servings, rec.IsPublic, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateRecipe(context.Background(), rec)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, rec.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetRecipeByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "title", "description", "description_short", "author", "rating_value", "rating_count", "nutrition_json", "video_url", "equipment_json", "source_url", "image_url", "image_options", "tags", "prep_time", "cook_time", "servings", "is_public", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Pasta", "Italian", "", "", 0, 0, "", "", "", "", "url", nil, nil, 10, 20, 4, true, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM recipes WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	rec, err := repo.GetRecipeByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, rec.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetRecipeByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM recipes WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	rec, err := repo.GetRecipeByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, rec)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_ListRecipesByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	uid := fixedUUID()

	cols := []string{"id", "user_id", "title", "description", "description_short", "author", "rating_value", "rating_count", "nutrition_json", "video_url", "equipment_json", "source_url", "image_url", "image_options", "tags", "prep_time", "cook_time", "servings", "is_public", "created_at", "updated_at"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), uid, "Pasta", "Italian", "", "", 0, 0, "", "", "", "", "url", nil, nil, 10, 20, 4, true, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM recipes WHERE user_id = .*").
		WithArgs(uid, 50, 0).
		WillReturnRows(rows)

	recipes, err := repo.ListRecipesByUser(context.Background(), uid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, recipes, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateRecipe(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipes SET").
		WithArgs("New Title", "New Desc", "", "", 0.0, 0, "", "", "", "", "newurl", []string(nil), []string(nil), 5, 15, 2, false, pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	rec := &models.Recipe{ID: id, Title: "New Title", Description: "New Desc", PrepTime: 5, CookTime: 15, Servings: 2, ImageURL: "newurl", IsPublic: false}
	err := repo.UpdateRecipe(context.Background(), rec)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateRecipe_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipes SET").
		WithArgs("New Title", "New Desc", "", "", 0.0, 0, "", "", "", "", "newurl", []string(nil), []string(nil), 5, 15, 2, false, pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	rec := &models.Recipe{ID: id, Title: "New Title", Description: "New Desc", PrepTime: 5, CookTime: 15, Servings: 2, ImageURL: "newurl", IsPublic: false}
	err := repo.UpdateRecipe(context.Background(), rec)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteRecipe(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM recipe_ingredients WHERE recipe_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectExec("DELETE FROM recipe_steps WHERE recipe_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectExec("DELETE FROM recipes WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectCommit()

	err := repo.DeleteRecipe(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteRecipe_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM recipe_ingredients WHERE recipe_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("DELETE FROM recipe_steps WHERE recipe_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("DELETE FROM recipes WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectRollback()

	err := repo.DeleteRecipe(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_CreateIngredient(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	ing := &models.RecipeIngredient{
		RecipeID: fixedUUID(),
		Name:     "Flour",
		Quantity: "200",
		Unit:     "g",
		Position: 1,
	}

	mock.ExpectExec("INSERT INTO recipe_ingredients").
		WithArgs(pgxmock.AnyArg(), ing.RecipeID, ing.Name, ing.Quantity, ing.Unit, ing.RawText, ing.Position).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateIngredient(context.Background(), ing)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, ing.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_ListIngredients(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	rid := fixedUUID()

	cols := []string{"id", "recipe_id", "name", "quantity", "unit", "raw_text", "position"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), rid, "Flour", "200", "g", "200 g flour", 1)

	mock.ExpectQuery("SELECT .* FROM recipe_ingredients WHERE recipe_id = .*").
		WithArgs(rid).
		WillReturnRows(rows)

	ingredients, err := repo.ListIngredients(context.Background(), rid)
	require.NoError(t, err)
	assert.Len(t, ingredients, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateIngredient(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipe_ingredients SET").
		WithArgs("Sugar", "100", "g", "", 2, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	ing := &models.RecipeIngredient{ID: id, Name: "Sugar", Quantity: "100", Unit: "g", Position: 2}
	err := repo.UpdateIngredient(context.Background(), ing)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateIngredient_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipe_ingredients SET").
		WithArgs("Sugar", "100", "g", "", 2, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	ing := &models.RecipeIngredient{ID: id, Name: "Sugar", Quantity: "100", Unit: "g", Position: 2}
	err := repo.UpdateIngredient(context.Background(), ing)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteIngredient(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recipe_ingredients WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteIngredient(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteIngredient_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recipe_ingredients WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteIngredient(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_CreateStep(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	step := &models.RecipeStep{
		RecipeID:    fixedUUID(),
		Description: "Boil water",
		Position:    1,
	}

	mock.ExpectExec("INSERT INTO recipe_steps").
		WithArgs(pgxmock.AnyArg(), step.RecipeID, step.Name, step.Description, step.Position).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateStep(context.Background(), step)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, step.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_ListSteps(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	rid := fixedUUID()

	cols := []string{"id", "recipe_id", "name", "description", "position"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), rid, "", "Boil water", 1)

	mock.ExpectQuery("SELECT .* FROM recipe_steps WHERE recipe_id = .*").
		WithArgs(rid).
		WillReturnRows(rows)

	steps, err := repo.ListSteps(context.Background(), rid)
	require.NoError(t, err)
	assert.Len(t, steps, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateStep(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipe_steps SET").
		WithArgs("", "Simmer", 2, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	step := &models.RecipeStep{ID: id, Description: "Simmer", Position: 2}
	err := repo.UpdateStep(context.Background(), step)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateStep_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE recipe_steps SET").
		WithArgs("", "Simmer", 2, id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	step := &models.RecipeStep{ID: id, Description: "Simmer", Position: 2}
	err := repo.UpdateStep(context.Background(), step)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteStep(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recipe_steps WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteStep(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteStep_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM recipe_steps WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteStep(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_CreateCollection(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	c := &models.Collection{
		UserID: fixedUUID(),
		Name:   "Favorites",
	}

	mock.ExpectExec("INSERT INTO collections").
		WithArgs(pgxmock.AnyArg(), c.UserID, c.Name, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateCollection(context.Background(), c)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, c.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetCollectionByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "user_id", "name", "created_at", "updated_at"}).
		AddRow(id, fixedUUID(), "Favorites", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM collections WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	c, err := repo.GetCollectionByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, c.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetCollectionByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM collections WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	c, err := repo.GetCollectionByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, c)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_ListCollections(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	uid := fixedUUID()

	cols := []string{"id", "user_id", "name", "created_at", "updated_at"}
	rows := pgxmock.NewRows(cols).AddRow(fixedUUID(), uid, "Favorites", fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM collections WHERE user_id = .*").
		WithArgs(uid, 50, 0).
		WillReturnRows(rows)

	collections, err := repo.ListCollections(context.Background(), uid, 50, 0)
	require.NoError(t, err)
	assert.Len(t, collections, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateCollection(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE collections SET").
		WithArgs("New Name", pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	c := &models.Collection{ID: id, Name: "New Name"}
	err := repo.UpdateCollection(context.Background(), c)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_UpdateCollection_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE collections SET").
		WithArgs("New Name", pgxmock.AnyArg(), id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))

	c := &models.Collection{ID: id, Name: "New Name"}
	err := repo.UpdateCollection(context.Background(), c)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteCollection(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM collection_recipes WHERE collection_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectExec("DELETE FROM collections WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))
	mock.ExpectCommit()

	err := repo.DeleteCollection(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteCollection_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	id := fixedUUID()

	mock.ExpectBegin()
	mock.ExpectExec("DELETE FROM collection_recipes WHERE collection_id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectExec("DELETE FROM collections WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))
	mock.ExpectRollback()

	err := repo.DeleteCollection(context.Background(), id)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_CreateRecipeShare(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	share := &models.RecipeShare{
		RecipeID:         fixedUUID(),
		SharedWithUserID: fixedUUID(),
		Permission:       "view",
	}

	mock.ExpectExec("INSERT INTO recipe_shares").
		WithArgs(pgxmock.AnyArg(), share.RecipeID, share.SharedWithUserID, share.Permission, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateRecipeShare(context.Background(), share)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, share.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetRecipeShareByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	rid := fixedUUID()
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "recipe_id", "shared_with_user_id", "permission", "created_at"}).
		AddRow(fixedUUID(), rid, uid, "view", fixedTime())

	mock.ExpectQuery("SELECT .* FROM recipe_shares WHERE recipe_id = .* AND shared_with_user_id = .*").
		WithArgs(rid, uid).
		WillReturnRows(rows)

	share, err := repo.GetRecipeShareByUser(context.Background(), rid, uid)
	require.NoError(t, err)
	assert.Equal(t, rid, share.RecipeID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_GetRecipeShareByUser_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	rid := fixedUUID()
	uid := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM recipe_shares WHERE recipe_id = .* AND shared_with_user_id = .*").
		WithArgs(rid, uid).
		WillReturnError(pgx.ErrNoRows)

	share, err := repo.GetRecipeShareByUser(context.Background(), rid, uid)
	require.Error(t, err)
	assert.Nil(t, share)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_CreateCollectionRecipe(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)

	cr := &models.CollectionRecipe{
		CollectionID: fixedUUID(),
		RecipeID:     fixedUUID(),
	}

	mock.ExpectExec("INSERT INTO collection_recipes").
		WithArgs(pgxmock.AnyArg(), cr.CollectionID, cr.RecipeID, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateCollectionRecipe(context.Background(), cr)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, cr.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteCollectionRecipe(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	cid := fixedUUID()
	rid := fixedUUID()

	mock.ExpectExec("DELETE FROM collection_recipes WHERE collection_id = .* AND recipe_id = .*").
		WithArgs(cid, rid).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteCollectionRecipe(context.Background(), cid, rid)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRecipeRepo_DeleteCollectionRecipe_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewRecipeRepo(mock)
	cid := fixedUUID()
	rid := fixedUUID()

	mock.ExpectExec("DELETE FROM collection_recipes WHERE collection_id = .* AND recipe_id = .*").
		WithArgs(cid, rid).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	err := repo.DeleteCollectionRecipe(context.Background(), cid, rid)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
	assert.NoError(t, mock.ExpectationsWereMet())
}
