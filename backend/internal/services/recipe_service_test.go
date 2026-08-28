package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

// newRecipeSvc wires a RecipeService over fresh mocks. Most tests never reach
// the group or user repo, so callers take only the ones they set up.
func newRecipeSvc() (*RecipeService, *mocks.MockRecipeRepo, *mocks.MockGroupRepo, *mocks.MockUserRepo) {
	recipeRepo := new(mocks.MockRecipeRepo)
	groupRepo := new(mocks.MockGroupRepo)
	userRepo := new(mocks.MockUserRepo)
	return NewRecipeService(recipeRepo, groupRepo, userRepo), recipeRepo, groupRepo, userRepo
}

// memberOf makes groupRepo answer "yes, a member" for this group/user pair.
func memberOf(groupRepo *mocks.MockGroupRepo, groupID, userID uuid.UUID) {
	groupRepo.On("GetMembership", mock.Anything, groupID, userID).
		Return(&models.GroupMembership{GroupID: groupID, UserID: userID, Role: "member"}, nil)
}

// notMemberOf makes groupRepo answer with pgx.ErrNoRows, which
// requireGroupMember maps to permission denied.
func notMemberOf(groupRepo *mocks.MockGroupRepo, groupID, userID uuid.UUID) {
	groupRepo.On("GetMembership", mock.Anything, groupID, userID).Return(nil, pgx.ErrNoRows)
}

func TestRecipeService_CreateRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success defaults to private", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		recipe := &models.Recipe{Title: "Pasta"}
		err := svc.CreateRecipe(ctx, userID, recipe)
		require.NoError(t, err)
		assert.Equal(t, userID, recipe.UserID)
		assert.Equal(t, models.RecipeVisibilityPrivate, recipe.Visibility)
	})

	t.Run("missing title", func(t *testing.T) {
		svc, _, _, _ := newRecipeSvc()
		err := svc.CreateRecipe(ctx, userID, &models.Recipe{Title: ""})
		require.Error(t, err)
		assert.Equal(t, api.ErrValidation, err)
	})

	t.Run("household share requires membership", func(t *testing.T) {
		groupID := uuid.New()
		svc, _, groupRepo, _ := newRecipeSvc()
		notMemberOf(groupRepo, groupID, userID)

		err := svc.CreateRecipe(ctx, userID, &models.Recipe{
			Title:      "Pasta",
			Visibility: models.RecipeVisibilityHousehold,
			GroupID:    &groupID,
		})
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
	})

	t.Run("household share without a group is rejected", func(t *testing.T) {
		svc, _, _, _ := newRecipeSvc()
		err := svc.CreateRecipe(ctx, userID, &models.Recipe{
			Title:      "Pasta",
			Visibility: models.RecipeVisibilityHousehold,
		})
		require.Error(t, err)
		var ve *api.ValidationError
		require.ErrorAs(t, err, &ve)
		assert.Equal(t, "group_id", ve.Field)
	})

	t.Run("unknown visibility is rejected", func(t *testing.T) {
		svc, _, _, _ := newRecipeSvc()
		err := svc.CreateRecipe(ctx, userID, &models.Recipe{Title: "Pasta", Visibility: "public"})
		require.Error(t, err)
		var ve *api.ValidationError
		require.ErrorAs(t, err, &ve)
		assert.Equal(t, "visibility", ve.Field)
	})

	t.Run("private clears any group that was sent", func(t *testing.T) {
		groupID := uuid.New()
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		recipe := &models.Recipe{Title: "Pasta", Visibility: models.RecipeVisibilityPrivate, GroupID: &groupID}
		require.NoError(t, svc.CreateRecipe(ctx, userID, recipe))
		assert.Nil(t, recipe.GroupID)
	})
}

