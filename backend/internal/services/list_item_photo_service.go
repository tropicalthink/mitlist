package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
)

type ListItemPhotoService struct {
	listRepo     repositories.ListRepo
	groupRepo    repositories.GroupRepo
	attachRepo   repositories.AttachmentRepo
	itemAttachRepo *repositories.ListItemAttachmentRepository
	storage      *storagesvc.Service
}

func NewListItemPhotoService(
	listRepo repositories.ListRepo,
	groupRepo repositories.GroupRepo,
	attachRepo repositories.AttachmentRepo,
	itemAttachRepo *repositories.ListItemAttachmentRepository,
	storage *storagesvc.Service,
) *ListItemPhotoService {
	return &ListItemPhotoService{
		listRepo:        listRepo,
		groupRepo:       groupRepo,
		attachRepo:      attachRepo,
		itemAttachRepo:  itemAttachRepo,
		storage:         storage,
	}
}

type ListItemPhoto struct {
	AttachmentID string    `json:"attachment_id"`
	ContentType  string    `json:"content_type"`
	ByteSize     int64     `json:"byte_size"`
	CreatedAt    time.Time `json:"created_at"`
	URL          string    `json:"url"`
}

func (s *ListItemPhotoService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

func (s *ListItemPhotoService) Attach(ctx context.Context, userID, groupID, listItemID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return err
	}

	item, err := s.listRepo.GetItemByID(ctx, listItemID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list item", ID: listItemID.String()}
		}
		return err
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list", ID: item.ListID.String()}
		}
		return err
	}
	if list.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "list item does not belong to this group"}
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

	return s.itemAttachRepo.Add(ctx, listItemID, attachmentID)
}

func (s *ListItemPhotoService) List(ctx context.Context, userID, groupID, listItemID uuid.UUID) ([]ListItemPhoto, error) {
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}

	item, err := s.listRepo.GetItemByID(ctx, listItemID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list item", ID: listItemID.String()}
		}
		return nil, err
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "list", ID: item.ListID.String()}
		}
		return nil, err
	}
	if list.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "list item does not belong to this group"}
	}

	atts, err := s.itemAttachRepo.ListReadyAttachmentsByListItem(ctx, listItemID)
	if err != nil {
		return nil, err
	}

	out := make([]ListItemPhoto, 0, len(atts))
	for _, a := range atts {
		url := s.storage.GetURL(a.ObjectKey)
		if url == "" {
			return nil, fmt.Errorf("failed to presign photo url")
		}
		out = append(out, ListItemPhoto{
			AttachmentID: a.ID.String(),
			ContentType:  a.ContentType,
			ByteSize:     a.ByteSize,
			CreatedAt:    a.CreatedAt,
			URL:          url,
		})
	}
	return out, nil
}

func (s *ListItemPhotoService) Detach(ctx context.Context, userID, groupID, listItemID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return err
	}

	item, err := s.listRepo.GetItemByID(ctx, listItemID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list item", ID: listItemID.String()}
		}
		return err
	}
	list, err := s.listRepo.GetListByID(ctx, item.ListID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list", ID: item.ListID.String()}
		}
		return err
	}
	if list.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "list item does not belong to this group"}
	}

	if err := s.itemAttachRepo.Remove(ctx, listItemID, attachmentID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "list item attachment", ID: attachmentID.String()}
		}
		return err
	}
	return nil
}

