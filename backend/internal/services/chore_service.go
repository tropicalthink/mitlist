package services

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/choreschedule"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
)

// chorePushPayload is the push message structure for chore events.
type chorePushPayload struct {
	Title string                     `json:"title"`
	Body  string                     `json:"body"`
	Data  models.NotificationPayload `json:"data"`
}

// ChoreService provides business logic for chores and deterministic rotation.
type ChoreService struct {
	choreRepo        repositories.ChoreRepo
	groupRepo        repositories.GroupRepo
	listRepo         repositories.ListRepo
	hub              *sse.Hub               // optional; nil disables SSE broadcasts
	pushSvc          PushService            // optional; nil disables push broadcasts
	dispatcher       NotificationDispatcher // optional; nil disables persist+push dispatch
	resolveCanonical CanonicalNameResolver  // optional; nil keeps supplies unlinked
}

// NewChoreService creates a new ChoreService.
func NewChoreService(choreRepo repositories.ChoreRepo, groupRepo repositories.GroupRepo, listRepo repositories.ListRepo) *ChoreService {
	return &ChoreService{
		choreRepo: choreRepo,
		groupRepo: groupRepo,
		listRepo:  listRepo,
	}
}

// SetHub injects the SSE hub for real-time event broadcasts.
func (s *ChoreService) SetHub(h *sse.Hub) { s.hub = h }

// SetPush injects the push service for mobile/web push broadcasts.
func (s *ChoreService) SetPush(p PushService) { s.pushSvc = p }

// SetDispatcher injects the notification dispatcher for persist+push broadcasts.
func (s *ChoreService) SetDispatcher(d NotificationDispatcher) { s.dispatcher = d }

// SetCanonicalNameResolver enables immediate grocery linking when chore
// supplies are copied into a shopping list.
func (s *ChoreService) SetCanonicalNameResolver(resolve CanonicalNameResolver) {
	s.resolveCanonical = resolve
}

// broadcastChorePush persists in-app feed rows and sends push to all group members
// except the actor. Uses the dispatcher when available (persist+push); falls back
// to push-only when only pushSvc is set.
func (s *ChoreService) broadcastChorePush(ctx context.Context, groupID, choreID, actorID uuid.UUID, nType, title, body string) {
	if s.dispatcher != nil {
		notifPayload := models.NotificationPayload{
			Screen:     models.ScreenChoreDetail,
			EntityType: models.EntityTypeChore,
			ID:         choreID.String(),
			GroupID:    groupID.String(),
		}
		_ = s.dispatcher.DispatchToGroup(ctx, groupID, actorID, nType, title, body, notifPayload)
		return
	}
	if s.pushSvc == nil {
		return
	}
	payload := chorePushPayload{
		Title: title,
		Body:  body,
		Data: models.NotificationPayload{
			Screen:     models.ScreenChoreDetail,
			EntityType: models.EntityTypeChore,
			ID:         choreID.String(),
			GroupID:    groupID.String(),
		},
	}
	data, _ := json.Marshal(payload)
	_ = s.pushSvc.BroadcastToGroupExcluding(groupID, actorID, string(data))
}

// publishChore emits an SSE event for a chore state change.
func (s *ChoreService) publishChore(eventType string, groupID, choreID uuid.UUID) {
	if s.hub == nil {
		return
	}
	data, _ := json.Marshal(map[string]string{"chore_id": choreID.String()})
	s.hub.Publish(groupID.String(), sse.Event{
		Type:    eventType,
		GroupID: groupID.String(),
		Payload: data,
	})
}

func (s *ChoreService) requireActiveVerifiedUser(u *models.User) error {
	if u == nil {
		return api.ErrUnauthorized
	}
	if !u.IsActive || !u.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	return nil
}

