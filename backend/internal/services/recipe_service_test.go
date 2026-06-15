package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestRecipeService_CreateRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		recipe := &models.Recipe{Title: "Pasta"}
		err := svc.CreateRecipe(ctx, userID, recipe)
		require.NoError(t, err)
		assert.Equal(t, userID, recipe.UserID)
	})

	t.Run("missing title", func(t *testing.T) {
		svc := NewRecipeService(nil)
		err := svc.CreateRecipe(ctx, userID, &models.Recipe{Title: ""})
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})
}

func TestRecipeService_GetRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()

	t.Run("owner can access", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("public recipe accessible", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		otherID := uuid.New()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: otherID, IsPublic: true}, nil)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("shared recipe accessible", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		otherID := uuid.New()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: otherID, IsPublic: false}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(&models.RecipeShare{}, nil)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("private recipe denied", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		otherID := uuid.New()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: otherID, IsPublic: false}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(nil, errors.New("recipe share not found"))

		_, err := svc.GetRecipe(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		var pd *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pd)
	})
}

func TestRecipeService_UpdateRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()

	t.Run("success owner", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		recipeRepo.On("UpdateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		err := svc.UpdateRecipe(ctx, userID, &models.Recipe{ID: recipeID, Title: "Updated"})
		require.NoError(t, err)
	})

	t.Run("non-owner denied", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: uuid.New()}, nil)

		err := svc.UpdateRecipe(ctx, userID, &models.Recipe{ID: recipeID})
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		var pd *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pd)
	})
}

func TestRecipeService_ShareRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()
	sharedWith := uuid.New()

	t.Run("success", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		recipeRepo.On("CreateRecipeShare", ctx, mock.AnythingOfType("*models.RecipeShare")).Return(nil)

		err := svc.ShareRecipe(ctx, userID, recipeID, sharedWith, "view")
		require.NoError(t, err)
	})
}

func TestRecipeService_CollectionOperations(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	collectionID := uuid.New()
	recipeID := uuid.New()

	t.Run("create collection", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("CreateCollection", ctx, mock.AnythingOfType("*models.Collection")).Return(nil)

		collection := &models.Collection{Name: "Favorites"}
		err := svc.CreateCollection(ctx, userID, collection)
		require.NoError(t, err)
		assert.Equal(t, userID, collection.UserID)
	})

	t.Run("get collection owner", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)

		c, err := svc.GetCollection(ctx, userID, collectionID)
		require.NoError(t, err)
		assert.Equal(t, collectionID, c.ID)
	})

	t.Run("add to collection", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID}, nil)
		recipeRepo.On("CreateCollectionRecipe", ctx, mock.AnythingOfType("*models.CollectionRecipe")).Return(nil)

		err := svc.AddToCollection(ctx, userID, collectionID, recipeID)
		require.NoError(t, err)
	})

	t.Run("remove from collection", func(t *testing.T) {
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewRecipeService(recipeRepo)

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("DeleteCollectionRecipe", ctx, collectionID, recipeID).Return(nil)

		err := svc.RemoveFromCollection(ctx, userID, collectionID, recipeID)
		require.NoError(t, err)
	})
}
