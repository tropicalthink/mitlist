package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
	"github.com/mitlist-app/mitlist/pkg/parsing"
)

// MealPlanService implements business logic for meal plans.
type MealPlanService struct {
	mealPlanRepo     repositories.MealPlanRepoIface
	groupRepo        repositories.GroupRepo
	recipeRepo       repositories.RecipeRepoIface
	listRepo         repositories.ListRepo
	resolveCanonical CanonicalNameResolver
	dispatcher       NotificationDispatcher
	hub              *sse.Hub
}

// SetHub injects the SSE hub for household meal-plan changes.
func (s *MealPlanService) SetHub(h *sse.Hub) { s.hub = h }

// SetCanonicalNameResolver enables immediate grocery linking for ingredients
// generated into a shopping list.
func (s *MealPlanService) SetCanonicalNameResolver(resolve CanonicalNameResolver) {
	s.resolveCanonical = resolve
}

// SetDispatcher enables preference-aware in-app, push, and email notifications.
func (s *MealPlanService) SetDispatcher(dispatcher NotificationDispatcher) {
	s.dispatcher = dispatcher
}

func (s *MealPlanService) notifyChanged(ctx context.Context, userID uuid.UUID, mp *models.MealPlan) {
	if s.dispatcher == nil {
		return
	}
	payload := models.NotificationPayload{
		Screen:     models.ScreenMealPlan,
		EntityType: models.EntityTypeMealPlan,
		ID:         mp.ID.String(),
		GroupID:    mp.GroupID.String(),
	}
	actorName := "A household member"
	if profiles, err := s.groupRepo.ListMemberProfilesByGroup(ctx, mp.GroupID); err == nil {
		for _, profile := range profiles {
			if profile.UserID == userID && strings.TrimSpace(profile.DisplayName) != "" {
				actorName = profile.DisplayName
				break
			}
		}
	}
	householdName := "your household"
	if group, err := s.groupRepo.GetGroupByID(ctx, mp.GroupID); err == nil && strings.TrimSpace(group.Name) != "" {
		householdName = group.Name
	}
	payload.ActorName = actorName
	payload.EntityName = "Meal plan"
	// The recipe name is what the household digest lists when several changes
	// are batched into one notification ("Pasta, Curry, Tacos").
	if recipe, err := s.recipeRepo.GetRecipeByID(ctx, mp.RecipeID); err == nil && strings.TrimSpace(recipe.Title) != "" {
		payload.ItemName = recipe.Title
	}
	payload.Copy = models.NewNotificationCopy(models.NotificationTemplateMealPlanChanged, map[string]string{
		"actor_name": actorName,
		"group_name": householdName,
	})
	_ = s.dispatcher.DispatchToGroup(
		ctx,
		mp.GroupID,
		userID,
		models.NotificationTypeMealPlanChanged,
		"Meal plan updated",
		actorName+" updated the meal plan in "+householdName+".",
		payload,
	)
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

// requireRecipeAccess mirrors RecipeService.GetRecipe: the owner, a member of
// the household the recipe is shared with, or someone holding an explicit
// share. Keep the two in step — a recipe you can see is one you can plan.
func (s *MealPlanService) requireRecipeAccess(ctx context.Context, userID, recipeID uuid.UUID) error {
	recipe, err := s.recipeRepo.GetRecipeByID(ctx, recipeID)
	if err != nil {
		return err
	}
	if recipe.UserID == userID {
		return nil
	}
	if recipe.SharedWithHousehold() {
		err := s.requireMembership(ctx, userID, *recipe.GroupID)
		if err == nil {
			return nil
		}
		if !errors.Is(err, api.ErrPermissionDenied) {
			return err
		}
	}
	if _, err := s.recipeRepo.GetRecipeShareByUser(ctx, recipeID, userID); err == nil {
		return nil
	}
	return &api.PermissionDeniedError{Action: "use recipe"}
}

// CreateMealPlan creates a new meal plan.
func (s *MealPlanService) CreateMealPlan(ctx context.Context, user *models.User, mp *models.MealPlan) error {
	if err := s.requireMembership(ctx, user.ID, mp.GroupID); err != nil {
		return err
	}
	if err := s.requireRecipeAccess(ctx, user.ID, mp.RecipeID); err != nil {
		return err
	}
	if mp.Slot == "" {
		mp.Slot = "dinner"
	}
	if mp.Servings <= 0 {
		mp.Servings = 1
	}
	if err := s.mealPlanRepo.CreateMealPlan(ctx, mp); err != nil {
		return err
	}
	publishDomainEvent(s.hub, "meal_plan:created", mp.GroupID, map[string]string{"meal_plan_id": mp.ID.String()})
	s.notifyChanged(ctx, user.ID, mp)
	return nil
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
	if mp.GroupID != existing.GroupID {
		return &api.ValidationError{Field: "group_id", Message: "group cannot be changed"}
	}
	if err := s.requireRecipeAccess(ctx, user.ID, mp.RecipeID); err != nil {
		return err
	}
	if err := s.mealPlanRepo.UpdateMealPlan(ctx, mp); err != nil {
		return err
	}
	publishDomainEvent(s.hub, "meal_plan:updated", existing.GroupID, map[string]string{"meal_plan_id": mp.ID.String()})
	s.notifyChanged(ctx, user.ID, mp)
	return nil
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
	if err := s.mealPlanRepo.DeleteMealPlan(ctx, mealPlanID); err != nil {
		return err
	}
	publishDomainEvent(s.hub, "meal_plan:deleted", mp.GroupID, map[string]string{"meal_plan_id": mp.ID.String()})
	s.notifyChanged(ctx, user.ID, mp)
	return nil
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
		if err := s.requireRecipeAccess(ctx, user.ID, plan.RecipeID); err != nil {
			return nil, nil, err
		}
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
	existingCanonicalIDs := make(map[uuid.UUID]struct{}, len(existingItems))
	for _, item := range existingItems {
		existingNames[strings.ToLower(strings.TrimSpace(item.Name))] = struct{}{}
		if item.CanonicalItemID != nil {
			existingCanonicalIDs[*item.CanonicalItemID] = struct{}{}
		}
	}

	// Add ingredients to list
	toCreate := make([]models.ListItem, 0, len(ingredientMap))
	for key, qty := range ingredientMap {
		if _, exists := existingNames[strings.ToLower(strings.TrimSpace(key.name))]; exists {
			continue
		}
		item := models.ListItem{
			ListID:   targetList.ID,
			Name:     key.name,
			Quantity: qty,
			Unit:     key.unit,
		}
		if s.resolveCanonical != nil {
			if canonicalID, resolveErr := s.resolveCanonical(ctx, groupID, key.name); resolveErr == nil {
				item.CanonicalItemID = canonicalID
				if canonicalID != nil {
					if _, exists := existingCanonicalIDs[*canonicalID]; exists {
						continue
					}
				}
			}
		}
		toCreate = append(toCreate, item)
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