func (s *ChoreService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *ChoreService) requireAdmin(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupAdmin(ctx, s.groupRepo, groupID, userID)
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
	chore.Frequency = choreschedule.NormalizeFrequency(chore.Frequency)
	chore.RotationType = choreschedule.NormalizeRotationType(chore.RotationType, chore.Frequency)
	normalizeChoreDefaults(chore)

	if err := s.choreRepo.CreateChore(ctx, chore); err != nil {
		return fmt.Errorf("failed to create chore: %w", err)
	}

	members, err := s.groupRepo.ListMembershipsByGroup(ctx, chore.GroupID)
	if err != nil {
		return fmt.Errorf("failed to list group members: %w", err)
	}

	memberOrder := make([]uuid.UUID, 0, len(members))
	allowedMembers := chore.AssignmentConfig
	for _, m := range members {
		if len(allowedMembers) == 0 || containsUUID(allowedMembers, m.UserID) {
			memberOrder = append(memberOrder, m.UserID)
		}
	}

	state := &models.ChoreRotationState{
		ChoreID:      chore.ID,
		MemberOrder:  memberOrder,
		CurrentIndex: 0,
	}
	if err := s.choreRepo.CreateRotationState(ctx, state); err != nil {
		return fmt.Errorf("failed to create rotation state: %w", err)
	}

	if len(memberOrder) > 0 && chore.AssignmentType != "no-assignment" {
		if err := s.createAssignmentForCurrentIndex(ctx, chore, state); err != nil {
			return fmt.Errorf("failed to create initial assignment: %w", err)
		}
		state.CurrentIndex = 1 % len(memberOrder)
		if err := s.choreRepo.UpdateRotationState(ctx, state); err != nil {
			return fmt.Errorf("failed to advance initial rotation state: %w", err)
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

// GetChoreDetails returns a Grocy-style detail payload with current assignment and history stats.
func (s *ChoreService) GetChoreDetails(ctx context.Context, user *models.User, choreID uuid.UUID, dueSoonDays int) (*models.ChoreDetails, error) {
	chore, err := s.GetChore(ctx, user, choreID)
	if err != nil {
		return nil, err
	}

	pending, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("failed to get pending assignment: %w", err)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		pending = nil
	}

	assignments, err := s.choreRepo.ListAssignments(ctx, choreID, 100, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to list assignments: %w", err)
	}
	var last *models.ChoreAssignment
	for i := range assignments {
		if assignments[i].Status != "pending" {
			last = &assignments[i]
			break
		}
	}

	stats, err := s.choreRepo.GetChoreStats(ctx, choreID)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	return &models.ChoreDetails{
		Chore:             *chore,
		PendingAssignment: pending,
		LastAssignment:    last,
		Stats:             *stats,
		DueStatus:         dueStatus(pending, now, dueSoonDays),
		AssignedToMe:      pending != nil && pending.UserID == user.ID,
	}, nil
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

// ListCurrentChores returns chores with pending/last assignments and due-state metadata.
// GetChoreLoad returns per-member completion counts for a group over the last
// `days` days (clamped to a sane range), for the fairness view.
func (s *ChoreService) GetChoreLoad(ctx context.Context, user *models.User, groupID uuid.UUID, days int) ([]models.ChoreLoadEntry, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	if days <= 0 {
		days = 30
	}
	if days > 365 {
		days = 365
	}
	since := time.Now().UTC().AddDate(0, 0, -days)
	return s.choreRepo.GetChoreLoadByGroup(ctx, groupID, since)
}

func (s *ChoreService) ListCurrentChores(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset, dueSoonDays int) ([]models.CurrentChore, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	current, err := s.choreRepo.ListCurrentChoresByGroup(ctx, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	for i := range current {
		current[i].DueStatus = dueStatus(current[i].PendingAssignment, now, dueSoonDays)
		current[i].AssignedToMe = current[i].PendingAssignment != nil && current[i].PendingAssignment.UserID == user.ID
	}
	return current, nil
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
		chore.Name = existing.Name
	}
	if chore.Description == nil {
		chore.Description = existing.Description
	}
	if chore.RotationType == "" {
		chore.RotationType = existing.RotationType
	}
	if chore.Frequency == "" {
		chore.Frequency = existing.Frequency
	}
	if chore.PeriodInterval == 0 {
		chore.PeriodInterval = existing.PeriodInterval
	}
	if chore.PeriodConfig == nil {
		chore.PeriodConfig = existing.PeriodConfig
	}
	if chore.StartDate == nil {
		chore.StartDate = existing.StartDate
	}
	if chore.AssignmentType == "" {
		chore.AssignmentType = existing.AssignmentType
	}
	if chore.AssignmentConfig == nil {
		chore.AssignmentConfig = existing.AssignmentConfig
	}
	if chore.Category == nil {
		chore.Category = existing.Category
	}
	if chore.Name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "chore name is required"}
	}
	chore.GroupID = existing.GroupID
	chore.Frequency = choreschedule.NormalizeFrequency(chore.Frequency)
	chore.RotationType = choreschedule.NormalizeRotationType(chore.RotationType, chore.Frequency)
	normalizeChoreDefaults(chore)
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
	if _, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID); err == nil {
		return &api.ValidationError{Field: "pending_assignment", Message: "chore already has a pending assignment"}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("failed to check pending assignment: %w", err)
	}

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	return s.rotateAndAssign(ctx, chore, state)
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
			if chore.AssignmentType == "no-assignment" {
				return s.recordUnassignedExecution(ctx, user.ID, chore, notes, false)
			}
			return &api.NotFoundError{Resource: "pending assignment", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}

	now := time.Now().UTC()

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	nextState, nextAssignment, err := s.planRotation(ctx, chore, state, now, &assignment.UserID)
	if err != nil {
		return err
	}

	completion := &models.ChoreCompletion{
		AssignmentID: assignment.ID,
		CompletedBy:  user.ID,
		CompletedAt:  now,
		Notes:        notes,
	}

	processed, err := s.choreRepo.CompleteAssignmentAndAdvance(ctx, assignment.ID, "completed", now, nil, completion, nextState, nextAssignment)
	if err != nil {
		return fmt.Errorf("failed to complete chore: %w", err)
	}
	if !processed {
		return &api.ConflictError{Message: "assignment already processed"}
	}

	s.publishChore("chore:completed", chore.GroupID, choreID)
	return nil
}

