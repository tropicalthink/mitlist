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

// ActivityService provides business logic for activity logs.
type ActivityService struct {
	activityRepo repositories.ActivityRepo
	groupRepo    repositories.GroupRepo
}

// NewActivityService creates a new ActivityService.
func NewActivityService(
	activityRepo repositories.ActivityRepo,
	groupRepo repositories.GroupRepo,
) *ActivityService {
	return &ActivityService{
		activityRepo: activityRepo,
		groupRepo:    groupRepo,
	}
}

func (s *ActivityService) requireGroupMember(ctx context.Context, groupID, userID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Action: "access group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

// LogActivity creates an activity log, enforcing group membership.
func (s *ActivityService) LogActivity(ctx context.Context, userID uuid.UUID, log *models.ActivityLog) error {
	if err := s.requireGroupMember(ctx, log.GroupID, userID); err != nil {
		return err
	}
	if log.ID == uuid.Nil {
		log.ID = uuid.New()
	}
	if log.UserID == uuid.Nil {
		log.UserID = userID
	}
	log.CreatedAt = time.Now().UTC()
	return s.activityRepo.LogActivity(ctx, log)
}

// GetActivityLog retrieves an activity log by ID.
func (s *ActivityService) GetActivityLog(ctx context.Context, userID, logID uuid.UUID) (*models.ActivityLog, error) {
	log, err := s.activityRepo.GetActivityLogByID(ctx, logID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "activity log", ID: logID.String()}
		}
		return nil, fmt.Errorf("get activity log: %w", err)
	}
	if err := s.requireGroupMember(ctx, log.GroupID, userID); err != nil {
		return nil, err
	}
	return log, nil
}

// ListActivityLogs lists activity logs for a group.
func (s *ActivityService) ListActivityLogs(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.ActivityLog, error) {
	if err := s.requireGroupMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.activityRepo.ListActivityLogsByGroup(ctx, groupID, limit, offset)
}

// DeleteActivityLog deletes an activity log.
func (s *ActivityService) DeleteActivityLog(ctx context.Context, userID, logID uuid.UUID) error {
	log, err := s.activityRepo.GetActivityLogByID(ctx, logID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "activity log", ID: logID.String()}
		}
		return fmt.Errorf("get activity log: %w", err)
	}
	if err := s.requireGroupMember(ctx, log.GroupID, userID); err != nil {
		return err
	}
	return s.activityRepo.DeleteActivityLog(ctx, logID)
}
