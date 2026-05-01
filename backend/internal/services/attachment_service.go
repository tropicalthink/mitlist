package services

import (
	"context"
	"fmt"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
)

type AttachmentService struct {
	cfg      *config.Config
	repo     repositories.AttachmentRepo
	groupRepo repositories.GroupRepo
	storage  *storagesvc.Service
}

func NewAttachmentService(cfg *config.Config, repo repositories.AttachmentRepo, groupRepo repositories.GroupRepo, storage *storagesvc.Service) *AttachmentService {
	return &AttachmentService{
		cfg:       cfg,
		repo:      repo,
		groupRepo: groupRepo,
		storage:   storage,
	}
}

type CreateUploadIntentInput struct {
	GroupID     uuid.UUID `json:"group_id"`
	Purpose     string    `json:"purpose"`
	Filename    string    `json:"filename"`
	ContentType string    `json:"content_type"`
	ByteSize    int64     `json:"byte_size"`
}

type UploadIntent struct {
	Attachment *models.Attachment `json:"attachment"`
	ObjectKey  string            `json:"object_key"`
	UploadURL  string            `json:"upload_url"`
	ExpiresIn  int               `json:"expires_in"`
}

func (s *AttachmentService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

func (s *AttachmentService) CreateUploadIntent(ctx context.Context, user *models.User, in CreateUploadIntentInput) (*UploadIntent, error) {
	if user == nil {
		return nil, api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if in.GroupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, in.GroupID); err != nil {
		return nil, err
	}

	in.Purpose = strings.TrimSpace(in.Purpose)
	if in.Purpose == "" {
		return nil, &api.ValidationError{Field: "purpose", Message: "purpose is required"}
	}
	in.Filename = sanitizeFilename(in.Filename)
	if in.Filename == "" {
		in.Filename = "upload"
	}
	if in.ByteSize <= 0 {
		return nil, &api.ValidationError{Field: "byte_size", Message: "byte_size must be positive"}
	}
	if s.cfg != nil && s.cfg.MaxFileSizeBytes > 0 && in.ByteSize > int64(s.cfg.MaxFileSizeBytes) {
		return nil, &api.ValidationError{Field: "byte_size", Message: "file too large"}
	}
	if in.ContentType == "" {
		in.ContentType = "application/octet-stream"
	}

	// Enforce per-group storage cap (best-effort).
	if s.cfg != nil && s.cfg.MaxStoragePerGroupGB > 0 {
		used, err := s.repo.SumReadyBytesByGroup(ctx, in.GroupID)
		if err != nil {
			return nil, err
		}
		limit := int64(s.cfg.MaxStoragePerGroupGB) * 1_000_000_000
		if used+in.ByteSize > limit {
			return nil, &api.ValidationError{Message: "group storage limit exceeded"}
		}
	}

	a := &models.Attachment{
		GroupID:     in.GroupID,
		UserID:      user.ID,
		Purpose:     in.Purpose,
		ContentType: in.ContentType,
		ByteSize:    in.ByteSize,
		Status:      models.AttachmentStatusPending,
	}

	// Create a placeholder object key using a generated attachment id in DB.
	// We will fill ObjectKey once we have the ID.
	a.ObjectKey = "pending"
	if err := s.repo.Create(ctx, a); err != nil {
		return nil, err
	}

	objectKey := buildObjectKey(in.GroupID, a.ID, in.Filename)
	a.ObjectKey = objectKey

	if err := s.repo.UpdateObjectKey(ctx, a.ID, objectKey); err != nil {
		return nil, err
	}

	expires := 15 * time.Minute
	uploadURL := s.storage.GetUploadURL(objectKey, in.ContentType, expires)
	if uploadURL == "" {
		return nil, fmt.Errorf("failed to generate upload URL")
	}

	return &UploadIntent{
		Attachment: a,
		ObjectKey:  objectKey,
		UploadURL:  uploadURL,
		ExpiresIn:  int(expires.Seconds()),
	}, nil
}

func (s *AttachmentService) FinalizeUpload(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) (*models.Attachment, error) {
	if user == nil {
		return nil, api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return nil, err
	}
	if a.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}

	if err := s.repo.UpdateStatus(ctx, attachmentID, models.AttachmentStatusReady); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return nil, err
	}
	a.Status = models.AttachmentStatusReady
	return a, nil
}

func (s *AttachmentService) GetDownloadURL(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) (string, error) {
	if user == nil {
		return "", api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return "", &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return "", &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return "", err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return "", &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return "", err
	}
	if a.GroupID != groupID {
		return "", &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}
	if a.Status != models.AttachmentStatusReady {
		return "", &api.ValidationError{Message: "attachment not ready"}
	}

	url := s.storage.GetURL(a.ObjectKey)
	if url == "" {
		return "", fmt.Errorf("failed to generate download URL")
	}
	return url, nil
}

func (s *AttachmentService) DeleteAttachment(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) error {
	if user == nil {
		return api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	if a.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}

	// Best-effort delete of backing object.
	if a.ObjectKey != "" && a.ObjectKey != "pending" {
		if err := s.storage.Delete(a.ObjectKey); err != nil {
			return err
		}
	}

	if err := s.repo.Delete(ctx, attachmentID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	return nil
}

func sanitizeFilename(name string) string {
	name = strings.TrimSpace(name)
	name = strings.ReplaceAll(name, "\\", "/")
	name = path.Base(name)
	name = strings.TrimSpace(name)
	name = strings.Trim(name, ".")
	name = strings.ReplaceAll(name, "..", ".")
	name = strings.ReplaceAll(name, "/", "_")
	name = strings.ReplaceAll(name, "\x00", "")
	if len(name) > 120 {
		name = name[:120]
	}
	return name
}

func buildObjectKey(groupID, attachmentID uuid.UUID, filename string) string {
	filename = sanitizeFilename(filename)
	if filename == "" {
		filename = "upload"
	}
	return fmt.Sprintf("groups/%s/attachments/%s/%s", groupID.String(), attachmentID.String(), filename)
}

