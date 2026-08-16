package models

import (
	"time"

	"github.com/google/uuid"
)

// Chore represents a recurring chore within a group.
type Chore struct {
	ID               uuid.UUID   `json:"id"`
	GroupID          uuid.UUID   `json:"group_id"`
	Name             string      `json:"name"`
	Description      *string     `json:"description,omitempty"`
	RotationType     string      `json:"rotation_type"`
	Frequency        string      `json:"frequency"`
	PeriodInterval   int         `json:"period_interval"`
	PeriodConfig     []string    `json:"period_config,omitempty"`
	StartDate        *time.Time  `json:"start_date,omitempty"`
	TrackDateOnly    bool        `json:"track_date_only"`
	Rollover         bool        `json:"rollover"`
	AssignmentType   string      `json:"assignment_type"`
	AssignmentConfig []uuid.UUID `json:"assignment_config,omitempty"`
	IsActive         bool        `json:"is_active"`
	Supplies         []string    `json:"supplies,omitempty"`
	Category         *string     `json:"category,omitempty"`
	CreatedAt        time.Time   `json:"created_at"`
	UpdatedAt        time.Time   `json:"updated_at"`
}

// ChoreRotationState stores the deterministic rotation order for a chore.
type ChoreRotationState struct {
	ID           uuid.UUID   `json:"id"`
	ChoreID      uuid.UUID   `json:"chore_id"`
	MemberOrder  []uuid.UUID `json:"member_order"`
	CurrentIndex int         `json:"current_index"`
}

// ChoreAssignment represents an instance of a chore assigned to a user.
type ChoreAssignment struct {
	ID             uuid.UUID  `json:"id"`
	ChoreID        uuid.UUID  `json:"chore_id"`
	UserID         uuid.UUID  `json:"user_id"`
	Status         string     `json:"status"`
	DueDate        *time.Time `json:"due_date,omitempty"`
	AssignedAt     time.Time  `json:"assigned_at"`
	CompletedAt    *time.Time `json:"completed_at,omitempty"`
	ReminderSentAt *time.Time `json:"reminder_sent_at,omitempty"`
	SkipReason     *string    `json:"skip_reason,omitempty"`
	ChoreName      string     `json:"chore_name,omitempty"`
}

// ChoreCompletion records the completion of a chore assignment.
type ChoreCompletion struct {
	ID           uuid.UUID `json:"id"`
	AssignmentID uuid.UUID `json:"assignment_id"`
	CompletedBy  uuid.UUID `json:"completed_by"`
	CompletedAt  time.Time `json:"completed_at"`
	Notes        *string   `json:"notes,omitempty"`
}

// CurrentChore is the overview shape used by the chores dashboard.
type CurrentChore struct {
	Chore             Chore            `json:"chore"`
	PendingAssignment *ChoreAssignment `json:"pending_assignment,omitempty"`
	LastAssignment    *ChoreAssignment `json:"last_assignment,omitempty"`
	DueStatus         string           `json:"due_status"`
	AssignedToMe      bool             `json:"assigned_to_me"`

	// NextAssigneeUserID is who the turn passes to after the pending
	// assignment, set only when the rotation is deterministic (sequential
	// types). Lets clients render the rotation as shape: "you → Sam".
	NextAssigneeUserID *uuid.UUID `json:"next_assignee_user_id,omitempty"`
}

// ChoreSubtask represents a subtask within a chore.
type ChoreSubtask struct {
	ID        uuid.UUID `json:"id"`
	ChoreID   uuid.UUID `json:"chore_id"`
	Title     string    `json:"title"`
	Completed bool      `json:"completed"`
	Position  int       `json:"position"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ChoreStats summarizes tracked execution history for a chore.
type ChoreStats struct {
	TrackedCount          int        `json:"tracked_count"`
	LastTrackedAt         *time.Time `json:"last_tracked_at,omitempty"`
	LastDoneByUserID      *uuid.UUID `json:"last_done_by_user_id,omitempty"`
	AverageFrequencyHours *float64   `json:"average_frequency_hours,omitempty"`
}

// ChoreLoadEntry is one member's completed-chore count over a window, used by
// the "who's carrying the load" fairness view.
type ChoreLoadEntry struct {
	UserID         uuid.UUID `json:"user_id"`
	CompletedCount int       `json:"completed_count"`
}

// ChoreDetails combines editable chore data, assignment context, and history stats.
type ChoreDetails struct {
	Chore             Chore            `json:"chore"`
	PendingAssignment *ChoreAssignment `json:"pending_assignment,omitempty"`
	LastAssignment    *ChoreAssignment `json:"last_assignment,omitempty"`
	Stats             ChoreStats       `json:"stats"`
	DueStatus         string           `json:"due_status"`
	AssignedToMe      bool             `json:"assigned_to_me"`

	// NextAssigneeUserID mirrors CurrentChore's field: who the turn passes to
	// after the pending assignment, set only for deterministic rotations.
	NextAssigneeUserID *uuid.UUID `json:"next_assignee_user_id,omitempty"`
}