// SkipChore marks the current pending assignment as skipped and rotates.
func (s *ChoreService) SkipChore(ctx context.Context, user *models.User, choreID uuid.UUID, skipReason *string) error {
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
			if chore.AssignmentType == "no-assignment" {
				return &api.ValidationError{Field: "assignment_type", Message: "unassigned chores cannot be skipped"}
			}
			return &api.NotFoundError{Resource: "pending assignment", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}

	now := time.Now().UTC()

	state, err := s.choreRepo.GetRotationState(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "rotation state", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get rotation state: %w", err)
	}

	nextState, nextAssignment, err := s.planRotation(ctx, chore, state, now, nil)
	if err != nil {
		return err
	}

	processed, err := s.choreRepo.CompleteAssignmentAndAdvance(ctx, assignment.ID, "skipped", now, skipReason, nil, nextState, nextAssignment)
	if err != nil {
		return fmt.Errorf("failed to skip chore: %w", err)
	}
	if !processed {
		return &api.ConflictError{Message: "assignment already processed"}
	}

	s.publishChore("chore:skipped", chore.GroupID, choreID)
	return nil
}

// RescheduleChore updates the current pending assignment's due date and assignee.
func (s *ChoreService) RescheduleChore(ctx context.Context, user *models.User, choreID uuid.UUID, dueDate *time.Time, assigneeID *uuid.UUID) error {
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
	if dueDate != nil && dueDate.Before(time.Now().UTC().Add(-time.Minute)) {
		return &api.ValidationError{Field: "due_date", Message: "due date cannot be in the past"}
	}

	assignment, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "pending assignment", ID: choreID.String()}
		}
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}
	if dueDate != nil {
		normalized := dueDate.UTC()
		assignment.DueDate = &normalized
	}
	if assigneeID != nil {
		if err := s.requireMembership(ctx, *assigneeID, chore.GroupID); err != nil {
			return err
		}
		assignment.UserID = *assigneeID
	}
	if err := s.choreRepo.UpdateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to reschedule assignment: %w", err)
	}
	s.publishChore("chore:rescheduled", chore.GroupID, choreID)
	return nil
}

