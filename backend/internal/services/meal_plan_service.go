package services

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// MealPlanService implements business logic for meal plans.
type MealPlanService struct {
	mealPlanRepo repositories.MealPlanRepoIface
	groupRepo    repositories.GroupRepo
}

// NewMealPlanService creates a new MealPlanService.
func NewMealPlanService(mealPlanRepo repositories.MealPlanRepoIface, groupRepo repositories.GroupRepo) *MealPlanService {
	return &MealPlanService{mealPlanRepo: mealPlanRepo, groupRepo: groupRepo}
}

func (s *MealPlanService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		return &api.PermissionDeniedError{Message: "not a member of this group"}
	}
	return nil
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
