package services

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func newMealPlanService(mpRepo *mocks.MockMealPlanRepo, groupRepo *mocks.MockGroupRepo, recipeRepo *mocks.MockRecipeRepo, listRepo *mocks.MockListRepo) *MealPlanService {
	return NewMealPlanService(mpRepo, groupRepo, recipeRepo, listRepo)
}

func TestMealPlanService_CreateMealPlan(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	recipeID := uuid.New()
	user := &models.User{ID: userID}

	t.Run("success with defaults", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		mpRepo.On("CreateMealPlan", ctx, mock.AnythingOfType("*models.MealPlan")).Return(nil)

		mp := &models.MealPlan{
			GroupID:  groupID,
			RecipeID: recipeID,
			Date:     time.Now(),
		}
		err := svc.CreateMealPlan(ctx, user, mp)
		require.NoError(t, err)
		// Default slot and servings are applied.
		assert.Equal(t, "dinner", mp.Slot)
		assert.Equal(t, 1, mp.Servings)
	})

	t.Run("non-member is denied", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		mp := &models.MealPlan{GroupID: groupID, RecipeID: recipeID, Date: time.Now()}
		err := svc.CreateMealPlan(ctx, user, mp)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})

	t.Run("explicit slot and servings are preserved", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		mpRepo.On("CreateMealPlan", ctx, mock.AnythingOfType("*models.MealPlan")).Return(nil)

		mp := &models.MealPlan{GroupID: groupID, RecipeID: recipeID, Date: time.Now(), Slot: "lunch", Servings: 4}
		err := svc.CreateMealPlan(ctx, user, mp)
		require.NoError(t, err)
		assert.Equal(t, "lunch", mp.Slot)
		assert.Equal(t, 4, mp.Servings)
	})
}

func TestMealPlanService_GetMealPlan(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	mpID := uuid.New()
	user := &models.User{ID: userID}

	t.Run("success", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		mpRepo.On("GetMealPlanByID", ctx, mpID).Return(&models.MealPlan{ID: mpID, GroupID: groupID}, nil)

		mp, err := svc.GetMealPlan(ctx, user, mpID)
		require.NoError(t, err)
		assert.Equal(t, mpID, mp.ID)
	})

	t.Run("not found", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		mpRepo.On("GetMealPlanByID", ctx, mpID).Return(nil, fmt.Errorf("meal plan not found"))

		_, err := svc.GetMealPlan(ctx, user, mpID)
		require.Error(t, err)
		assert.Equal(t, api.ErrNotFound, err)
	})

	t.Run("non-member denied after found", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		mpRepo.On("GetMealPlanByID", ctx, mpID).Return(&models.MealPlan{ID: mpID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetMealPlan(ctx, user, mpID)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})
}

func TestMealPlanService_ListMealPlans(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	user := &models.User{ID: userID}

	from := time.Now()
	to := from.Add(7 * 24 * time.Hour)

	t.Run("success returns plans in range", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		plans := []models.MealPlan{
			{ID: uuid.New(), GroupID: groupID, Date: from.Add(1 * time.Hour)},
			{ID: uuid.New(), GroupID: groupID, Date: from.Add(25 * time.Hour)},
		}
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		mpRepo.On("ListMealPlansByGroup", ctx, groupID, from, to).Return(plans, nil)

		result, err := svc.ListMealPlans(ctx, user, groupID, from, to)
		require.NoError(t, err)
		assert.Len(t, result, 2)
	})

	t.Run("non-member denied", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.ListMealPlans(ctx, user, groupID, from, to)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})
}

func TestMealPlanService_DeleteMealPlan(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	mpID := uuid.New()
	user := &models.User{ID: userID}

	t.Run("success", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		mpRepo.On("GetMealPlanByID", ctx, mpID).Return(&models.MealPlan{ID: mpID, GroupID: groupID}, nil)
		mpRepo.On("DeleteMealPlan", ctx, mpID).Return(nil)

		err := svc.DeleteMealPlan(ctx, user, mpID)
		require.NoError(t, err)
	})

	t.Run("not found", func(t *testing.T) {
		mpRepo := new(mocks.MockMealPlanRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := newMealPlanService(mpRepo, groupRepo, nil, nil)

		mpRepo.On("GetMealPlanByID", ctx, mpID).Return(nil, fmt.Errorf("meal plan not found"))

		err := svc.DeleteMealPlan(ctx, user, mpID)
		require.Error(t, err)
		assert.Equal(t, api.ErrNotFound, err)
	})
}

func TestMealPlanService_GenerateShoppingList_BatchesRecipeAndIngredientQueries(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	user := &models.User{ID: userID}
	recipeID := uuid.New()
	listID := uuid.New()
	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := from.Add(7 * 24 * time.Hour)

	mpRepo := new(mocks.MockMealPlanRepo)
	groupRepo := new(mocks.MockGroupRepo)
	recipeRepo := new(mocks.MockRecipeRepo)
	listRepo := new(mocks.MockListRepo)
	svc := newMealPlanService(mpRepo, groupRepo, recipeRepo, listRepo)
	canonicalID := uuid.New()
	svc.SetCanonicalNameResolver(func(_ context.Context, gotGroupID uuid.UUID, name string) (*uuid.UUID, error) {
		assert.Equal(t, groupID, gotGroupID)
		assert.Equal(t, "Carrots", name)
		return &canonicalID, nil
	})

	plans := []models.MealPlan{{ID: uuid.New(), GroupID: groupID, RecipeID: recipeID, Servings: 2, Date: from}}
	groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
	mpRepo.On("ListMealPlansByGroup", ctx, groupID, from, to).Return(plans, nil)
	recipeRepo.On("GetRecipesByIDs", ctx, []uuid.UUID{recipeID}).Return(map[uuid.UUID]*models.Recipe{
		recipeID: {ID: recipeID, Title: "Soup", Servings: 4},
	}, nil)
	recipeRepo.On("ListIngredientsByRecipeIDs", ctx, []uuid.UUID{recipeID}).Return(map[uuid.UUID][]models.RecipeIngredient{
		recipeID: {{RecipeID: recipeID, Name: "Carrots", Quantity: "2", Unit: "pcs"}},
	}, nil)
	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	listRepo.On("ListItemsByList", ctx, listID, 0, 0).Return(nil, nil)
	listRepo.On("CreateItems", ctx, mock.MatchedBy(func(items []models.ListItem) bool {
		return len(items) == 1 &&
			items[0].Name == "Carrots" &&
			items[0].CanonicalItemID != nil &&
			*items[0].CanonicalItemID == canonicalID
	})).Return(nil)

	targetID := listID
	_, created, err := svc.GenerateShoppingList(ctx, user, groupID, from, to, &targetID)
	require.NoError(t, err)
	require.Len(t, created, 1)
	require.NotNil(t, created[0].CanonicalItemID)
	assert.Equal(t, canonicalID, *created[0].CanonicalItemID)
	recipeRepo.AssertNotCalled(t, "GetRecipeByID", ctx, recipeID)
	recipeRepo.AssertNotCalled(t, "ListIngredients", ctx, recipeID)
	listRepo.AssertNotCalled(t, "CreateItem", ctx, mock.Anything)
}
