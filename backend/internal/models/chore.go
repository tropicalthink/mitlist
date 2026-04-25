package models

import (
	"time"

	"github.com/google/uuid"
)

// Chore represents a recurring chore within a group.
type Chore struct {
	ID           uuid.UUID `json:"id"`
	GroupID      uuid.UUID `json:"group_id"`
	Name         string    `json:"name"`
	Description  *string   `json:"description,omitempty"`
	RotationType string    `json:"rotation_type"`
	Frequency    string    `json:"frequency"`
	IsActive     bool      `json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
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
	ID          uuid.UUID  `json:"id"`
	ChoreID     uuid.UUID  `json:"chore_id"`
	UserID      uuid.UUID  `json:"user_id"`
	Status      string     `json:"status"`
	DueDate     *time.Time `json:"due_date,omitempty"`
	AssignedAt  time.Time  `json:"assigned_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// ChoreCompletion records the completion of a chore assignment.
type ChoreCompletion struct {
	ID            uuid.UUID  `json:"id"`
	AssignmentID  uuid.UUID  `json:"assignment_id"`
	CompletedBy   uuid.UUID  `json:"completed_by"`
	CompletedAt   time.Time  `json:"completed_at"`
	Notes         *string    `json:"notes,omitempty"`
}
