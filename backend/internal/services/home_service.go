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
	ListRecentActivity(context.Context, *models.User, uuid.UUID, int) ([]models.ActivityEvent, error)
}

type homePinwallReader interface {
	ListPosts(context.Context, *models.User, uuid.UUID, int, int) ([]models.PinwallPost, error)
}

type homeMealPlanReader interface {
	ListMealPlans(context.Context, *models.User, uuid.UUID, time.Time, time.Time) ([]models.MealPlan, error)
}

type homeRecipeReader interface {
	GetRecipe(context.Context, uuid.UUID, uuid.UUID) (*models.Recipe, error)
}

// HomeService builds the data needed for the initial household screen in one
// authenticated request. The existing feature services remain the source of
// authorization and business rules.
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
		events, sectionErr := s.activity.ListRecentActivity(ctx, user, groupID, 10)
		if sectionErr != nil {
			snapshot.ActivityError = true
			return
		}
		snapshot.Activities = events
	}()
	go func() {
		defer wg.Done()
		posts, sectionErr := s.pinwall.ListPosts(ctx, user, groupID, 50, 0)
		if sectionErr != nil {
			snapshot.PinwallError = true
			return
		}
		snapshot.PinwallPosts = posts
	}()
	go func() {
		defer wg.Done()
		plans, sectionErr := s.mealPlans.ListMealPlans(ctx, user, groupID, date, date)
		if sectionErr != nil {
			snapshot.TodayMealError = true
			return
		}
		meals := make([]models.HomeMeal, len(plans))
		for i := range plans {
			meals[i].Plan = plans[i]
			recipe, recipeErr := s.recipes.GetRecipe(ctx, user.ID, plans[i].RecipeID)
			if recipeErr == nil {
				meals[i].Recipe = recipe
			}
		}
		snapshot.TodayMeals = meals
	}()
	wg.Wait()

	return snapshot, nil
}
