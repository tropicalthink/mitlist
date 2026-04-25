package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
	"github.com/yourorg/mitlist/internal/models"
)

func TestShareService_ParseSharedText(t *testing.T) {
	svc := NewShareService(nil, nil, nil)

	t.Run("success with url", func(t *testing.T) {
		parsed, err := svc.ParseSharedText("Check this out\nhttps://example.com/recipe")
		require.NoError(t, err)
		assert.Equal(t, "Check this out", parsed.Title)
		assert.Equal(t, "https://example.com/recipe", parsed.URL)
	})

	t.Run("empty text", func(t *testing.T) {
		_, err := svc.ParseSharedText("")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestShareService_CreateListFromShare(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		recipeRepo := new(mocks.MockRecipeRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewShareService(listRepo, recipeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)
		listRepo.On("CreateList", ctx, mock.AnythingOfType("*models.List")).Return(nil)
		listRepo.On("CreateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		list, items, err := svc.CreateListFromShare(ctx, userID, groupID, "Milk\nEggs\nBread")
		require.NoError(t, err)
		assert.NotNil(t, list)
		assert.Equal(t, "Milk", list.Name)
		assert.Len(t, items, 2)
	})

	t.Run("not a member", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		recipeRepo := new(mocks.MockRecipeRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewShareService(listRepo, recipeRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, &api.PermissionDeniedError{Message: "not a member"})

		_, _, err := svc.CreateListFromShare(ctx, userID, groupID, "Milk\nEggs\nBread")
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestShareService_CreateRecipeFromShare(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		recipeRepo := new(mocks.MockRecipeRepo)
		svc := NewShareService(listRepo, recipeRepo, nil)

		recipeRepo.On("CreateRecipe", ctx, mock.AnythingOfType("*models.Recipe")).Return(nil)

		recipe, err := svc.CreateRecipeFromShare(ctx, userID, "Amazing Pasta\nhttps://example.com")
		require.NoError(t, err)
		assert.Equal(t, "Amazing Pasta", recipe.Title)
	})
}