// UndoLastChoreExecution restores the latest completed/skipped assignment as pending.
func (s *ChoreService) UndoLastChoreExecution(ctx context.Context, user *models.User, choreID uuid.UUID) error {
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

	assignments, err := s.choreRepo.ListAssignments(ctx, choreID, 100, 0)
	if err != nil {
		return fmt.Errorf("failed to list assignments: %w", err)
	}

	var latestFinished *models.ChoreAssignment
	for i := range assignments {
		if assignments[i].Status == "completed" || assignments[i].Status == "skipped" {
			latestFinished = &assignments[i]
			break
		}
	}
	if latestFinished == nil {
		return &api.NotFoundError{Resource: "finished assignment", ID: choreID.String()}
	}

	var successorUserID *uuid.UUID
	if pending, err := s.choreRepo.GetPendingAssignmentByChore(ctx, choreID); err == nil && pending.ID != latestFinished.ID {
		successorUserID = &pending.UserID
		if err := s.choreRepo.DeleteAssignment(ctx, pending.ID); err != nil {
			return fmt.Errorf("failed to delete successor pending assignment: %w", err)
		}
	} else if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("failed to get pending assignment: %w", err)
	}

	latestFinished.Status = "pending"
	latestFinished.CompletedAt = nil
	if err := s.choreRepo.UpdateAssignment(ctx, latestFinished); err != nil {
		return fmt.Errorf("failed to restore assignment: %w", err)
	}
	if successorUserID != nil {
		state, err := s.choreRepo.GetRotationState(ctx, choreID)
		if err != nil {
			return fmt.Errorf("failed to get rotation state: %w", err)
		}
		state.CurrentIndex = indexOfUUID(state.MemberOrder, *successorUserID)
		if err := s.choreRepo.UpdateRotationState(ctx, state); err != nil {
			return fmt.Errorf("failed to restore rotation state: %w", err)
		}
	}
	return nil
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

func (s *ChoreService) recordUnassignedExecution(ctx context.Context, userID uuid.UUID, chore *models.Chore, notes *string, skipped bool) error {
	now := time.Now().UTC()
	status := "completed"
	if skipped {
		status = "skipped"
	}
	assignment := &models.ChoreAssignment{
		ChoreID:     chore.ID,
		UserID:      userID,
		Status:      status,
		DueDate:     nextDue(now, chore),
		AssignedAt:  now,
		CompletedAt: &now,
	}
	if err := s.choreRepo.CreateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to create unassigned execution: %w", err)
	}
	if !skipped {
		completion := &models.ChoreCompletion{
			AssignmentID: assignment.ID,
			CompletedBy:  userID,
			CompletedAt:  now,
			Notes:        notes,
		}
		if err := s.choreRepo.CreateCompletion(ctx, completion); err != nil {
			return fmt.Errorf("failed to record completion: %w", err)
		}
	}
	return nil
}

// rotateAndAssign advances the rotation state and creates the next assignment.
func (s *ChoreService) rotateAndAssign(ctx context.Context, chore *models.Chore, state *models.ChoreRotationState) error {
	assigneeID, nextIndex, err := s.nextAssignee(ctx, chore, state)
	if err != nil {
		return err
	}
	if assigneeID == nil {
		return nil
	}

	state.CurrentIndex = nextIndex
	if err := s.choreRepo.UpdateRotationState(ctx, state); err != nil {
		return fmt.Errorf("failed to update rotation state: %w", err)
	}

	now := time.Now().UTC()
	assignment := &models.ChoreAssignment{
		ChoreID:    chore.ID,
		UserID:     *assigneeID,
		Status:     "pending",
		DueDate:    nextDue(now, chore),
		AssignedAt: now,
	}
	if err := s.choreRepo.CreateAssignment(ctx, assignment); err != nil {
		return fmt.Errorf("failed to create assignment: %w", err)
	}
	return nil
}

// planRotation mirrors rotateAndAssign's decision but performs NO writes,
// returning the rotation state and next assignment objects to persist atomically
// (or nil, nil for chores that do not auto-assign a successor).
//
// completedUserID is the user whose completion (not skip) is being recorded in
// the same transaction; pass nil for skips. It exists only to preserve the
// legacy "who-least-did-first" count (see nextAssigneeForCompletion).
func (s *ChoreService) planRotation(ctx context.Context, chore *models.Chore, state *models.ChoreRotationState, now time.Time, completedUserID *uuid.UUID) (*models.ChoreRotationState, *models.ChoreAssignment, error) {
	assigneeID, nextIndex, err := s.nextAssigneeForCompletion(ctx, chore, state, completedUserID)
	if err != nil {
		return nil, nil, err
	}
	if assigneeID == nil {
		return nil, nil, nil
	}
	state.CurrentIndex = nextIndex
	next := &models.ChoreAssignment{
		ChoreID:    chore.ID,
		UserID:     *assigneeID,
		Status:     "pending",
		DueDate:    nextDue(now, chore),
		AssignedAt: now,
	}
	return state, next, nil
}

