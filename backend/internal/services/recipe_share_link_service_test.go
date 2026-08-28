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
)

func TestRecipeService_CreateShareLink(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()

	t.Run("mints a token on first share", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		recipeRepo.On("SetShareToken", ctx, recipeID, mock.AnythingOfType("*string")).Return(nil)

		token, err := svc.CreateShareLink(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Len(t, token, shareTokenLen)
		recipeRepo.AssertExpectations(t)
	})

	t.Run("returns the existing token rather than rotating", func(t *testing.T) {
		existing := "EXISTINGTOKEN"
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).
			Return(&models.Recipe{ID: recipeID, UserID: userID, ShareToken: &existing}, nil)

		token, err := svc.CreateShareLink(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, existing, token)
		// Sharing twice must not leave two live capabilities behind.
		recipeRepo.AssertNotCalled(t, "SetShareToken", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("non-owner cannot mint a link", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: uuid.New()}, nil)

		_, err := svc.CreateShareLink(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		recipeRepo.AssertNotCalled(t, "SetShareToken", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("household member is not an owner", func(t *testing.T) {
		// Being able to read a recipe must not let you hand out links to it.
		groupID := uuid.New()
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{
			ID: recipeID, UserID: uuid.New(),
			Visibility: models.RecipeVisibilityHousehold, GroupID: &groupID,
		}, nil)

		_, err := svc.CreateShareLink(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
	})
}

func TestRecipeService_GetSharedRecipe(t *testing.T) {
	ctx := context.Background()
	recipeID := uuid.New()
	token := "SHARETOKEN"

	t.Run("resolves without a session and strips owner details", func(t *testing.T) {
		groupID := uuid.New()
		ownerID := uuid.New()
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(&models.Recipe{
			ID: recipeID, UserID: ownerID, Title: "Cake",
			Visibility: models.RecipeVisibilityHousehold, GroupID: &groupID,
			ShareToken: &token,
		}, nil)
		recipeRepo.On("ListIngredients", ctx, recipeID).Return([]models.RecipeIngredient{{Name: "flour"}}, nil)
		recipeRepo.On("ListSteps", ctx, recipeID).Return([]models.RecipeStep{{Description: "mix"}}, nil)

		shared, err := svc.GetSharedRecipe(ctx, token)
		require.NoError(t, err)
		assert.Equal(t, "Cake", shared.Recipe.Title)
		require.Len(t, shared.Ingredients, 1)
		require.Len(t, shared.Steps, 1)

		// An anonymous viewer learns nothing about where the recipe lives.
		assert.Equal(t, uuid.Nil, shared.Recipe.UserID)
		assert.Nil(t, shared.Recipe.GroupID)
		assert.Empty(t, shared.Recipe.Visibility)
		assert.Nil(t, shared.Recipe.ShareToken)
	})

	t.Run("empty token is not found", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		_, err := svc.GetSharedRecipe(ctx, "")
		require.ErrorIs(t, err, api.ErrNotFound)
		// Never let a blank token reach the database as a lookup.
		recipeRepo.AssertNotCalled(t, "GetRecipeByShareToken", mock.Anything, mock.Anything)
	})

	t.Run("revoked token is not found", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(nil, errors.New("recipe not found"))

		_, err := svc.GetSharedRecipe(ctx, token)
		assert.ErrorIs(t, err, api.ErrNotFound)
	})
}

func TestRecipeService_SaveSharedRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()
	token := "SHARETOKEN"

	sharedRecipe := func() *models.Recipe {
		return &models.Recipe{
			ID: recipeID, UserID: uuid.New(), Title: "Cake",
			Tags: []string{"dessert"}, Servings: 8,
		}
	}

	t.Run("copies into the caller's library as private by default", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(sharedRecipe(), nil)
		recipeRepo.On("ListIngredients", ctx, recipeID).Return([]models.RecipeIngredient{{Name: "flour"}}, nil)
		recipeRepo.On("ListSteps", ctx, recipeID).Return([]models.RecipeStep{{Description: "mix"}}, nil)
		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)
		recipeRepo.On("CreateIngredient", ctx, mock.AnythingOfType("*models.RecipeIngredient")).Return(nil)
		recipeRepo.On("CreateStep", ctx, mock.AnythingOfType("*models.RecipeStep")).Return(nil)

		copied, err := svc.SaveSharedRecipe(ctx, userID, token, "", nil)
		require.NoError(t, err)
		assert.Equal(t, userID, copied.UserID)
		assert.Equal(t, "Cake", copied.Title)
		assert.Equal(t, models.RecipeVisibilityPrivate, copied.Visibility)
		// A copy, not a reference: the recipient's version survives revocation.
		assert.NotEqual(t, recipeID, copied.ID)
		recipeRepo.AssertExpectations(t)
	})

	t.Run("saving into a household requires membership", func(t *testing.T) {
		groupID := uuid.New()
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(sharedRecipe(), nil)
		recipeRepo.On("ListIngredients", ctx, recipeID).Return([]models.RecipeIngredient{}, nil)
		recipeRepo.On("ListSteps", ctx, recipeID).Return([]models.RecipeStep{}, nil)
		notMemberOf(groupRepo, groupID, userID)

		_, err := svc.SaveSharedRecipe(ctx, userID, token, models.RecipeVisibilityHousehold, &groupID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		recipeRepo.AssertNotCalled(t, "CreateRecipe", mock.Anything, mock.Anything)
	})

	t.Run("saving to a household the caller belongs to succeeds", func(t *testing.T) {
		groupID := uuid.New()
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(sharedRecipe(), nil)
		recipeRepo.On("ListIngredients", ctx, recipeID).Return([]models.RecipeIngredient{}, nil)
		recipeRepo.On("ListSteps", ctx, recipeID).Return([]models.RecipeStep{}, nil)
		memberOf(groupRepo, groupID, userID)
		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		copied, err := svc.SaveSharedRecipe(ctx, userID, token, models.RecipeVisibilityHousehold, &groupID)
		require.NoError(t, err)
		assert.Equal(t, models.RecipeVisibilityHousehold, copied.Visibility)
		require.NotNil(t, copied.GroupID)
		assert.Equal(t, groupID, *copied.GroupID)
	})

	t.Run("the copy does not inherit the original's share link", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		src := sharedRecipe()
		src.ShareToken = &token
		recipeRepo.On("GetRecipeByShareToken", ctx, token).Return(src, nil)
		recipeRepo.On("ListIngredients", ctx, recipeID).Return([]models.RecipeIngredient{}, nil)
		recipeRepo.On("ListSteps", ctx, recipeID).Return([]models.RecipeStep{}, nil)
		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		copied, err := svc.SaveSharedRecipe(ctx, userID, token, "", nil)
		require.NoError(t, err)
		assert.Nil(t, copied.ShareToken)
	})
}
