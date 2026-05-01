package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

type PinwallService struct {
	repo      repositories.PinwallRepo
	groupRepo repositories.GroupRepo
}

func NewPinwallService(repo repositories.PinwallRepo, groupRepo repositories.GroupRepo) *PinwallService {
	return &PinwallService{repo: repo, groupRepo: groupRepo}
}

func (s *PinwallService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

func (s *PinwallService) CreatePost(ctx context.Context, user *models.User, groupID uuid.UUID, content string) (*models.PinwallPost, error) {
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	content = strings.TrimSpace(content)
	if content == "" {
		return nil, &api.ValidationError{Field: "content", Message: "content is required"}
	}
	if len(content) > 2000 {
		return nil, &api.ValidationError{Field: "content", Message: "content is too long"}
	}

	p := &models.PinwallPost{
		GroupID: groupID,
		UserID:  user.ID,
		Content: content,
	}
	if err := s.repo.CreatePost(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

func (s *PinwallService) ListPosts(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.repo.ListPostsByGroup(ctx, groupID, limit, offset)
}

// DeletePost deletes a post; any group member may delete.
func (s *PinwallService) DeletePost(ctx context.Context, user *models.User, groupID, postID uuid.UUID) error {
	if !user.IsActive || !user.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return err
	}

	existing, err := s.repo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return err
	}
	if existing.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	if err := s.repo.DeletePost(ctx, postID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return err
	}
	return nil
}