// nextAssigneeForCompletion is identical to nextAssignee for all assignment
// types except "who-least-did-first". For that policy, the decision is made
// BEFORE the completing assignment is marked completed in the DB, so its row is
// still "pending" and would not be counted. To preserve the legacy behavior
// (where the just-completed assignment WAS counted, because completion happened
// first), we add 1 to completedUserID's count. completedUserID is nil for skips
// (skipped assignments were never counted by the legacy code, so no adjustment).
func (s *ChoreService) nextAssigneeForCompletion(ctx context.Context, chore *models.Chore, state *models.ChoreRotationState, completedUserID *uuid.UUID) (*uuid.UUID, int, error) {
	if chore.AssignmentType != "who-least-did-first" {
		return s.nextAssignee(ctx, chore, state)
	}
	if len(state.MemberOrder) == 0 {
		return nil, state.CurrentIndex, &api.ValidationError{Field: "member_order", Message: "no members in rotation"}
	}
	assignments, err := s.choreRepo.ListAssignments(ctx, chore.ID, 500, 0)
	if err != nil {
		return nil, state.CurrentIndex, fmt.Errorf("failed to list assignments for least-done policy: %w", err)
	}
	counts := map[uuid.UUID]int{}
	for _, userID := range state.MemberOrder {
		counts[userID] = 0
	}
	for _, assignment := range assignments {
		if assignment.Status == "completed" {
			if _, ok := counts[assignment.UserID]; ok {
				counts[assignment.UserID]++
			}
		}
	}
	// Account for the assignment being completed now (still "pending" in the DB
	// at decision time), matching the legacy ordering where it was counted.
	if completedUserID != nil {
		if _, ok := counts[*completedUserID]; ok {
			counts[*completedUserID]++
		}
	}
	chosen := state.MemberOrder[0]
	for _, userID := range state.MemberOrder[1:] {
		if counts[userID] < counts[chosen] {
			chosen = userID
		}
	}
	nextIndex := (indexOfUUID(state.MemberOrder, chosen) + 1) % len(state.MemberOrder)
	return &chosen, nextIndex, nil
}

func (s *ChoreService) nextAssignee(ctx context.Context, chore *models.Chore, state *models.ChoreRotationState) (*uuid.UUID, int, error) {
	if chore.AssignmentType == "no-assignment" {
		return nil, state.CurrentIndex, nil
	}
	if len(state.MemberOrder) == 0 {
		return nil, state.CurrentIndex, &api.ValidationError{Field: "member_order", Message: "no members in rotation"}
	}

	switch chore.AssignmentType {
	case "in-alphabetical-order", "round_robin", "round-robin", "random":
		nextUserID := state.MemberOrder[state.CurrentIndex]
		nextIndex := (state.CurrentIndex + 1) % len(state.MemberOrder)
		if chore.AssignmentType == "random" {
			randomIndex, err := rand.Int(rand.Reader, big.NewInt(int64(len(state.MemberOrder))))
			if err != nil {
				return nil, state.CurrentIndex, fmt.Errorf("failed to select random assignee: %w", err)
			}
			nextUserID = state.MemberOrder[randomIndex.Int64()]
			nextIndex = state.CurrentIndex
		}
		return &nextUserID, nextIndex, nil
	case "who-least-did-first":
		assignments, err := s.choreRepo.ListAssignments(ctx, chore.ID, 500, 0)
		if err != nil {
			return nil, state.CurrentIndex, fmt.Errorf("failed to list assignments for least-done policy: %w", err)
		}
		counts := map[uuid.UUID]int{}
		for _, userID := range state.MemberOrder {
			counts[userID] = 0
		}
		for _, assignment := range assignments {
			if assignment.Status == "completed" {
				if _, ok := counts[assignment.UserID]; ok {
					counts[assignment.UserID]++
				}
			}
		}
		chosen := state.MemberOrder[0]
		for _, userID := range state.MemberOrder[1:] {
			if counts[userID] < counts[chosen] {
				chosen = userID
			}
		}
		nextIndex := (indexOfUUID(state.MemberOrder, chosen) + 1) % len(state.MemberOrder)
		return &chosen, nextIndex, nil
	default:
		nextUserID := state.MemberOrder[state.CurrentIndex]
		nextIndex := (state.CurrentIndex + 1) % len(state.MemberOrder)
		return &nextUserID, nextIndex, nil
	}
}

