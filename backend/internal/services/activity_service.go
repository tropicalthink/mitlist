package services

import (
	"context"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ActivityRepo is the interface for activity repository operations.
type ActivityRepo interface {
	ListRecentActivity(ctx context.Context, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error)
}

// ActivityService aggregates recent household events.
type ActivityService struct {
	repo      ActivityRepo
	groupRepo GroupMembershipChecker
}

// GroupMembershipChecker is a minimal interface for membership checks.
type GroupMembershipChecker interface {
	GetMembership(ctx context.Context, groupID, userID uuid.UUID) (*models.GroupMembership, error)
}

// NewActivityService creates a new ActivityService.
func NewActivityService(repo ActivityRepo, groupRepo GroupMembershipChecker) *ActivityService {
	return &ActivityService{repo: repo, groupRepo: groupRepo}
}

func (s *ActivityService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

// ListRecentActivity returns recent household events.
func (s *ActivityService) ListRecentActivity(ctx context.Context, user *models.User, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error) {
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.repo.ListRecentActivity(ctx, groupID, limit)
}
