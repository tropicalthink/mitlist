package services

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

// CalendarService aggregates meal plans, chores, and recurring expenses into calendar events.
type CalendarService struct {
	mealPlanRepo repositories.MealPlanRepoIface
	recipeRepo   repositories.RecipeRepoIface
	choreRepo    repositories.ChoreRepo
	financeRepo  repositories.FinanceRepoIface
	groupRepo    repositories.GroupRepo
}

// NewCalendarService creates a new CalendarService.
func NewCalendarService(
	mealPlanRepo repositories.MealPlanRepoIface,
	recipeRepo repositories.RecipeRepoIface,
	choreRepo repositories.ChoreRepo,
	financeRepo repositories.FinanceRepoIface,
	groupRepo repositories.GroupRepo,
) *CalendarService {
	return &CalendarService{
		mealPlanRepo: mealPlanRepo,
		recipeRepo:   recipeRepo,
		choreRepo:    choreRepo,
		financeRepo:  financeRepo,
		groupRepo:    groupRepo,
	}
}

func (s *CalendarService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	member, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		return err
	}
	if member == nil {
		return &api.PermissionDeniedError{Message: "not a member of this group"}
	}
	return nil
}

// GetCalendar returns calendar events for a group in a date range.
func (s *CalendarService) GetCalendar(ctx context.Context, user *models.User, groupID uuid.UUID, from, to time.Time) ([]models.CalendarEvent, error) {
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	var events []models.CalendarEvent

	// Meal plans
	plans, err := s.mealPlanRepo.ListMealPlansByGroup(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	for _, p := range plans {
		title := "Meal"
		if recipe, err := s.recipeRepo.GetRecipeByID(ctx, p.RecipeID); err == nil && recipe != nil {
			title = recipe.Title
		}
		events = append(events, models.CalendarEvent{
			ID:      p.ID.String(),
			Type:    models.EventTypeMealPlan,
			Title:   title,
			Date:    p.Date,
			GroupID: p.GroupID,
			MealPlan: &models.CalendarMealPlan{
				MealPlanID: p.ID,
				Slot:       p.Slot,
				RecipeID:   p.RecipeID,
				Servings:   p.Servings,
				CookUserID: p.CookUserID,
			},
		})
	}

	// Chores
	assignments, err := s.choreRepo.ListDueAssignmentsByGroup(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	for _, a := range assignments {
		chore, err := s.choreRepo.GetChoreByID(ctx, a.ChoreID)
		if err != nil {
			continue // skip if chore deleted
		}
		events = append(events, models.CalendarEvent{
			ID:      a.ID.String(),
			Type:    models.EventTypeChore,
			Title:   chore.Name,
			Date:    *a.DueDate,
			GroupID: groupID,
			Chore: &models.CalendarChore{
				ChoreID:      a.ChoreID,
				AssignmentID: a.ID,
				UserID:       a.UserID,
				Status:       a.Status,
			},
		})
	}

	// Recurring expenses
	recurring, err := s.financeRepo.ListRecurringExpensesByDateRange(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	for _, re := range recurring {
		events = append(events, models.CalendarEvent{
			ID:      re.ID.String(),
			Type:    models.EventTypeRecurringExpense,
			Title:   re.Description,
			Date:    re.NextDue,
			GroupID: re.GroupID,
			RecurringExpense: &models.CalendarRecurringExpense{
				RecurringExpenseID: re.ID,
				PayerID:            re.PayerID,
				Amount:             re.Amount,
				Currency:           re.Currency,
				Frequency:          re.Frequency,
			},
		})
	}

	return events, nil
}