// createAssignmentForCurrentIndex creates an assignment for the user at the current index without advancing.
func (s *ChoreService) createAssignmentForCurrentIndex(ctx context.Context, chore *models.Chore, state *models.ChoreRotationState) error {
	if len(state.MemberOrder) == 0 {
		return nil
	}
	userID := state.MemberOrder[state.CurrentIndex]
	now := time.Now().UTC()
	assignment := &models.ChoreAssignment{
		ChoreID:    chore.ID,
		UserID:     userID,
		Status:     "pending",
		AssignedAt: now,
	}
	assignment.DueDate = nextDue(now, chore)
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

	choreIDs := make([]uuid.UUID, 0, len(chores))
	for _, chore := range chores {
		choreIDs = append(choreIDs, chore.ID)
	}
	states, err := s.choreRepo.GetRotationStatesByChoreIDs(ctx, choreIDs)
	if err != nil {
		return fmt.Errorf("failed to get rotation states: %w", err)
	}
	stateByChoreID := make(map[uuid.UUID]models.ChoreRotationState, len(states))
	for _, state := range states {
		stateByChoreID[state.ChoreID] = state
	}

	var updatedStates []models.ChoreRotationState
	for _, chore := range chores {
		state, ok := stateByChoreID[chore.ID]
		if !ok {
			continue
		}

		state.MemberOrder = memberOrder
		if state.CurrentIndex >= len(state.MemberOrder) {
			state.CurrentIndex = 0
		}
		updatedStates = append(updatedStates, state)
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

func dueStatus(assignment *models.ChoreAssignment, now time.Time, dueSoonDays int) string {
	if assignment == nil || assignment.DueDate == nil {
		return "unscheduled"
	}
	due := assignment.DueDate.UTC()
	todayEnd := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, int(time.Second-time.Nanosecond), time.UTC)
	if due.Before(now) {
		return "overdue"
	}
	if !due.After(todayEnd) {
		return "due_today"
	}
	if dueSoonDays > 0 && !due.After(now.AddDate(0, 0, dueSoonDays)) {
		return "due_soon"
	}
	return "later"
}

func normalizeChoreDefaults(chore *models.Chore) {
	if chore.PeriodInterval <= 0 {
		chore.PeriodInterval = 1
	}
	if chore.AssignmentType == "" {
		chore.AssignmentType = "round-robin"
	}
	if chore.AssignmentType == "none" {
		chore.AssignmentType = "no-assignment"
	}
	if chore.AssignmentType == "alphabetical" {
		chore.AssignmentType = "in-alphabetical-order"
	}
	if chore.StartDate == nil {
		now := time.Now().UTC()
		chore.StartDate = &now
	}
}

func nextDue(from time.Time, chore *models.Chore) *time.Time {
	return choreschedule.NextDueForRule(from, choreschedule.Rule{
		Frequency:     chore.Frequency,
		Interval:      chore.PeriodInterval,
		PeriodConfig:  chore.PeriodConfig,
		StartDate:     chore.StartDate,
		TrackDateOnly: chore.TrackDateOnly,
		Rollover:      chore.Rollover,
	})
}

func containsUUID(values []uuid.UUID, target uuid.UUID) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func indexOfUUID(values []uuid.UUID, target uuid.UUID) int {
	for i, value := range values {
		if value == target {
			return i
		}
	}
	return 0
}

// ListSubtasks returns subtasks for a chore.
func (s *ChoreService) ListSubtasks(ctx context.Context, user *models.User, choreID uuid.UUID) ([]models.ChoreSubtask, error) {
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
	return s.choreRepo.ListSubtasksByChore(ctx, choreID)
}

// CreateSubtask creates a subtask for a chore.
func (s *ChoreService) CreateSubtask(ctx context.Context, user *models.User, subtask *models.ChoreSubtask) (*models.ChoreSubtask, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, subtask.ChoreID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore", ID: subtask.ChoreID.String()}
		}
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return nil, err
	}
	if subtask.Title == "" {
		return nil, &api.ValidationError{Field: "title", Message: "subtask title is required"}
	}
	subtasks, err := s.choreRepo.ListSubtasksByChore(ctx, subtask.ChoreID)
	if err != nil {
		return nil, fmt.Errorf("failed to list subtasks: %w", err)
	}
	subtask.Position = len(subtasks)
	if err := s.choreRepo.CreateSubtask(ctx, subtask); err != nil {
		return nil, fmt.Errorf("failed to create subtask: %w", err)
	}
	return subtask, nil
}

