package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

type homeGroupReaderFunc func(context.Context, uuid.UUID, uuid.UUID) (*models.Group, error)

func (f homeGroupReaderFunc) GetGroup(ctx context.Context, userID, groupID uuid.UUID) (*models.Group, error) {
	return f(ctx, userID, groupID)
}

type homeActivityReaderFunc func(context.Context, *models.User, uuid.UUID, int) ([]models.ActivityEvent, error)

func (f homeActivityReaderFunc) ListRecentActivity(ctx context.Context, user *models.User, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error) {
	return f(ctx, user, groupID, limit)
}

type homePinwallReaderFunc func(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error)

func (f homePinwallReaderFunc) ListPosts(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	return f(ctx, user, groupID, limit, offset)
}

type homeMealPlanReaderFunc func(context.Context, *models.User, uuid.UUID, time.Time, time.Time) ([]models.MealPlan, error)

func (f homeMealPlanReaderFunc) ListMealPlans(ctx context.Context, user *models.User, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	return f(ctx, user, groupID, from, to)
}

type homeRecipeReaderFunc func(context.Context, uuid.UUID, uuid.UUID) (*models.Recipe, error)

func (f homeRecipeReaderFunc) GetRecipe(ctx context.Context, userID, recipeID uuid.UUID) (*models.Recipe, error) {
	return f(ctx, userID, recipeID)
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
		homeActivityReaderFunc(func(context.Context, *models.User, uuid.UUID, int) ([]models.ActivityEvent, error) {
			return nil, errors.New("activity unavailable")
		}),
		homePinwallReaderFunc(func(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error) {
			return []models.PinwallPost{{ID: uuid.New(), GroupID: group.ID, UserID: user.ID}}, nil
		}),
		homeMealPlanReaderFunc(func(_ context.Context, _ *models.User, _ uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
			require.Equal(t, date, from)
			require.Equal(t, date, to)
			return []models.MealPlan{plan}, nil
		}),
		homeRecipeReaderFunc(func(context.Context, uuid.UUID, uuid.UUID) (*models.Recipe, error) {
			return recipe, nil
		}),
	)

	snapshot, err := service.GetSnapshot(context.Background(), user, group.ID, date)
	require.NoError(t, err)
	require.Same(t, group, snapshot.Group)
	require.True(t, snapshot.ActivityError)
	require.Empty(t, snapshot.Activities)
	require.Len(t, snapshot.PinwallPosts, 1)
	require.False(t, snapshot.PinwallError)
	require.Len(t, snapshot.TodayMeals, 1)
	require.Equal(t, "Soup", snapshot.TodayMeals[0].Recipe.Title)
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
