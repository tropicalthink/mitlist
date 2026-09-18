package services

import (
	"context"
	"sync"
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

	queryCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	var (
		plans        []models.MealPlan
		recipeTitles map[uuid.UUID]*models.Recipe
		assignments  []models.ChoreAssignment
		recurring    []models.RecurringExpense
		pinwallPosts []models.PinwallPost
		expenses     []models.Expense
		wg           sync.WaitGroup
		errOnce      sync.Once
		firstErr     error
	)
	run := func(query func() error) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := query(); err != nil {
				errOnce.Do(func() {
					firstErr = err
					cancel()
				})
			}
		}()
	}

	// Meal plans and their recipe titles form one dependent query branch.
	run(func() error {
		var err error
		plans, err = s.mealPlanRepo.ListMealPlansByGroup(queryCtx, groupID, from, to)
		if err != nil {
			return err
		}
		recipeIDs := make([]uuid.UUID, 0, len(plans))
		seenRecipes := make(map[uuid.UUID]struct{}, len(plans))
		for _, p := range plans {
			if _, ok := seenRecipes[p.RecipeID]; !ok {
				seenRecipes[p.RecipeID] = struct{}{}
				recipeIDs = append(recipeIDs, p.RecipeID)
			}
		}
		recipeTitles, err = s.recipeRepo.GetRecipesByIDs(queryCtx, recipeIDs)
		return err
	})
	run(func() error {
		var err error
		assignments, err = s.choreRepo.ListDueAssignmentsByGroup(queryCtx, groupID, from, to)
		return err
	})
	run(func() error {
		var err error
		recurring, err = s.financeRepo.ListRecurringExpensesByDateRange(queryCtx, groupID, from, to)
		return err
	})
	run(func() error {
		var err error
		pinwallPosts, err = s.pinwallRepo.ListPostsByGroupAndRemindAtRange(queryCtx, groupID, from, to)
		return err
	})
	run(func() error {
		var err error
		expenses, err = s.financeRepo.ListExpensesByDateRange(queryCtx, groupID, from, to)
		return err
	})
	wg.Wait()
	if firstErr != nil {
		return nil, firstErr
	}

	events := make([]models.CalendarEvent, 0,
		len(plans)+len(assignments)+len(recurring)+len(pinwallPosts)+len(expenses))

	// Meal plans
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
