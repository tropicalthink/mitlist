package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// ChoreService provides business logic for chores and deterministic rotation.
type ChoreService struct {
	choreRepo repositories.ChoreRepo
	groupRepo repositories.GroupRepo
}

// NewChoreService creates a new ChoreService.
func NewChoreService(choreRepo repositories.ChoreRepo, groupRepo repositories.GroupRepo) *ChoreService {
	return &ChoreService{
		choreRepo: choreRepo,
		groupRepo: groupRepo,
	}
}

func (s *ChoreService) requireActiveVerifiedUser(u *models.User) error {
	if !u.IsActive || !u.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	return nil
}

func (s *ChoreService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("failed to check membership: %w", err)
	}
	return nil
}

func (s *ChoreService) requireAdmin(ctx context.Context, userID, groupID uuid.UUID) error {
	m, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("failed to check membership: %w", err)
	}
	if m.Role != "admin" {
		return &api.PermissionDeniedError{Message: "admin role required"}
	}
	return nil
}

// CreateChore creates a new chore, initializes deterministic rotation state, and creates the first assignment.
func (s *ChoreService) CreateChore(ctx context.Context, user *models.User, chore *models.Chore) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	if err := s.requireAdmin(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}
	if chore.Name == "" {
		return &api.ValidationError{Field: "name", Message: "chore name is required"}
	}

	if err := s.choreRepo.CreateChore(ctx, chore); err != nil {
		return fmt.Errorf("failed to create chore: %w", err)
	}

	members, err := s.groupRepo.ListMembershipsByGroup(ctx, chore.GroupID)
	if err != nil {
		return fmt.Errorf("failed to list group members: %w", err)
	}

	memberOrder := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		memberOrder = append(memberOrder, m.UserID)
	}

	state := &models.ChoreRotationState{
		ChoreID:      chore.ID,
		MemberOrder:  memberOrder,
		CurrentIndex: 0,
	}
	if err := s.choreRepo.CreateRotationState(ctx, state); err != nil {
		return fmt.Errorf("failed to create rotation state: %w", err)
	}

	if len(memberOrder) > 0 {
		if err := s.createAssignmentForCurrentIndex(ctx, chore.ID, state); err != nil {
			return fmt.Errorf("failed to create initial assignment: %w", err)
		}
	}

	return nil
}

// GetChore retrieves a chore by ID.
func (s *ChoreService) GetChore(ctx context.Context, user *models.User, choreID uuid.UUID) (*models.Chore, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return nil, err
	}
	return chore, nil
}

// ListChores returns all chores for a group.
func (s *ChoreService) ListChores(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.Chore, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.choreRepo.ListChoresByGroup(ctx, groupID, limit, offset)
}

// UpdateChore updates a chore's details.
func (s *ChoreService) UpdateChore(ctx context.Context, user *models.User, chore *models.Chore) (*models.Chore, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	existing, err := s.choreRepo.GetChoreByID(ctx, chore.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore", ID: chore.ID.String()}
		}
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireAdmin(ctx, user.ID, existing.GroupID); err != nil {
		return nil, err
	}
	if chore.Name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "chore name is required"}
	}
	chore.GroupID = existing.GroupID
	if err := s.choreRepo.UpdateChore(ctx, chore); err != nil {
		return nil, fmt.Errorf("failed to update chore: %w", err)
	}
	return chore, nil
}

// DeleteChore removes a chore and its rotation state / assignments.
func (s *ChoreService) DeleteChore(ctx context.Context, user *models.User, choreID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireAdmin(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}
	return s.choreRepo.DeleteChore(ctx, choreID)
}

// RotateChore manually advances the chore rotation and creates the next assignment.
func (s *ChoreService) RotateChore(ctx context.Context, user *models.User, choreID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireAdmin(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	return s.rotateAndAssign(ctx, choreID, state)
}

// CompleteChore marks the current pending assignment as completed, records completion, and rotates.
func (s *ChoreService) CompleteChore(ctx context.Context, user *models.User, choreID uuid.UUID, notes *string) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}

	assignment, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "pending assignment", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}

	now := time.Now().UTC()
	assignment.Status = "completed"
	assignment.CompletedAt = &now
	if err := s.choreRepo.UpdateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to update assignment: %w", err)
	}

	completion := &models.ChoreCompletion{
		AssignmentID: assignment.ID,
		CompletedBy:  user.ID,
		CompletedAt:  now,
		Notes:        notes,
	}
	if err := s.choreRepo.CreateCompletion(ctx, completion); err != nil {
		return fmt.Errorf("failed to record completion: %w", err)
	}

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	return s.rotateAndAssign(ctx, choreID, state)
}

