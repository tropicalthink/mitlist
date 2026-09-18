package services

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

type homeGroupReader interface {
	GetGroup(context.Context, uuid.UUID, uuid.UUID) (*models.Group, error)
}

type homeActivityReader interface {
	listRecentActivityForMember(context.Context, uuid.UUID, int) ([]models.ActivityEvent, error)
}

type homePinwallReader interface {
	listPostsForMember(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error)
}

type homeMealPlanReader interface {
	listMealPlansForMember(context.Context, uuid.UUID, time.Time, time.Time) ([]models.MealPlan, error)
}

type homeRecipeReader interface {
	getRecipesForMember(context.Context, uuid.UUID, uuid.UUID, []uuid.UUID) (map[uuid.UUID]*models.Recipe, error)
}

// HomeService builds the data needed for the initial household screen in one
// authenticated request. GroupService proves membership once; package-private
// feature reads then reuse that proof while preserving their other rules.
type HomeService struct {
	groups    homeGroupReader
	activity  homeActivityReader
	pinwall   homePinwallReader
	mealPlans homeMealPlanReader
	recipes   homeRecipeReader
}

func NewHomeService(
	groups homeGroupReader,
	activity homeActivityReader,
	pinwall homePinwallReader,
	mealPlans homeMealPlanReader,
	recipes homeRecipeReader,
) *HomeService {
	return &HomeService{
		groups: groups, activity: activity, pinwall: pinwall,
		mealPlans: mealPlans, recipes: recipes,
	}
}

// GetSnapshot returns the household plus best-effort Home sections. A missing
// or unauthorized household fails the request; optional sections fail
// independently and leave the client's previously cached data intact.
func (s *HomeService) GetSnapshot(
	ctx context.Context,
	user *models.User,
	groupID uuid.UUID,
	date time.Time,
) (*models.HomeSnapshot, error) {
	group, err := s.groups.GetGroup(ctx, user.ID, groupID)
	if err != nil {
		return nil, err
	}

	snapshot := &models.HomeSnapshot{
		Group:        group,
		Activities:   make([]models.ActivityEvent, 0),
		PinwallPosts: make([]models.PinwallPost, 0),
		TodayMeals:   make([]models.HomeMeal, 0),
	}

	var wg sync.WaitGroup
	wg.Add(3)
	go func() {
		defer wg.Done()
		events, sectionErr := s.activity.listRecentActivityForMember(ctx, groupID, 10)
		if sectionErr != nil {
			snapshot.ActivityError = true
			return
		}
		snapshot.Activities = events
	}()
	go func() {
		defer wg.Done()
		posts, sectionErr := s.pinwall.listPostsForMember(ctx, user, groupID, 50, 0)
		if sectionErr != nil {
			snapshot.PinwallError = true
			return
		}
		snapshot.PinwallPosts = posts
	}()
	go func() {
		defer wg.Done()
		plans, sectionErr := s.mealPlans.listMealPlansForMember(ctx, groupID, date, date)
		if sectionErr != nil {
			snapshot.TodayMealError = true
			return
		}
		recipeIDs := make([]uuid.UUID, 0, len(plans))
		seenRecipes := make(map[uuid.UUID]struct{}, len(plans))
		for i := range plans {
			if _, seen := seenRecipes[plans[i].RecipeID]; seen {
				continue
			}
			seenRecipes[plans[i].RecipeID] = struct{}{}
			recipeIDs = append(recipeIDs, plans[i].RecipeID)
		}
		recipes, recipeErr := s.recipes.getRecipesForMember(ctx, user.ID, groupID, recipeIDs)
		if recipeErr != nil {
			recipes = nil
		}
		meals := make([]models.HomeMeal, len(plans))
		for i := range plans {
			meals[i].Plan = plans[i]
			meals[i].Recipe = recipes[plans[i].RecipeID]
		}
		snapshot.TodayMeals = meals
	}()
	wg.Wait()

	return snapshot, nil
}
