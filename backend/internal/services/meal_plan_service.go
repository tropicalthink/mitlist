package services

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/parsing"
)

// MealPlanService implements business logic for meal plans.
type MealPlanService struct {
	mealPlanRepo repositories.MealPlanRepoIface
	groupRepo    repositories.GroupRepo
	recipeRepo   repositories.RecipeRepoIface
	listRepo     repositories.ListRepo
}

// NewMealPlanService creates a new MealPlanService.
func NewMealPlanService(mealPlanRepo repositories.MealPlanRepoIface, groupRepo repositories.GroupRepo, recipeRepo repositories.RecipeRepoIface, listRepo repositories.ListRepo) *MealPlanService {
	return &MealPlanService{mealPlanRepo: mealPlanRepo, groupRepo: groupRepo, recipeRepo: recipeRepo, listRepo: listRepo}
}

func (s *MealPlanService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	// Previously swallowed all repo errors; now uses canonical fail-closed helper
	// (authorized behavior change per reviewer ruling).
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

// CreateMealPlan creates a new meal plan.
func (s *MealPlanService) CreateMealPlan(ctx context.Context, user *models.User, mp *models.MealPlan) error {
	if err := s.requireMembership(ctx, user.ID, mp.GroupID); err != nil {
		return err
	}
	if mp.Slot == "" {
		mp.Slot = "dinner"
	}
	if mp.Servings <= 0 {
		mp.Servings = 1
	}
	return s.mealPlanRepo.CreateMealPlan(ctx, mp)
}

// GetMealPlan returns a meal plan if the user is a member of the group.
func (s *MealPlanService) GetMealPlan(ctx context.Context, user *models.User, mealPlanID uuid.UUID) (*models.MealPlan, error) {
	mp, err := s.mealPlanRepo.GetMealPlanByID(ctx, mealPlanID)
	if err != nil {
		if err.Error() == "meal plan not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, mp.GroupID); err != nil {
		return nil, err
	}
	return mp, nil
}

// ListMealPlans returns meal plans for a group in a date range.
func (s *MealPlanService) ListMealPlans(ctx context.Context, user *models.User, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.mealPlanRepo.ListMealPlansByGroup(ctx, groupID, from, to)
}

// UpdateMealPlan updates a meal plan.
func (s *MealPlanService) UpdateMealPlan(ctx context.Context, user *models.User, mp *models.MealPlan) error {
	existing, err := s.mealPlanRepo.GetMealPlanByID(ctx, mp.ID)
	if err != nil {
		if err.Error() == "meal plan not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMembership(ctx, user.ID, existing.GroupID); err != nil {
		return err
	}
	return s.mealPlanRepo.UpdateMealPlan(ctx, mp)
}

// DeleteMealPlan removes a meal plan.
func (s *MealPlanService) DeleteMealPlan(ctx context.Context, user *models.User, mealPlanID uuid.UUID) error {
	mp, err := s.mealPlanRepo.GetMealPlanByID(ctx, mealPlanID)
	if err != nil {
		if err.Error() == "meal plan not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMembership(ctx, user.ID, mp.GroupID); err != nil {
		return err
	}
	return s.mealPlanRepo.DeleteMealPlan(ctx, mealPlanID)
}

// GenerateShoppingList creates a shopping list from meal plans in a date range.
func (s *MealPlanService) GenerateShoppingList(ctx context.Context, user *models.User, groupID uuid.UUID, from, to time.Time, listID *uuid.UUID) (*models.List, []models.ListItem, error) {
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, nil, err
	}

	plans, err := s.mealPlanRepo.ListMealPlansByGroup(ctx, groupID, from, to)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list meal plans: %w", err)
	}
	if len(plans) == 0 {
		return nil, nil, &api.ValidationError{Message: "no meal plans in selected date range"}
	}

	// Collect all ingredients scaled by servings
	type ingredientKey struct {
		name string
		unit string
	}
	ingredientMap := make(map[ingredientKey]float64)

	recipeIDs := make([]uuid.UUID, 0, len(plans))
	seenRecipes := make(map[uuid.UUID]struct{}, len(plans))
	for _, plan := range plans {
		if _, ok := seenRecipes[plan.RecipeID]; !ok {
			seenRecipes[plan.RecipeID] = struct{}{}
			recipeIDs = append(recipeIDs, plan.RecipeID)
		}
	}
	recipes, err := s.recipeRepo.GetRecipesByIDs(ctx, recipeIDs)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get recipes: %w", err)
	}
	ingredientsByRecipe, err := s.recipeRepo.ListIngredientsByRecipeIDs(ctx, recipeIDs)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list ingredients: %w", err)
	}

	for _, plan := range plans {
		recipe, ok := recipes[plan.RecipeID]
		if !ok || recipe == nil {
			continue
		}
		ingredients := ingredientsByRecipe[plan.RecipeID]

		scale := 1.0
		if recipe.Servings > 0 && plan.Servings > 0 {
			scale = float64(plan.Servings) / float64(recipe.Servings)
		}

		for _, ing := range ingredients {
			key := ingredientKey{name: ing.Name, unit: ing.Unit}
			qty := parseIngredientAmount(ing.Quantity) * scale
			if qty <= 0 {
				qty = 1 * scale
			}
			ingredientMap[key] += qty
		}
	}

	if len(ingredientMap) == 0 {
		return nil, nil, &api.ValidationError{Message: "no ingredients found in meal plans"}
	}

	// Get or create the target list
	var targetList *models.List
	if listID != nil {
		targetList, err = s.listRepo.GetListByID(ctx, *listID)
		if err != nil {
			return nil, nil, &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		if targetList.GroupID != groupID {
			return nil, nil, &api.PermissionDeniedError{Message: "list does not belong to this group"}
		}
	} else {
		targetList = &models.List{
			GroupID: groupID,
			Name:    fmt.Sprintf("Shopping %s", from.Format("2006-01-02")),
			Type:    "shopping",
		}
		if err := s.listRepo.CreateList(ctx, targetList); err != nil {
			return nil, nil, fmt.Errorf("failed to create list: %w", err)
		}
	}

	// Get existing items for deduplication
	existingItems, err := s.listRepo.ListItemsByList(ctx, targetList.ID, 0, 0)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list existing items: %w", err)
	}
	existingNames := make(map[string]struct{}, len(existingItems))
	for _, item := range existingItems {
		existingNames[strings.ToLower(strings.TrimSpace(item.Name))] = struct{}{}
	}

	// Add ingredients to list
	toCreate := make([]models.ListItem, 0, len(ingredientMap))
	for key, qty := range ingredientMap {
		if _, exists := existingNames[strings.ToLower(strings.TrimSpace(key.name))]; exists {
			continue
		}
		toCreate = append(toCreate, models.ListItem{
			ListID:   targetList.ID,
			Name:     key.name,
			Quantity: qty,
			Unit:     key.unit,
		})
	}
	if len(toCreate) > 0 {
		if err := s.listRepo.CreateItems(ctx, toCreate); err != nil {
			return nil, nil, fmt.Errorf("failed to create items: %w", err)
		}
	}
	createdItems := toCreate

	return targetList, createdItems, nil
}

func parseIngredientAmount(raw string) float64 {
	return parsing.ParseIngredientAmount(raw)
}
