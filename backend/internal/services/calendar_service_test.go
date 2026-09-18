package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestCalendarService_GetCalendar_BatchesRecipeAndChoreLookups(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	user := &models.User{ID: uuid.New()}
	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := from.Add(7 * 24 * time.Hour)

	recipeID := uuid.New()
	planID := uuid.New()
	assignmentID := uuid.New()
	choreID := uuid.New()
	due := from.Add(24 * time.Hour)

	mpRepo := new(mocks.MockMealPlanRepo)
	recipeRepo := new(mocks.MockRecipeRepo)
	choreRepo := new(mocks.MockChoreRepo)
	financeRepo := new(mocks.MockFinanceRepo)
	groupRepo := new(mocks.MockGroupRepo)
	pinwallRepo := new(mocks.MockCalendarPinwallRepo)
	listRepo := new(mocks.MockCalendarListRepo)

	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	mpRepo.On("ListMealPlansByGroup", mock.Anything, groupID, from, to).Return([]models.MealPlan{{
		ID: planID, GroupID: groupID, Date: from, RecipeID: recipeID,
	}}, nil)
	recipeRepo.On("GetRecipesByIDs", mock.Anything, []uuid.UUID{recipeID}).Return(map[uuid.UUID]*models.Recipe{
		recipeID: {ID: recipeID, Title: "Pasta"},
	}, nil)
	choreRepo.On("ListDueAssignmentsByGroup", mock.Anything, groupID, from, to).Return([]models.ChoreAssignment{{
		ID: assignmentID, ChoreID: choreID, UserID: user.ID, Status: "pending", DueDate: &due, ChoreName: "Dishes",
	}}, nil)
	financeRepo.On("ListRecurringExpensesByDateRange", mock.Anything, groupID, from, to).Return(nil, nil)
	pinwallRepo.On("ListPostsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).Return(nil, nil)
	financeRepo.On("ListExpensesByDateRange", mock.Anything, groupID, from, to).Return(nil, nil)
	listRepo.On("ListListsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).Return(nil, nil)

	svc := NewCalendarService(mpRepo, recipeRepo, choreRepo, financeRepo, groupRepo, pinwallRepo, listRepo)
	events, err := svc.GetCalendar(ctx, user, groupID, from, to)
	require.NoError(t, err)
	require.Len(t, events, 2)

	mealEvent := events[0]
	assert.Equal(t, models.EventTypeMealPlan, mealEvent.Type)
	assert.Equal(t, "Pasta", mealEvent.Title)

	choreEvent := events[1]
	assert.Equal(t, models.EventTypeChore, choreEvent.Type)
	assert.Equal(t, "Dishes", choreEvent.Title)

	recipeRepo.AssertExpectations(t)
	recipeRepo.AssertNotCalled(t, "GetRecipeByID", mock.Anything, recipeID)
	choreRepo.AssertNotCalled(t, "GetChoreByID", mock.Anything, choreID)
}

func TestCalendarService_RunsIndependentQueriesConcurrently(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	user := &models.User{ID: uuid.New()}
	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := from.Add(7 * 24 * time.Hour)

	mpRepo := new(mocks.MockMealPlanRepo)
	recipeRepo := new(mocks.MockRecipeRepo)
	choreRepo := new(mocks.MockChoreRepo)
	financeRepo := new(mocks.MockFinanceRepo)
	groupRepo := new(mocks.MockGroupRepo)
	pinwallRepo := new(mocks.MockCalendarPinwallRepo)
	listRepo := new(mocks.MockCalendarListRepo)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).
		Return(&models.GroupMembership{Role: "member"}, nil)

	started := make(chan string, 6)
	release := make(chan struct{})
	block := func(name string) func(mock.Arguments) {
		return func(mock.Arguments) {
			started <- name
			<-release
		}
	}
	mpRepo.On("ListMealPlansByGroup", mock.Anything, groupID, from, to).
		Run(block("meals")).Return([]models.MealPlan{}, nil)
	recipeRepo.On("GetRecipesByIDs", mock.Anything, []uuid.UUID{}).
		Return(map[uuid.UUID]*models.Recipe{}, nil)
	choreRepo.On("ListDueAssignmentsByGroup", mock.Anything, groupID, from, to).
		Run(block("chores")).Return([]models.ChoreAssignment{}, nil)
	financeRepo.On("ListRecurringExpensesByDateRange", mock.Anything, groupID, from, to).
		Run(block("recurring")).Return([]models.RecurringExpense{}, nil)
	pinwallRepo.On("ListPostsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).
		Run(block("pinwall")).Return([]models.PinwallPost{}, nil)
	financeRepo.On("ListExpensesByDateRange", mock.Anything, groupID, from, to).
		Run(block("expenses")).Return([]models.Expense{}, nil)
	listRepo.On("ListListsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).
		Run(block("lists")).Return([]models.List{}, nil)

	svc := NewCalendarService(mpRepo, recipeRepo, choreRepo, financeRepo, groupRepo, pinwallRepo, listRepo)
	done := make(chan error, 1)
	go func() {
		_, err := svc.GetCalendar(ctx, user, groupID, from, to)
		done <- err
	}()

	seen := make(map[string]bool, 6)
	timer := time.NewTimer(2 * time.Second)
	defer timer.Stop()
	for len(seen) < 6 {
		select {
		case name := <-started:
			seen[name] = true
		case <-timer.C:
			close(release)
			t.Fatalf("only %d independent queries started before release", len(seen))
		}
	}
	close(release)

	select {
	case err := <-done:
		require.NoError(t, err)
	case <-time.After(2 * time.Second):
		t.Fatal("calendar query did not finish after releasing repositories")
	}
}

func TestCalendarService_GetCalendar_IncludesListReminders(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	user := &models.User{ID: uuid.New()}
	from := time.Date(2026, 9, 14, 0, 0, 0, 0, time.UTC)
	to := from.Add(7 * 24 * time.Hour)

	pendingID := uuid.New()
	sentID := uuid.New()
	pendingAt := from.Add(36 * time.Hour)
	sentAt := from.Add(12 * time.Hour)
	deliveredAt := sentAt.Add(time.Minute)

	mpRepo := new(mocks.MockMealPlanRepo)
	recipeRepo := new(mocks.MockRecipeRepo)
	choreRepo := new(mocks.MockChoreRepo)
	financeRepo := new(mocks.MockFinanceRepo)
	groupRepo := new(mocks.MockGroupRepo)
	pinwallRepo := new(mocks.MockCalendarPinwallRepo)
	listRepo := new(mocks.MockCalendarListRepo)

	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	mpRepo.On("ListMealPlansByGroup", mock.Anything, groupID, from, to).Return(nil, nil)
	recipeRepo.On("GetRecipesByIDs", mock.Anything, []uuid.UUID{}).Return(map[uuid.UUID]*models.Recipe{}, nil)
	choreRepo.On("ListDueAssignmentsByGroup", mock.Anything, groupID, from, to).Return(nil, nil)
	financeRepo.On("ListRecurringExpensesByDateRange", mock.Anything, groupID, from, to).Return(nil, nil)
	pinwallRepo.On("ListPostsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).Return(nil, nil)
	financeRepo.On("ListExpensesByDateRange", mock.Anything, groupID, from, to).Return(nil, nil)
	listRepo.On("ListListsByGroupAndRemindAtRange", mock.Anything, groupID, from, to).Return([]models.List{
		{ID: sentID, GroupID: groupID, Name: "Groceries", Type: "shopping", RemindAt: &sentAt, ReminderSentAt: &deliveredAt},
		{ID: pendingID, GroupID: groupID, Name: "Packing", Type: "todo", RemindAt: &pendingAt},
		{ID: uuid.New(), GroupID: groupID, Name: "No reminder", Type: "todo"},
	}, nil)

	svc := NewCalendarService(mpRepo, recipeRepo, choreRepo, financeRepo, groupRepo, pinwallRepo, listRepo)
	events, err := svc.GetCalendar(ctx, user, groupID, from, to)
	require.NoError(t, err)
	require.Len(t, events, 2)

	sent := events[0]
	assert.Equal(t, models.EventTypeListReminder, sent.Type)
	assert.Equal(t, "list_reminder_"+sentID.String(), sent.ID)
	assert.Equal(t, "Groceries", sent.Title)
	assert.Equal(t, sentAt, sent.Date)
	assert.Equal(t, groupID, sent.GroupID)
	require.NotNil(t, sent.ListReminder)
	assert.Equal(t, sentID, sent.ListReminder.ListID)
	assert.Equal(t, "Groceries", sent.ListReminder.ListName)
	assert.Equal(t, "shopping", sent.ListReminder.ListType)
	assert.True(t, sent.ListReminder.Sent)

	pending := events[1]
	assert.Equal(t, models.EventTypeListReminder, pending.Type)
	assert.Equal(t, pendingAt, pending.Date)
	require.NotNil(t, pending.ListReminder)
	assert.Equal(t, pendingID, pending.ListReminder.ListID)
	assert.False(t, pending.ListReminder.Sent)

	listRepo.AssertExpectations(t)
}
