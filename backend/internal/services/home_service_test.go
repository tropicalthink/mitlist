package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

type homeGroupReaderFunc func(context.Context, uuid.UUID, uuid.UUID) (*models.Group, error)

func (f homeGroupReaderFunc) GetGroup(ctx context.Context, userID, groupID uuid.UUID) (*models.Group, error) {
	return f(ctx, userID, groupID)
}

type homeActivityReaderFunc func(context.Context, uuid.UUID, int) ([]models.ActivityEvent, error)

func (f homeActivityReaderFunc) listRecentActivityForMember(ctx context.Context, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error) {
	return f(ctx, groupID, limit)
}

type homePinwallReaderFunc func(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error)

func (f homePinwallReaderFunc) listPostsForMember(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	return f(ctx, user, groupID, limit, offset)
}

type homeMealPlanReaderFunc func(context.Context, uuid.UUID, time.Time, time.Time) ([]models.MealPlan, error)

func (f homeMealPlanReaderFunc) listMealPlansForMember(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	return f(ctx, groupID, from, to)
}

type homeRecipeReaderFunc func(context.Context, uuid.UUID, uuid.UUID, []uuid.UUID) (map[uuid.UUID]*models.Recipe, error)

func (f homeRecipeReaderFunc) getRecipesForMember(ctx context.Context, userID, groupID uuid.UUID, recipeIDs []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
	return f(ctx, userID, groupID, recipeIDs)
}

func TestHomeServiceBuildsPartialSnapshot(t *testing.T) {
	user := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	group := &models.Group{ID: uuid.New(), Name: "Home"}
	plan := models.MealPlan{ID: uuid.New(), GroupID: group.ID, RecipeID: uuid.New()}
	recipe := &models.Recipe{ID: plan.RecipeID, UserID: user.ID, Title: "Soup"}
	date := time.Date(2026, time.September, 18, 0, 0, 0, 0, time.UTC)

	service := NewHomeService(
		homeGroupReaderFunc(func(context.Context, uuid.UUID, uuid.UUID) (*models.Group, error) {
			return group, nil
		}),
		homeActivityReaderFunc(func(context.Context, uuid.UUID, int) ([]models.ActivityEvent, error) {
			return nil, errors.New("activity unavailable")
		}),
		homePinwallReaderFunc(func(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error) {
			return []models.PinwallPost{{ID: uuid.New(), GroupID: group.ID, UserID: user.ID}}, nil
		}),
		homeMealPlanReaderFunc(func(_ context.Context, _ uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
			require.Equal(t, date, from)
			require.Equal(t, date, to)
			return []models.MealPlan{plan, {ID: uuid.New(), GroupID: group.ID, RecipeID: plan.RecipeID}}, nil
		}),
		homeRecipeReaderFunc(func(_ context.Context, userID, groupID uuid.UUID, recipeIDs []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
			require.Equal(t, user.ID, userID)
			require.Equal(t, group.ID, groupID)
			require.Equal(t, []uuid.UUID{plan.RecipeID}, recipeIDs)
			return map[uuid.UUID]*models.Recipe{plan.RecipeID: recipe}, nil
		}),
	)

	snapshot, err := service.GetSnapshot(context.Background(), user, group.ID, date)
	require.NoError(t, err)
	require.Same(t, group, snapshot.Group)
	require.True(t, snapshot.ActivityError)
	require.Empty(t, snapshot.Activities)
	require.Len(t, snapshot.PinwallPosts, 1)
	require.False(t, snapshot.PinwallError)
	require.Len(t, snapshot.TodayMeals, 2)
	require.Equal(t, "Soup", snapshot.TodayMeals[0].Recipe.Title)
	require.Equal(t, "Soup", snapshot.TodayMeals[1].Recipe.Title)
}

func TestHomeServiceRequiresReadableGroup(t *testing.T) {
	wantErr := errors.New("not a member")
	service := NewHomeService(
		homeGroupReaderFunc(func(context.Context, uuid.UUID, uuid.UUID) (*models.Group, error) {
			return nil, wantErr
		}),
		homeActivityReaderFunc(nil),
		homePinwallReaderFunc(nil),
		homeMealPlanReaderFunc(nil),
		homeRecipeReaderFunc(nil),
	)

	_, err := service.GetSnapshot(
		context.Background(),
		&models.User{ID: uuid.New()},
		uuid.New(),
		time.Now(),
	)
	require.ErrorIs(t, err, wantErr)
}

func TestHomeServiceReusesMembershipProofAndBatchesRecipes(t *testing.T) {
	ctx := context.Background()
	user := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	group := &models.Group{ID: uuid.New(), Name: "Home"}
	recipeID := uuid.New()
	date := time.Date(2026, time.September, 18, 0, 0, 0, 0, time.UTC)
	plans := []models.MealPlan{
		{ID: uuid.New(), GroupID: group.ID, RecipeID: recipeID},
		{ID: uuid.New(), GroupID: group.ID, RecipeID: recipeID},
	}
	recipe := &models.Recipe{ID: recipeID, UserID: user.ID, Title: "Soup"}

	groupRepo := new(mocks.MockGroupRepo)
	activityRepo := new(mocks.MockActivityRepo)
	pinwallRepo := new(mocks.MockPinwallRepo)
	mealPlanRepo := new(mocks.MockMealPlanRepo)
	recipeRepo := new(mocks.MockRecipeRepo)
	groupRepo.On("GetGroupByIDForUser", ctx, group.ID, user.ID).Return(group, nil).Once()
	activityRepo.On("ListRecentActivity", ctx, group.ID, 10).Return([]models.ActivityEvent{}, nil).Once()
	pinwallRepo.On("ListPostsByGroup", ctx, group.ID, 50, 0).Return([]models.PinwallPost{}, nil).Once()
	mealPlanRepo.On("ListMealPlansByGroup", ctx, group.ID, date, date).Return(plans, nil).Once()
	recipeRepo.On("GetReadableRecipesByIDs", ctx, []uuid.UUID{recipeID}, user.ID, group.ID).
		Return(map[uuid.UUID]*models.Recipe{recipeID: recipe}, nil).Once()

	service := NewHomeService(
		NewGroupService(groupRepo, nil),
		NewActivityService(activityRepo, groupRepo),
		NewPinwallService(pinwallRepo, groupRepo),
		NewMealPlanService(mealPlanRepo, groupRepo, recipeRepo, nil),
		NewRecipeService(recipeRepo, groupRepo, nil),
	)
	snapshot, err := service.GetSnapshot(ctx, user, group.ID, date)

	require.NoError(t, err)
	require.Len(t, snapshot.TodayMeals, 2)
	require.Equal(t, "Soup", snapshot.TodayMeals[0].Recipe.Title)
	groupRepo.AssertNotCalled(t, "GetMembership", ctx, group.ID, user.ID)
	groupRepo.AssertExpectations(t)
	activityRepo.AssertExpectations(t)
	pinwallRepo.AssertExpectations(t)
	mealPlanRepo.AssertExpectations(t)
	recipeRepo.AssertExpectations(t)
}