// SkipChore marks the current pending assignment as skipped and rotates.
func (s *ChoreService) SkipChore(ctx context.Context, user *models.User, choreID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}

	assignment, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "pending assignment", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}

	now := time.Now().UTC()
	assignment.Status = "skipped"
	assignment.CompletedAt = &now
	if err := s.choreRepo.UpdateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to update assignment: %w", err)
	}

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	return s.rotateAndAssign(ctx, choreID, state)
}

// GetAssignments returns assignments for a chore.
func (s *ChoreService) GetAssignments(ctx context.Context, user *models.User, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore", ID: choreID.String()}
		}
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return nil, err
	}
	return s.choreRepo.ListAssignments(ctx, choreID, limit, offset)
}

// rotateAndAssign advances the rotation state and creates the next assignment.
func (s *ChoreService) rotateAndAssign(ctx context.Context, choreID uuid.UUID, state *models.ChoreRotationState) error {
	if len(state.MemberOrder) == 0 {
		return &api.ValidationError{Field: "member_order", Message: "no members in rotation"}
	}

	nextUserID := state.MemberOrder[state.CurrentIndex]
	state.CurrentIndex = (state.CurrentIndex + 1) % len(state.MemberOrder)

	if err := s.choreRepo.UpdateRotationState(ctx, state); err != nil {
		return fmt.Errorf("failed to update rotation state: %w", err)
	}

	assignment := &models.ChoreAssignment{
		ChoreID:    choreID,
		UserID:     nextUserID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}
	if err := s.choreRepo.CreateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to create assignment: %w", err)
	}
	return nil
}

// createAssignmentForCurrentIndex creates an assignment for the user at the current index without advancing.
func (s *ChoreService) createAssignmentForCurrentIndex(ctx context.Context, choreID uuid.UUID, state *models.ChoreRotationState) error {
	if len(state.MemberOrder) == 0 {
		return nil
	}
	userID := state.MemberOrder[state.CurrentIndex]
	assignment := &models.ChoreAssignment{
		ChoreID:    choreID,
		UserID:     userID,
		Status:     "pending",
		AssignedAt: time.Now().UTC(),
	}
	return s.choreRepo.CreateAssignment(ctx, assignment)
}

// RebuildMemberOrdersForGroup rebuilds member_order for all chores in a group.
// This should be called by the group service whenever membership changes.
func (s *ChoreService) RebuildMemberOrdersForGroup(ctx context.Context, groupID uuid.UUID) error {
	members, err := s.groupRepo.ListMembershipsByGroup(ctx, groupID)
	if err != nil {
		return fmt.Errorf("failed to list group members: %w", err)
	}

	memberOrder := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		memberOrder = append(memberOrder, m.UserID)
	}

	chores, err := s.choreRepo.ListChoresByGroup(ctx, groupID, 0, 0)
	if err != nil {
		return fmt.Errorf("failed to list chores: %w", err)
	}

	var updatedStates []models.ChoreRotationState
	for _, chore := range chores {
		state, err := s.choreRepo.GetRotationState(ctx, chore.ID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return fmt.Errorf("failed to get rotation state for chore %s: %w", chore.ID, err)
		}

		state.MemberOrder = memberOrder
		if state.CurrentIndex >= len(state.MemberOrder) {
			state.CurrentIndex = 0
		}
		updatedStates = append(updatedStates, *state)
	}

	if len(updatedStates) > 0 {
		if err := s.choreRepo.BulkUpdateRotationStates(ctx, updatedStates); err != nil {
			return fmt.Errorf("batch update rotation states: %w", err)
		}
	}
	return nil
}

// SyncMemberOrderForGroup is an alias for RebuildMemberOrdersForGroup for external callers.
func (s *ChoreService) SyncMemberOrderForGroup(ctx context.Context, groupID uuid.UUID) error {
	return s.RebuildMemberOrdersForGroup(ctx, groupID)
}