// UpdateSubtask updates a subtask.
func (s *ChoreService) UpdateSubtask(ctx context.Context, user *models.User, subtask *models.ChoreSubtask) (*models.ChoreSubtask, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	existing, err := s.choreRepo.GetSubtaskByID(ctx, subtask.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "subtask", ID: subtask.ID.String()}
		}
		return nil, fmt.Errorf("failed to get subtask: %w", err)
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, existing.ChoreID)
	if err != nil {
		return nil, fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return nil, err
	}
	if subtask.Title != "" {
		existing.Title = subtask.Title
	}
	existing.Completed = subtask.Completed
	if subtask.Position >= 0 {
		existing.Position = subtask.Position
	}
	if err := s.choreRepo.UpdateSubtask(ctx, existing); err != nil {
		return nil, fmt.Errorf("failed to update subtask: %w", err)
	}
	return existing, nil
}

// DeleteSubtask deletes a subtask.
func (s *ChoreService) DeleteSubtask(ctx context.Context, user *models.User, subtaskID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	existing, err := s.choreRepo.GetSubtaskByID(ctx, subtaskID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "subtask", ID: subtaskID.String()}
		}
		return fmt.Errorf("failed to get subtask: %w", err)
	}
	chore, err := s.choreRepo.GetChoreByID(ctx, existing.ChoreID)
	if err != nil {
		return fmt.Errorf("failed to get chore: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, chore.GroupID); err != nil {
		return err
	}
	return s.choreRepo.DeleteSubtask(ctx, subtaskID)
}

// FindDueChores returns pending assignments due within the given window.
// This is the foundation for the due reminder job (Slice 7 will wire push delivery).
func (s *ChoreService) FindDueChores(ctx context.Context, window time.Duration) ([]models.ChoreAssignment, error) {
	now := time.Now().UTC()
	until := now.Add(window)
	return s.choreRepo.ListDueAssignments(ctx, now, until)
}

// ReorderSubtasks updates positions for subtasks of a chore.
func (s *ChoreService) ReorderSubtasks(ctx context.Context, user *models.User, choreID uuid.UUID, subtaskIDs []uuid.UUID) error {
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
	for i, id := range subtaskIDs {
		subtask, err := s.choreRepo.GetSubtaskByID(ctx, id)
		if err != nil {
			return fmt.Errorf("subtask %s not found: %w", id, err)
		}
		if subtask.ChoreID != choreID {
			return &api.ValidationError{Field: "subtask_ids", Message: "subtask does not belong to chore"}
		}
		subtask.Position = i
		if err := s.choreRepo.UpdateSubtask(ctx, subtask); err != nil {
			return fmt.Errorf("failed to update subtask position: %w", err)
		}
	}
	return nil
}

// AddSuppliesToList creates list items from a chore's supplies on a specified list.
func (s *ChoreService) AddSuppliesToList(ctx context.Context, user *models.User, choreID uuid.UUID, listID uuid.UUID) error {
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
	list, err := s.listRepo.GetListByID(ctx, listID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "list", ID: listID.String()}
		}
		return fmt.Errorf("failed to get list: %w", err)
	}
	if list.GroupID != chore.GroupID {
		return &api.ValidationError{Field: "list_id", Message: "list does not belong to same group"}
	}

	for _, supply := range chore.Supplies {
		if supply == "" {
			continue
		}
		item := &models.ListItem{
			ListID:  listID,
			Name:    supply,
			Checked: false,
		}
		if s.resolveCanonical != nil {
			if canonicalID, resolveErr := s.resolveCanonical(ctx, chore.GroupID, supply); resolveErr == nil {
				item.CanonicalItemID = canonicalID
			}
		}
		if err := s.listRepo.CreateItem(ctx, item); err != nil {
			return fmt.Errorf("failed to create list item for supply %s: %w", supply, err)
		}
	}
	return nil
}
