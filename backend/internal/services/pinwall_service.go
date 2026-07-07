package services

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
)

type PinwallService struct {
	repo      repositories.PinwallRepo
	groupRepo repositories.GroupRepo
	hub       *sse.Hub // optional; nil disables SSE broadcasts
}

func NewPinwallService(repo repositories.PinwallRepo, groupRepo repositories.GroupRepo) *PinwallService {
	return &PinwallService{repo: repo, groupRepo: groupRepo}
}

// SetHub injects the SSE hub so pinwall changes broadcast to the household in
// real time. Without a hub, the board only updates on manual refresh.
func (s *PinwallService) SetHub(h *sse.Hub) { s.hub = h }

// publishPost emits an SSE event for a pinwall post change. The payload carries
// just the post id; clients reconcile against their cache (refetch on create,
// remove on delete) so they never trust unauthenticated event bodies.
func (s *PinwallService) publishPost(eventType string, groupID, postID uuid.UUID) {
	if s.hub == nil {
		return
	}
	data, _ := json.Marshal(map[string]string{"post_id": postID.String()})
	s.hub.Publish(groupID.String(), sse.Event{
		Type:    eventType,
		GroupID: groupID.String(),
		Payload: data,
	})
}

func (s *PinwallService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *PinwallService) CreatePost(
	ctx context.Context,
	user *models.User,
	groupID uuid.UUID,
	content string,
	remindAt *time.Time,
) (*models.PinwallPost, error) {
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

	if remindAt != nil {
		t := remindAt.UTC()
		now := time.Now().UTC()
		if !t.After(now) {
			return nil, &api.ValidationError{Field: "remind_at", Message: "must be in the future"}
		}
		remindAt = &t
	}

	p := &models.PinwallPost{
		GroupID:  groupID,
		UserID:   user.ID,
		Content:  content,
		RemindAt: remindAt,
	}
	if err := s.repo.CreatePost(ctx, p); err != nil {
		return nil, err
	}
	s.publishPost("pinwall:post_created", groupID, p.ID)
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
	s.publishPost("pinwall:post_deleted", groupID, postID)
	return nil
}
