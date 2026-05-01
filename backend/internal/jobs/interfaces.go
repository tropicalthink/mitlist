package jobs

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
)

// Pusher abstracts push notification delivery.
type Pusher interface {
	SendToUser(userID uuid.UUID, payload string) error
	BroadcastToGroup(groupID uuid.UUID, payload string) error
}

type choreSchedulerRepo interface {
	ListActiveScheduledChores(ctx context.Context) ([]models.Chore, error)
	GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error)
	ScheduleChore(ctx context.Context, assignment *models.ChoreAssignment, stateID uuid.UUID, nextIndex int) error
}

type choreReminderRepo interface {
	ListPendingAssignmentsDueSoon(ctx context.Context, cutoff time.Time) ([]models.ChoreAssignment, error)
	GetChoreName(ctx context.Context, choreID uuid.UUID) (string, error)
	GetChoreGroupID(ctx context.Context, choreID uuid.UUID) (uuid.UUID, error)
	GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
}

type recurringExpenseRepo interface {
	ListDueRecurringExpenses(ctx context.Context) ([]models.RecurringExpense, error)
	ProcessRecurringExpense(ctx context.Context, expense *models.Expense, split *models.Split, reID uuid.UUID, oldNextDue time.Time, nextDue time.Time) error
}

type groupActivity struct {
	GroupID uuid.UUID
	Count   int
}

type weeklySummaryRepo interface {
	ListWeeklyActivity(ctx context.Context, since time.Time) ([]groupActivity, error)
	ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error)
	GetUserPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
}