func TestRecipeService_GetRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()

	t.Run("owner can access", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("household member can access", func(t *testing.T) {
		groupID := uuid.New()
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{
			ID: recipeID, UserID: uuid.New(),
			Visibility: models.RecipeVisibilityHousehold, GroupID: &groupID,
		}, nil)
		memberOf(groupRepo, groupID, userID)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("non-member is denied a household recipe", func(t *testing.T) {
		groupID := uuid.New()
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{
			ID: recipeID, UserID: uuid.New(),
			Visibility: models.RecipeVisibilityHousehold, GroupID: &groupID,
		}, nil)
		notMemberOf(groupRepo, groupID, userID)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(nil, errors.New("recipe share not found"))

		_, err := svc.GetRecipe(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
	})

	t.Run("household recipe whose group was deleted stays owner-only", func(t *testing.T) {
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		// visibility survives the group; group_id is SET NULL by the FK.
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{
			ID: recipeID, UserID: uuid.New(),
			Visibility: models.RecipeVisibilityHousehold, GroupID: nil,
		}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(nil, errors.New("recipe share not found"))

		_, err := svc.GetRecipe(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		groupRepo.AssertNotCalled(t, "GetMembership", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("shared recipe accessible", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: uuid.New()}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(&models.RecipeShare{}, nil)

		recipe, err := svc.GetRecipe(ctx, userID, recipeID)
		require.NoError(t, err)
		assert.Equal(t, recipeID, recipe.ID)
	})

	t.Run("private recipe denied", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: uuid.New()}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(nil, errors.New("recipe share not found"))

		_, err := svc.GetRecipe(ctx, userID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		var pd *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pd)
	})
}

func TestRecipeService_ListRecipes(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("non-member cannot list a household's recipes", func(t *testing.T) {
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		notMemberOf(groupRepo, groupID, userID)

		_, err := svc.ListRecipes(ctx, userID, repositories.RecipeFilter{GroupID: &groupID})
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		recipeRepo.AssertNotCalled(t, "ListRecipes", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("member gets the household scope passed through", func(t *testing.T) {
		svc, recipeRepo, groupRepo, _ := newRecipeSvc()
		memberOf(groupRepo, groupID, userID)
		filter := repositories.RecipeFilter{GroupID: &groupID, Tags: []string{"dessert"}, Limit: 50}
		recipeRepo.On("ListRecipes", ctx, userID, filter).Return([]models.Recipe{{Title: "Cake"}}, nil)

		out, err := svc.ListRecipes(ctx, userID, filter)
		require.NoError(t, err)
		require.Len(t, out, 1)
		recipeRepo.AssertExpectations(t)
	})
}

func TestRecipeService_UpdateRecipe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	recipeID := uuid.New()

	t.Run("success owner", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		recipeRepo.On("UpdateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		err := svc.UpdateRecipe(ctx, userID, &models.Recipe{ID: recipeID, Title: "Updated"})
		require.NoError(t, err)
	})

	t.Run("non-owner denied", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

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
		svc, recipeRepo, _, userRepo := newRecipeSvc()

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		userRepo.On("GetByID", ctx, sharedWith).Return(&models.User{ID: sharedWith}, nil)
		recipeRepo.On("CreateRecipeShare", ctx, mock.AnythingOfType("*models.RecipeShare")).Return(nil)

		err := svc.ShareRecipe(ctx, userID, recipeID, sharedWith, "view")
		require.NoError(t, err)
	})

	t.Run("rejects an unknown recipient", func(t *testing.T) {
		stranger := uuid.New()
		svc, recipeRepo, _, userRepo := newRecipeSvc()

		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		userRepo.On("GetByID", ctx, stranger).Return(nil, errors.New("user not found"))

		err := svc.ShareRecipe(ctx, userID, recipeID, stranger, "view")
		require.Error(t, err)
		var ve *api.ValidationError
		require.ErrorAs(t, err, &ve)
		assert.Equal(t, "shared_with_user_id", ve.Field)
		recipeRepo.AssertNotCalled(t, "CreateRecipeShare", mock.Anything, mock.Anything)
	})
}

func TestRecipeService_CollectionOperations(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	collectionID := uuid.New()
	recipeID := uuid.New()

	t.Run("create collection", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("CreateCollection", ctx, mock.AnythingOfType("*models.Collection")).Return(nil)

		collection := &models.Collection{Name: "Favorites"}
		err := svc.CreateCollection(ctx, userID, collection)
		require.NoError(t, err)
		assert.Equal(t, userID, collection.UserID)
	})

	t.Run("get collection owner", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)

		c, err := svc.GetCollection(ctx, userID, collectionID)
		require.NoError(t, err)
		assert.Equal(t, collectionID, c.ID)
	})

	t.Run("add to collection", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: userID}, nil)
		recipeRepo.On("CreateCollectionRecipe", ctx, mock.AnythingOfType("*models.CollectionRecipe")).Return(nil)

		err := svc.AddToCollection(ctx, userID, collectionID, recipeID)
		require.NoError(t, err)
	})

	t.Run("foreign private recipe cannot be added", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()
		otherUserID := uuid.New()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("GetRecipeByID", ctx, recipeID).Return(&models.Recipe{ID: recipeID, UserID: otherUserID}, nil)
		recipeRepo.On("GetRecipeShareByUser", ctx, recipeID, userID).Return(nil, errors.New("recipe share not found"))

		err := svc.AddToCollection(ctx, userID, collectionID, recipeID)
		require.Error(t, err)
		assert.ErrorIs(t, err, api.ErrPermissionDenied)
		recipeRepo.AssertNotCalled(t, "CreateCollectionRecipe", mock.Anything, mock.Anything)
	})

	t.Run("remove from collection", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("DeleteCollectionRecipe", ctx, collectionID, recipeID).Return(nil)

		err := svc.RemoveFromCollection(ctx, userID, collectionID, recipeID)
		require.NoError(t, err)
	})

	t.Run("list collection recipes as owner", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: userID}, nil)
		recipeRepo.On("ListRecipesByCollection", ctx, collectionID, 50, 0).Return([]models.Recipe{{ID: recipeID}}, nil)

		recipes, err := svc.ListCollectionRecipes(ctx, userID, collectionID, 50, 0)
		require.NoError(t, err)
		assert.Len(t, recipes, 1)
		assert.Equal(t, recipeID, recipes[0].ID)
	})

	t.Run("list collection recipes denied for non-owner", func(t *testing.T) {
		svc, recipeRepo, _, _ := newRecipeSvc()

		recipeRepo.On("GetCollectionByID", ctx, collectionID).Return(&models.Collection{ID: collectionID, UserID: uuid.New()}, nil)

		_, err := svc.ListCollectionRecipes(ctx, userID, collectionID, 50, 0)
		require.Error(t, err)
		recipeRepo.AssertNotCalled(t, "ListRecipesByCollection", ctx, collectionID, 50, 0)
	})
}
