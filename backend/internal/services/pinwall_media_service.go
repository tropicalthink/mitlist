package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
	storagesvc "github.com/yourorg/mitlist/internal/services/storage"
)

type PinwallMediaService struct {
	pinwallRepo   repositories.PinwallRepo
	groupRepo     repositories.GroupRepo
	attachRepo    repositories.AttachmentRepo
	postAttachRepo *repositories.PinwallAttachmentRepository
	storage       *storagesvc.Service
}

func NewPinwallMediaService(
	pinwallRepo repositories.PinwallRepo,
	groupRepo repositories.GroupRepo,
	attachRepo repositories.AttachmentRepo,
	postAttachRepo *repositories.PinwallAttachmentRepository,
	storage *storagesvc.Service,
) *PinwallMediaService {
	return &PinwallMediaService{
		pinwallRepo:    pinwallRepo,
		groupRepo:      groupRepo,
		attachRepo:     attachRepo,
		postAttachRepo: postAttachRepo,
		storage:        storage,
	}
}

type PinwallMediaItem struct {
	AttachmentID string    `json:"attachment_id"`
	ContentType  string    `json:"content_type"`
	ByteSize     int64     `json:"byte_size"`
	CreatedAt    time.Time `json:"created_at"`
	URL          string    `json:"url"`
}

func (s *PinwallMediaService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

func (s *PinwallMediaService) Attach(ctx context.Context, userID, groupID, postID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return err
	}

	post, err := s.pinwallRepo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return err
	}
	if post.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	att, err := s.attachRepo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	if att.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}
	if att.Status != models.AttachmentStatusReady {
		return &api.ValidationError{Message: "attachment not ready"}
	}

	return s.postAttachRepo.Add(ctx, postID, attachmentID)
}

func (s *PinwallMediaService) List(ctx context.Context, userID, groupID, postID uuid.UUID) ([]PinwallMediaItem, error) {
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}

	post, err := s.pinwallRepo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return nil, err
	}
	if post.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	atts, err := s.postAttachRepo.ListReadyAttachmentsByPost(ctx, postID)
	if err != nil {
		return nil, err
	}

	out := make([]PinwallMediaItem, 0, len(atts))
	for _, a := range atts {
		url := s.storage.GetURL(a.ObjectKey)
		if url == "" {
			return nil, fmt.Errorf("failed to presign media url")
		}
		out = append(out, PinwallMediaItem{
			AttachmentID: a.ID.String(),
			ContentType:  a.ContentType,
			ByteSize:     a.ByteSize,
			CreatedAt:    a.CreatedAt,
			URL:          url,
		})
	}
	return out, nil
}

func (s *PinwallMediaService) Detach(ctx context.Context, userID, groupID, postID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return err
	}

	post, err := s.pinwallRepo.GetPostByID(ctx, postID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "pinwall post", ID: postID.String()}
		}
		return err
	}
	if post.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "post does not belong to this group"}
	}

	if err := s.postAttachRepo.Remove(ctx, postID, attachmentID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "pinwall attachment", ID: attachmentID.String()}
		}
		return err
	}
	return nil
}

