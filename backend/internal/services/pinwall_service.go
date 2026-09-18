package services

import (
	"context"
	"encoding/json"
	"math"
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

// listPostsForMember is for composite services that have already proved
// membership. User status is still checked because it is part of pinwall read
// authorization independently of household membership.
func (s *PinwallService) listPostsForMember(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
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

// UpdatePost edits a note's content and/or presentation (color, size). Any
// group member may edit, matching delete's household-owned semantics. A nil
// field is left unchanged; an empty-string color/size clears the choice back
// to the client default. Broadcasts pinwall:post_updated so open boards and
// hubs reconcile.
func (s *PinwallService) UpdatePost(
	ctx context.Context,
	user *models.User,
	groupID, postID uuid.UUID,
	content, color, size *string,
) (*models.PinwallPost, error) {
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	existing, err := s.repo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return nil, err
	}
	if existing.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	newContent := existing.Content
	if content != nil {
		trimmed := strings.TrimSpace(*content)
		if trimmed == "" {
			return nil, &api.ValidationError{Field: "content", Message: "content is required"}
		}
		if len(trimmed) > 2000 {
			return nil, &api.ValidationError{Field: "content", Message: "content is too long"}
		}
		newContent = trimmed
	}

	newColor := existing.Color
	if color != nil {
		v := strings.TrimSpace(*color)
		if v == "" {
			newColor = nil
		} else if !models.ValidPinwallNoteColors[v] {
			return nil, &api.ValidationError{Field: "color", Message: "unknown note color"}
		} else {
			newColor = &v
		}
	}

	newSize := existing.Size
	if size != nil {
		v := strings.TrimSpace(*size)
		if v == "" {
			newSize = nil
		} else if !models.ValidPinwallNoteSizes[v] {
			return nil, &api.ValidationError{Field: "size", Message: "unknown note size"}
		} else {
			newSize = &v
		}
	}

	if err := s.repo.UpdatePost(ctx, postID, newContent, newColor, newSize); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return nil, err
	}
	existing.Content = newContent
	existing.Color = newColor
	existing.Size = newSize
	s.publishPost("pinwall:post_updated", groupID, postID)
	return existing, nil
}

// UpdatePostPosition moves a note on the shared cork board. Any group member may
// rearrange the board. Broadcasts pinwall:post_moved so open boards reconcile.
func (s *PinwallService) UpdatePostPosition(
	ctx context.Context,
	user *models.User,
	groupID, postID uuid.UUID,
	x, y float64,
) (*models.PinwallPost, error) {
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	// Guard against NaN/Inf and absurd coordinates. The board is a bounded
	// logical space on the client; a generous cap here keeps the data sane
	// without hard-coupling to the exact client dimensions.
	const maxCoord = 1_000_000
	if math.IsNaN(x) || math.IsNaN(y) || math.IsInf(x, 0) || math.IsInf(y, 0) ||
		x < 0 || y < 0 || x > maxCoord || y > maxCoord {
		return nil, &api.ValidationError{Field: "position", Message: "x and y must be finite, non-negative coordinates"}
	}

	existing, err := s.repo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return nil, err
	}
	if existing.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	if err := s.repo.UpdatePostPosition(ctx, postID, x, y); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return nil, err
	}
	existing.PosX = &x
	existing.PosY = &y
	s.publishPost("pinwall:post_moved", groupID, postID)
	return existing, nil
}
