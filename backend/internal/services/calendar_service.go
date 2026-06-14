package services

import (
	"context"
	"time"

	"github.com/google/uuid"

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
	pinwallRepo  repositories.CalendarPinwallRepo
}

func NewCalendarService(
	mealPlanRepo repositories.MealPlanRepoIface,
	recipeRepo repositories.RecipeRepoIface,
	choreRepo repositories.ChoreRepo,
	financeRepo repositories.FinanceRepoIface,
	groupRepo repositories.GroupRepo,
	pinwallRepo repositories.CalendarPinwallRepo,
) *CalendarService {
	return &CalendarService{
		mealPlanRepo: mealPlanRepo,
		recipeRepo:   recipeRepo,
		choreRepo:    choreRepo,
		financeRepo:  financeRepo,
		groupRepo:    groupRepo,
		pinwallRepo:  pinwallRepo,
	}
}


func (s *CalendarService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	// Previously checked member == nil (unreachable when err == nil); now uses
	// canonical fail-closed helper (authorized behavior change per reviewer ruling).
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
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
	recipeIDs := make([]uuid.UUID, 0, len(plans))
	seenRecipes := make(map[uuid.UUID]struct{}, len(plans))
	for _, p := range plans {
		if _, ok := seenRecipes[p.RecipeID]; !ok {
			seenRecipes[p.RecipeID] = struct{}{}
			recipeIDs = append(recipeIDs, p.RecipeID)
		}
	}
	recipeTitles, err := s.recipeRepo.GetRecipesByIDs(ctx, recipeIDs)
	if err != nil {
		return nil, err
	}
	for _, p := range plans {
		title := "Meal"
		if recipe, ok := recipeTitles[p.RecipeID]; ok && recipe != nil {
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
		title := a.ChoreName
		if title == "" {
			continue
		}
		events = append(events, models.CalendarEvent{
			ID:      a.ID.String(),
			Type:    models.EventTypeChore,
			Title:   title,
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

	// Pinwall reminders
	pinwallPosts, err := s.pinwallRepo.ListPostsByGroupAndRemindAtRange(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	for _, p := range pinwallPosts {
		if p.RemindAt == nil {
			continue
		}
		title := p.Content
		if len(title) > 80 {
			title = title[:80] + "…"
		}
		events = append(events, models.CalendarEvent{
			ID:      "pinwall_" + p.ID.String(),
			Type:    models.EventTypePinwallReminder,
			Title:   title,
			Date:    *p.RemindAt,
			GroupID: p.GroupID,
			PinwallReminder: &models.CalendarPinwallReminder{
				PostID:  p.ID,
				UserID:  p.UserID,
				Content: p.Content,
				Sent:    p.ReminderSentAt != nil,
			},
		})
	}

	// One-time expenses
	expenses, err := s.financeRepo.ListExpensesByDateRange(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	for _, e := range expenses {
		events = append(events, models.CalendarEvent{
			ID:      "expense_" + e.ID.String(),
			Type:    models.EventTypeExpense,
			Title:   e.Description,
			Date:    e.Date,
			GroupID: e.GroupID,
			Expense: &models.CalendarExpense{
				ExpenseID: e.ID,
				PayerID:   e.PayerID,
				Amount:    e.Amount,
				Currency:  e.Currency,
				Category:  e.Category,
			},
		})
	}

	return events, nil
}
